/*
 * taskmanager.c — TaskManager / Activity Monitor as an external PFX plugin.
 *
 * Presents a non-local "TaskManager" volume. When mounted, every running
 * process appears as a flat file entry, so a file manager becomes a task
 * manager (onboarding Windows users). Process attributes (PID, CPU %, MEM,
 * threads, state, user, PPID, command) are published as content columns via
 * the PFX content facet — selectable/sortable/persisted by the host's normal
 * column machinery. The mount is VOLATILE so the host auto-refreshes it.
 *
 * Identity: an entry's leaf name is "<name> (<pid>)". The host derives a
 * virtual path "/<name> (<pid>)" from the name, and we parse the trailing
 * "(pid)" back out — so kill (PfxDelete), info (PfxGetFile) and the content
 * lookup all resolve the exact process even when names collide (many "node").
 *
 * Data scope (Phase 1, unprivileged): the process list, PPID, UID and state
 * come from `sysctl KERN_PROC_ALL` (readable by anyone, like `ps`). RSS,
 * thread count and CPU time come from proc_pidinfo(), which only succeeds for
 * the caller's own processes — others show blank metrics. A privileged helper
 * for system-wide metrics is a later phase. CPU % is a delta between two
 * snapshots (the host's ~2s refresh IS the sampling interval); the first
 * snapshot has no baseline, so CPU is blank until the second refresh.
 *
 * The host serialises all calls on the one connection, so the global snapshot
 * needs no locking. Read-only as a filesystem; kill is the one mutation.
 */
#include "pfx.h"

#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <stdint.h>
#include <signal.h>
#include <pwd.h>
#include <time.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/sysctl.h>
#include <sys/proc.h>
#include <sys/proc_info.h>
#include <netinet/in.h>
#include <libproc.h>

/* ---- one process row of a snapshot ------------------------------------- */
typedef struct {
    int      pid;
    int      ppid;
    uid_t    uid;
    char     name[256];       /* display name (proc_name / p_comm)          */
    char     command[1024];   /* executable path (proc_pidpath) or name     */
    char     state;           /* R/S/T/Z/I                                  */
    int64_t  rss;             /* resident bytes (0 if not our process)      */
    int64_t  start;           /* start time, epoch seconds (0 if unknown)   */
    int      threads;         /* thread count (0 if not our process)        */
    int      have_task;       /* 1 if RSS/threads/CPU are real              */
    uint64_t cpu_ns;          /* cumulative CPU ns (for the % delta)        */
    double   cpu_pct;         /* CPU %, or -1 if no baseline yet            */
} Proc;

/* Per-connection state (heap-owned, returned by PfxConnect). Keeping it here —
 * not in globals — lets two mounts coexist without racing on one snapshot, and
 * lets PfxDisconnect free exactly its own connection. The host serialises all
 * calls on a given connection. */
typedef struct {
    Proc    *cur;      int cur_n;      /* live process snapshot                */
    uint64_t cur_wall;                 /* monotonic ns at the snapshot         */
    int     *terming;  int terming_n, terming_cap;  /* PIDs sent SIGTERM       */
} Conn;

/* A find cursor over one connection's live snapshot. */
typedef struct { Conn *c; int index; } Find;

static int terming_has(Conn *c, int pid) {
    for (int i = 0; i < c->terming_n; i++) if (c->terming[i] == pid) return 1;
    return 0;
}
static void terming_add(Conn *c, int pid) {
    if (terming_has(c, pid)) return;
    if (c->terming_n == c->terming_cap) {
        int cap = c->terming_cap ? c->terming_cap * 2 : 16;
        int *n = (int *)realloc(c->terming, (size_t)cap * sizeof(int));
        if (!n) return;
        c->terming = n; c->terming_cap = cap;
    }
    c->terming[c->terming_n++] = pid;
}

int PcGetApiVersion(void) { return 1; }
int PfxGetCapabilities(void) { return PC_PFX_CAP_READ | PC_PFX_CAP_VOLATILE; }

/* ---- static volume: the "TaskManager" drive ---------------------------- */
int  PfxGetVolumeCount(void) { return 1; }
void PfxGetVolumeInfo(int index, PfxVolumeInfo *out) {
    if (!out || index != 0) return;
    memset(out, 0, sizeof(*out));
    strcpy(out->id, "taskman");
    strcpy(out->name, "TaskManager");
    out->flags = 0;             /* non-local: clicking connects + mounts    */
    strcpy(out->icon, "📊");    /* our own drive-chip icon                  */
    out->order = 1;             /* pin right after the boot drive           */
}

/* ---- connection lifecycle ---------------------------------------------- */
void *PfxConnect(const PfxHostServices *services) {
    (void)services;
    return calloc(1, sizeof(Conn));   /* NULL on OOM -> host treats as failure */
}
int   PfxConnectionId(void *conn, char *out, int maxlen) {
    (void)conn;
    if (out && maxlen > 0) { strncpy(out, "taskman", (size_t)maxlen - 1); out[maxlen - 1] = 0; }
    return 1;
}
void  PfxDisconnect(void *conn) {
    Conn *c = (Conn *)conn;
    if (!c) return;
    free(c->cur); free(c->terming); free(c);
}

/* ---- helpers ----------------------------------------------------------- */

static uint64_t mono_ns(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000000000ull + (uint64_t)ts.tv_nsec;
}

static char state_letter(char p_stat) {
    switch (p_stat) {
        case SIDL:   return 'I';
        case SRUN:   return 'R';
        case SSLEEP: return 'S';
        case SSTOP:  return 'T';
        case SZOMB:  return 'Z';
        default:     return '?';
    }
}

/* Parse the trailing "(pid)" out of a host path like "/Safari (1234)". */
static int pid_from_path(const char *path) {
    if (!path) return -1;
    const char *lp = strrchr(path, '(');
    if (!lp) return -1;
    return atoi(lp + 1);
}

/* Find a process in the connection's snapshot by pid (linear — small lists). */
static const Proc *find_proc(Conn *c, int pid) {
    for (int i = 0; i < c->cur_n; i++)
        if (c->cur[i].pid == pid) return &c->cur[i];
    return NULL;
}

/* Cumulative CPU ns for `pid` in the still-current (soon-previous) snapshot,
 * or UINT64_MAX if it wasn't measured there — the baseline for the % delta. */
static uint64_t prev_cpu_ns(Conn *c, int pid) {
    for (int i = 0; i < c->cur_n; i++)
        if (c->cur[i].pid == pid && c->cur[i].have_task) return c->cur[i].cpu_ns;
    return UINT64_MAX;
}

/* Rebuild the connection's snapshot from the kernel, deriving CPU % as a delta
 * against the previous snapshot (still in c->cur) over the refresh interval. */
static void rebuild_snapshot(Conn *c) {
    int mib[4] = { CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0 };
    size_t len = 0;
    if (sysctl(mib, 4, NULL, &len, NULL, 0) != 0 || len == 0) return;
    /* Over-allocate slightly: the process count can grow between the two calls. */
    len += len / 8;
    struct kinfo_proc *kp = (struct kinfo_proc *)malloc(len);
    if (!kp) return;
    if (sysctl(mib, 4, kp, &len, NULL, 0) != 0) { free(kp); return; }
    int n = (int)(len / sizeof(struct kinfo_proc));

    uint64_t wall = mono_ns();
    Proc *rows = (Proc *)calloc((size_t)(n > 0 ? n : 1), sizeof(Proc));
    if (!rows) { free(kp); return; }

    int m = 0;
    for (int i = 0; i < n; i++) {
        int pid = kp[i].kp_proc.p_pid;
        if (pid <= 0) continue;
        Proc *p = &rows[m];
        p->pid   = pid;
        p->ppid  = kp[i].kp_eproc.e_ppid;
        p->uid   = kp[i].kp_eproc.e_ucred.cr_uid;
        p->state = state_letter(kp[i].kp_proc.p_stat);
        p->cpu_pct = -1.0;

        /* Base name from the (truncated) comm; upgraded below if possible. */
        strncpy(p->name, kp[i].kp_proc.p_comm, sizeof(p->name) - 1);

        /* A longer display name when the kernel offers one. */
        char nb[256];
        if (proc_name(pid, nb, sizeof(nb)) > 0 && nb[0])
            strncpy(p->name, nb, sizeof(p->name) - 1);

        /* Executable path as the command (cheap; full argv only in the info view). */
        char pathbuf[PROC_PIDPATHINFO_MAXSIZE];
        if (proc_pidpath(pid, pathbuf, sizeof(pathbuf)) > 0 && pathbuf[0])
            strncpy(p->command, pathbuf, sizeof(p->command) - 1);
        else
            strncpy(p->command, p->name, sizeof(p->command) - 1);

        /* Task metrics + start time — only for our own processes (unprivileged). */
        struct proc_taskallinfo tai;
        int r = proc_pidinfo(pid, PROC_PIDTASKALLINFO, 0, &tai, sizeof(tai));
        if (r == (int)sizeof(tai)) {
            p->have_task = 1;
            p->rss       = (int64_t)tai.ptinfo.pti_resident_size;
            p->threads   = tai.ptinfo.pti_threadnum;
            p->cpu_ns    = tai.ptinfo.pti_total_user + tai.ptinfo.pti_total_system;
            p->start     = (int64_t)tai.pbsd.pbi_start_tvsec;
            uint64_t prev = prev_cpu_ns(c, pid);
            if (prev != UINT64_MAX && c->cur_wall != 0 && wall > c->cur_wall && p->cpu_ns >= prev) {
                double dcpu  = (double)(p->cpu_ns - prev);
                double dwall = (double)(wall - c->cur_wall);
                p->cpu_pct = dwall > 0 ? (100.0 * dcpu / dwall) : -1.0;
            }
        }
        m++;
    }
    free(kp);

    /* Replace the snapshot; the old one (read above for baselines) is freed. */
    free(c->cur);
    c->cur = rows;  c->cur_n = m;  c->cur_wall = wall;

    /* Prune the terminate-escalation set to PIDs still alive (a died-then-reused
     * PID must not be force-killed on its owner's first delete). */
    int w = 0;
    for (int i = 0; i < c->terming_n; i++)
        if (find_proc(c, c->terming[i])) c->terming[w++] = c->terming[i];
    c->terming_n = w;
}

/* ---- directory enumeration (flat: everything under "/") ---------------- */
void *PfxFindFirst(void *conn, const char *dir) {
    Conn *c = (Conn *)conn;
    if (!c || !dir || (strcmp(dir, "/") != 0 && dir[0] != 0)) return NULL;  /* flat */
    rebuild_snapshot(c);
    Find *f = (Find *)calloc(1, sizeof(Find));
    if (f) f->c = c;
    return f;   /* may be NULL on OOM; host treats that as "not a directory" */
}

int PfxFindNext(void *find, PfxFindData *out) {
    if (!find || !out) return 0;
    Find *f = (Find *)find;
    if (f->index >= f->c->cur_n) return 0;
    const Proc *p = &f->c->cur[f->index++];
    memset(out, 0, sizeof(*out));
    snprintf(out->name, sizeof(out->name), "%s (%d)", p->name, p->pid);
    out->size  = p->have_task ? p->rss : -1;
    out->mtime = p->start;
    out->isDir = 0;
    return 1;
}

void PfxFindClose(void *find) { free(find); }

int PfxStat(void *conn, const char *path, PfxFindData *out) {
    Conn *c = (Conn *)conn;
    if (!c || !path || !out) return PC_E_NOT_SUPPORTED;
    if (strcmp(path, "/") == 0) {   /* the mount root */
        memset(out, 0, sizeof(*out));
        strcpy(out->name, "/"); out->isDir = 1; out->size = -1;
        return PC_OK;
    }
    const Proc *p = find_proc(c, pid_from_path(path));
    if (!p) return PC_E_EOPEN;
    memset(out, 0, sizeof(*out));
    snprintf(out->name, sizeof(out->name), "%s (%d)", p->name, p->pid);
    out->size  = p->have_task ? p->rss : -1;
    out->mtime = p->start;
    out->isDir = 0;
    return PC_OK;
}

/* ---- content-column facet ----------------------------------------------
 * MEM (RSS) and start time are carried by the entry's built-in size/mtime, so
 * they use the host's Size/Date columns (formatted + correctly numeric-sorted).
 * The facet publishes only the extra attributes, as display strings. */
int PfxContentFieldCount(void) { return 7; }

void PfxContentField(int index, PfxFieldInfo *out) {
    if (!out) return;
    memset(out, 0, sizeof(*out));
    struct { const char *name, *title; int type, w; } F[] = {
        { "pid",     "PID",     PFX_FT_NUMERIC,  56 },
        { "cpu",     "CPU %",   PFX_FT_NUMERIC,  60 },
        { "threads", "Threads", PFX_FT_NUMERIC,  64 },
        { "state",   "State",   PFX_FT_STRING,   52 },
        { "user",    "User",    PFX_FT_STRING,   90 },
        { "ppid",    "PPID",    PFX_FT_NUMERIC,  56 },
        { "command", "Command", PFX_FT_STRING,  420 },
    };
    if (index < 0 || index >= (int)(sizeof(F) / sizeof(F[0]))) return;
    strncpy(out->name,  F[index].name,  sizeof(out->name) - 1);
    strncpy(out->title, F[index].title, sizeof(out->title) - 1);
    out->type = F[index].type;
    out->defaultWidth = F[index].w;
}

int PfxContentGetRow(void *conn, const char *path, char *out, int maxlen) {
    Conn *c = (Conn *)conn;
    if (!c || !path || !out || maxlen <= 0) return 0;
    const Proc *p = find_proc(c, pid_from_path(path));
    if (!p) return 0;

    char cpu[32] = "";
    if (p->cpu_pct >= 0.0) snprintf(cpu, sizeof(cpu), "%.1f", p->cpu_pct);
    char thr[16] = "";
    if (p->have_task) snprintf(thr, sizeof(thr), "%d", p->threads);
    char st[2] = { p->state, 0 };

    const char *user = "";
    struct passwd *pw = getpwuid(p->uid);
    if (pw && pw->pw_name) user = pw->pw_name;

    /* Order MUST match PfxContentField: pid,cpu,threads,state,user,ppid,command */
    snprintf(out, (size_t)maxlen, "%d\t%s\t%s\t%s\t%s\t%d\t%s",
             p->pid, cpu, thr, st, user, p->ppid, p->command);
    return 1;
}

/* ---- lookup facet: "port:<n>" -> the process owning that local port ----- */

/* Does process `pid` hold a TCP/UDP socket bound to local `port`? Enumerates
 * the process's socket fds; only works for the caller's own processes
 * unprivileged (others' fd lists are not readable). */
static int pid_owns_port(int pid, int port) {
    int bufsize = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, NULL, 0);
    if (bufsize <= 0) return 0;
    struct proc_fdinfo *fds = (struct proc_fdinfo *)malloc((size_t)bufsize);
    if (!fds) return 0;
    int n = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, fds, bufsize);
    int count = n > 0 ? n / (int)sizeof(struct proc_fdinfo) : 0;
    int hit = 0;
    for (int i = 0; i < count && !hit; i++) {
        if (fds[i].proc_fdtype != PROX_FDTYPE_SOCKET) continue;
        struct socket_fdinfo si;
        if (proc_pidfdinfo(pid, fds[i].proc_fd, PROC_PIDFDSOCKETINFO,
                           &si, sizeof(si)) != (int)sizeof(si)) continue;
        int lport = -1;
        if (si.psi.soi_kind == SOCKINFO_TCP)
            lport = ntohs((uint16_t)si.psi.soi_proto.pri_tcp.tcpsi_ini.insi_lport);
        else if (si.psi.soi_kind == SOCKINFO_IN)
            lport = ntohs((uint16_t)si.psi.soi_proto.pri_in.insi_lport);
        if (lport == port) hit = 1;
    }
    free(fds);
    return hit;
}

int PfxLookup(void *conn, const char *query, char *out, int maxlen) {
    Conn *c = (Conn *)conn;
    if (!c || !query || !out || maxlen <= 0) return 0;
    if (strncmp(query, "port:", 5) != 0) return 0;   /* only "port:<n>" for now */
    int port = atoi(query + 5);
    if (port <= 0 || port > 65535) return 0;
    if (c->cur_n == 0) rebuild_snapshot(c);
    for (int i = 0; i < c->cur_n; i++) {
        if (pid_owns_port(c->cur[i].pid, port)) {
            snprintf(out, (size_t)maxlen, "/%s (%d)", c->cur[i].name, c->cur[i].pid);
            return 1;
        }
    }
    return 0;   /* no (readable) process owns it — may need elevated privileges */
}

/* ---- kill (Delete), with graceful->forced escalation ------------------- */
int PfxDelete(void *conn, const char *path) {
    Conn *c = (Conn *)conn;
    if (!c) return PC_E_EOPEN;
    int pid = pid_from_path(path);
    if (pid <= 1) return PC_E_EOPEN;   /* never target the root path or launchd */
    /* First delete: SIGTERM (graceful). Repeat delete on a still-alive process:
     * SIGKILL (force quit). kill(pid,0) probes liveness without signalling. */
    int sig = (terming_has(c, pid) && kill(pid, 0) == 0) ? SIGKILL : SIGTERM;
    if (kill(pid, sig) != 0)
        return (errno == EPERM) ? PC_E_NOT_SUPPORTED : PC_E_EOPEN;
    if (sig == SIGTERM) terming_add(c, pid);
    return PC_OK;
}

/* ---- process info (GetFile → temp text → host F3 viewer) --------------- */

/* Best-effort full command line via KERN_PROCARGS2 (own processes / permitted).
 * Writes argv space-joined into `out`; returns 1 on success. */
static int full_cmdline(int pid, char *out, size_t outlen) {
    int argmax = 0; size_t sz = sizeof(argmax);
    int mib_max[2] = { CTL_KERN, KERN_ARGMAX };
    if (sysctl(mib_max, 2, &argmax, &sz, NULL, 0) != 0 || argmax <= 0) return 0;
    char *buf = (char *)malloc((size_t)argmax);
    if (!buf) return 0;
    int mib[3] = { CTL_KERN, KERN_PROCARGS2, pid };
    sz = (size_t)argmax;
    if (sysctl(mib, 3, buf, &sz, NULL, 0) != 0 || sz < sizeof(int)) { free(buf); return 0; }
    int argc = 0; memcpy(&argc, buf, sizeof(argc));
    char *p = buf + sizeof(argc);
    char *end = buf + sz;
    while (p < end && *p) p++;            /* skip exec path */
    while (p < end && !*p) p++;           /* skip NUL padding */
    size_t used = 0;
    for (int a = 0; a < argc && p < end; a++) {
        size_t l = strnlen(p, (size_t)(end - p));
        if (used + l + 2 >= outlen) break;
        if (used) out[used++] = ' ';
        memcpy(out + used, p, l); used += l;
        p += l + 1;
    }
    out[used] = 0;
    free(buf);
    return used > 0;
}

static const char *state_name(char s) {
    switch (s) {
        case 'R': return "running";
        case 'S': return "sleeping";
        case 'T': return "stopped";
        case 'Z': return "zombie";
        case 'I': return "idle";
        default:  return "unknown";
    }
}

int PfxGetFile(void *conn, const char *remotePath, const char *localPath) {
    Conn *c = (Conn *)conn;
    if (!c || !remotePath || !localPath) return PC_E_NOT_SUPPORTED;
    const Proc *p = find_proc(c, pid_from_path(remotePath));
    if (!p) return PC_E_EOPEN;
    FILE *f = fopen(localPath, "w");
    if (!f) return PC_E_ECREATE;

    struct passwd *pw = getpwuid(p->uid);
    fprintf(f, "Process Information\n===================\n\n");
    fprintf(f, "Name:      %s\n", p->name);
    fprintf(f, "PID:       %d\n", p->pid);
    fprintf(f, "PPID:      %d\n", p->ppid);
    fprintf(f, "User:      %s (uid %d)\n", (pw && pw->pw_name) ? pw->pw_name : "?", p->uid);
    fprintf(f, "State:     %s\n", state_name(p->state));
    if (p->have_task) {
        fprintf(f, "Threads:   %d\n", p->threads);
        fprintf(f, "Memory:    %lld bytes (%.1f MB)\n",
                (long long)p->rss, (double)p->rss / (1024.0 * 1024.0));
        if (p->cpu_pct >= 0.0) fprintf(f, "CPU:       %.1f %%\n", p->cpu_pct);
    } else {
        fprintf(f, "Threads:   (needs elevated privileges)\n");
        fprintf(f, "Memory:    (needs elevated privileges)\n");
    }
    if (p->start > 0) {
        time_t t = (time_t)p->start;
        char tb[64]; struct tm tm;
        localtime_r(&t, &tm);
        strftime(tb, sizeof(tb), "%Y-%m-%d %H:%M:%S", &tm);
        fprintf(f, "Started:   %s\n", tb);
    }
    fprintf(f, "\nExecutable:\n  %s\n", p->command);

    char cmd[4096];
    if (full_cmdline(p->pid, cmd, sizeof(cmd)))
        fprintf(f, "\nCommand line:\n  %s\n", cmd);

    fclose(f);
    return PC_OK;
}
