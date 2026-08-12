// SPDX-License-Identifier: Apache-2.0
/*
 * taskmanager.c — TaskManager / Activity Monitor as an external PFX plugin.
 *
 * Presents a non-local "TaskManager" volume. When mounted, every running
 * process appears as an entry, so a file manager becomes a task manager
 * (onboarding Windows users). Process attributes (PID, CPU %, memory, I/O,
 * threads, state, user, PPID, signer, command) are published as content columns
 * via the PFX content facet — selectable/sortable/persisted by the host's normal
 * column machinery. The mount is VOLATILE so the host auto-refreshes it.
 *
 * A process is also a FOLDER (F-391): entering it lists the files it currently
 * has open, as real file rows the host can view, reveal and navigate to. That is
 * the thing a file manager can say about a process that a task manager cannot.
 *
 * Identity: an entry's leaf name is "<name> (<pid>)". The host derives a
 * virtual path "/<name> (<pid>)" from the name, and we parse the trailing
 * "(pid)" back out — so kill (PfxDelete), info (PfxGetFile) and the content
 * lookup all resolve the exact process even when names collide (many "node").
 *
 * Data scope (unprivileged): the process list, PPID, UID, state and the
 * executable path come from `sysctl KERN_PROC_ALL` and proc_pidpath, readable
 * for every process. Memory, threads, CPU, I/O and the open-file list come from
 * proc_pidinfo/proc_pid_rusage, which succeed for every process of the CALLER'S
 * OWN UID — on a normal Mac that is most of the table (~72% here), not just this
 * one process, which is what this comment used to claim. Another user's and
 * root's processes show those columns blank unless the `ps` fallback is on
 * (F-394). Who signed the binary (F-393) is readable for ALL of them, because it
 * is a property of the file rather than of the task. CPU % is a delta between two
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
#include <fcntl.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/sysctl.h>
#include <sys/proc.h>
#include <sys/proc_info.h>
#include <netinet/in.h>
#include <libproc.h>
#include <CoreFoundation/CoreFoundation.h>
#include <Security/Security.h>

/* ---- one process row of a snapshot ------------------------------------- */
typedef struct {
    int      pid;
    int      ppid;
    uid_t    uid;
    char     name[256];       /* display name (proc_name / p_comm)          */
    char     command[1024];   /* executable path (proc_pidpath) or name     */
    char     state;           /* p_stat letter: R/S/T/Z/I                   */
    char     state_str[8];    /* what `ps` says (F-397), else the letter     */
    int64_t  rss;             /* resident bytes (0 if not our process)      */
    int64_t  start;           /* start time, epoch seconds (0 if unknown)   */
    int      threads;         /* thread count (0 if not our process)        */
    int      have_task;       /* 1 if RSS/threads/CPU are real              */
    uint64_t cpu_ns;          /* cumulative CPU ns (for the % delta)        */
    double   cpu_pct;         /* CPU %, or -1 if no baseline yet            */
    /* proc_pid_rusage, same reach as the task info (F-392). Memory footprint is
     * what Activity Monitor calls "Memory" — RSS counts shared pages the process
     * did not cause, which is why the two disagree for every browser tab. */
    int      have_rusage;
    int      from_ps;         /* metrics filled by the setuid `ps` (F-394)  */
    uint64_t footprint;       /* phys_footprint, bytes                      */
    uint64_t io_read;         /* bytes read from disk, lifetime             */
    uint64_t io_write;        /* bytes written to disk, lifetime            */
    uint64_t wakeups;         /* interrupt wakeups, lifetime                */
    const char *signer;       /* into the signature cache, or NULL (F-393)  */
} Proc;

/* ---- who signed this binary (F-393) ------------------------------------
 *
 * The macOS answer to Process Explorer's "Verified Signer" column, and the one
 * thing here that is readable for EVERY process: it is a property of the
 * executable file, which is world-readable, not of the running task. So a root
 * daemon whose memory we may not look at still says who signed it.
 *
 * Reading a signature costs ~1.5 ms and this machine runs ~700 distinct
 * binaries, so doing them all in one listing is a second of dead panel. They are
 * cached by path and filled a few per refresh under a time budget instead: a
 * blank cell means "not read yet" and turns into an answer within seconds,
 * without the listing ever stopping to wait.
 *
 * NOT notarization: that needs `SecStaticCodeCheckValidity`, which hashes the
 * whole binary — seconds per application. Who signed it, and whether the
 * signature is ad-hoc or hardened, comes out of the signature blob alone. */
typedef struct SigEntry {
    char            *path;
    char             label[72];   /* "Apple", "Developer ID: ABCDE12345", … */
    uint32_t         flags;       /* kSecCodeSignature* bits                */
    struct SigEntry *next;
} SigEntry;

static void sigs_free(SigEntry *e);   /* defined with the rest of the signature code */

/* One row of `ps` output — the way to see another user's numbers without being
 * root, and without a privileged helper of our own (F-394). */
typedef struct PsRow { int pid; double cpu; int64_t rss; char state[8]; } PsRow;

/* uid → login name, so the row formatter does not ask the directory per row. */
typedef struct { uid_t uid; char name[64]; } UserName;

/* Per-connection state (heap-owned, returned by PfxConnect). Keeping it here —
 * not in globals — lets two mounts coexist without racing on one snapshot, and
 * lets PfxDisconnect free exactly its own connection. The host serialises all
 * calls on a given connection. */
typedef struct {
    Proc    *cur;      int cur_n;      /* live process snapshot                */
    uint64_t cur_wall;                 /* monotonic ns at the snapshot         */
    int     *terming;  int terming_n, terming_cap;  /* PIDs sent SIGTERM       */
    SigEntry *sigs;                    /* signature cache, by executable path  */
    struct PsRow *ps;  int ps_n;       /* `ps` snapshot for other users (F-394)*/
    uint64_t ps_wall;                  /* monotonic ns of that snapshot        */
    UserName users[32]; int users_n;   /* uid → name, per connection           */
} Conn;

/* One open file of a process, as a directory entry (F-391). */
typedef struct {
    char    name[1024];   /* the file's path, "/" written as ":" (see enc_path)    */
    int64_t size;
    int64_t mtime;
    uint32_t mode;
} FileRow;

/* A find cursor: over the process list (rows == NULL) or over one process's
 * open files (rows != NULL, collected up front — an fd list is a snapshot and
 * cannot be walked lazily while the process keeps opening and closing files). */
typedef struct { Conn *c; int index; FileRow *rows; int n; } Find;

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
    free(c->cur); free(c->terming); free(c->ps); sigs_free(c->sigs); free(c);
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

/* Split a host path into the process it names and whatever follows it.
 *
 * "/Safari (1234)"                  -> pid 1234, *sub = NULL   (the process itself)
 * "/Safari (1234)/:Users:x:a.txt"   -> pid 1234, *sub = ":Users:x:a.txt"
 *
 * The trailing "(pid)" is read out of the FIRST component only. A plain
 * `strrchr(path, '(')` finds it anywhere in the path, so an open file whose own
 * name contains a bracket used to answer as the process — and PfxDelete would
 * then have signalled a process because a *file* was selected. */
static int split_process_path(const char *path, const char **sub) {
    if (sub) *sub = NULL;
    if (!path || path[0] != '/') return -1;
    const char *slash = strchr(path + 1, '/');
    const char *end = slash ? slash : path + strlen(path);
    const char *lp = NULL;
    for (const char *p = path + 1; p < end; p++) if (*p == '(') lp = p;
    if (!lp) return -1;
    int pid = atoi(lp + 1);
    if (pid <= 0) return -1;
    if (slash && sub) *sub = slash + 1;
    return pid;
}

/* The process a path names, or -1 if the path names something *inside* one. */
static int pid_from_path(const char *path) {
    const char *sub = NULL;
    int pid = split_process_path(path, &sub);
    return sub ? -1 : pid;
}

/* A file path as an entry name: "/" is written ":" — the host's own convention
 * for a name that contains a slash (it displays ":" as "/"), so the row reads as
 * the path it is while staying a single leaf name the host can hand back. */
static void enc_path(const char *path, char *out, size_t outlen) {
    size_t i = 0;
    for (; path[i] && i + 1 < outlen; i++) out[i] = (path[i] == '/') ? ':' : path[i];
    out[i] = 0;
}

/* …and back, for the entry names the host hands us. */
static void dec_path(const char *name, char *out, size_t outlen) {
    size_t i = 0;
    for (; name[i] && i + 1 < outlen; i++) out[i] = (name[i] == ':') ? '/' : name[i];
    out[i] = 0;
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

/* ---- signature reading (F-393) ----------------------------------------- */

static void cf_to_utf8(CFStringRef s, char *out, size_t outlen) {
    out[0] = 0;
    if (s) CFStringGetCString(s, out, (CFIndex)outlen, kCFStringEncodingUTF8);
}

/* Who signed `path`, in one short phrase, plus the signature's flag word.
 *
 * The distinction users care about is not "valid/invalid" but WHO: Apple's own
 * system binaries, a named developer (with the team id that identifies them
 * across renames), something signed only to itself (ad-hoc — what a local build
 * looks like), or nothing at all. */
static void read_signature(const char *path, char *label, size_t labellen, uint32_t *flags) {
    snprintf(label, labellen, "?");
    *flags = 0;
    CFStringRef ps = CFStringCreateWithCString(NULL, path, kCFStringEncodingUTF8);
    if (!ps) return;
    CFURLRef url = CFURLCreateWithFileSystemPath(NULL, ps, kCFURLPOSIXPathStyle, false);
    CFRelease(ps);
    if (!url) return;
    SecStaticCodeRef code = NULL;
    OSStatus rc = SecStaticCodeCreateWithPath(url, kSecCSDefaultFlags, &code);
    CFRelease(url);
    if (rc != errSecSuccess || !code) { snprintf(label, labellen, "unreadable"); return; }

    CFDictionaryRef info = NULL;
    if (SecCodeCopySigningInformation(code, kSecCSSigningInformation, &info) != errSecSuccess || !info) {
        CFRelease(code);
        snprintf(label, labellen, "unsigned");
        return;
    }
    CFNumberRef fl = CFDictionaryGetValue(info, kSecCodeInfoFlags);
    if (fl) CFNumberGetValue(fl, kCFNumberSInt32Type, flags);

    CFArrayRef chain = CFDictionaryGetValue(info, kSecCodeInfoCertificates);
    CFStringRef team = CFDictionaryGetValue(info, kSecCodeInfoTeamIdentifier);
    if (chain && CFArrayGetCount(chain) > 0) {
        /* Index 0 is the leaf — the certificate that names the signer. The root
         * (last) only ever says "Apple Root CA", which every signed binary on the
         * machine shares and which therefore distinguishes nothing. */
        SecCertificateRef leaf = (SecCertificateRef)CFArrayGetValueAtIndex(chain, 0);
        CFStringRef cn = SecCertificateCopySubjectSummary(leaf);
        char subject[256] = "";
        cf_to_utf8(cn, subject, sizeof(subject));
        if (cn) CFRelease(cn);
        char teamid[64] = "";
        cf_to_utf8(team, teamid, sizeof(teamid));
        if (strncmp(subject, "Developer ID Application: ", 26) == 0) {
            if (teamid[0]) snprintf(label, labellen, "Developer ID: %s", teamid);
            else           snprintf(label, labellen, "%s", subject + 26);
        } else if (strstr(subject, "Apple") || strcmp(subject, "Software Signing") == 0) {
            snprintf(label, labellen, "Apple");
        } else if (subject[0]) {
            snprintf(label, labellen, "%s", subject);
        }
    } else if (*flags & kSecCodeSignatureAdhoc) {
        snprintf(label, labellen, "ad-hoc");
    } else {
        snprintf(label, labellen, "unsigned");
    }
    CFRelease(info);
    CFRelease(code);
}

/* The cached signature label for `path`, computing it when `may_read` allows.
 * Returns "" while unknown — an empty cell is honest about not having looked. */
static const char *sig_label(Conn *c, const char *path, int may_read, uint32_t *flags_out) {
    if (!path || !path[0]) return "";
    for (SigEntry *e = c->sigs; e; e = e->next)
        if (strcmp(e->path, path) == 0) {
            if (flags_out) *flags_out = e->flags;
            return e->label;
        }
    if (!may_read) return "";
    SigEntry *e = (SigEntry *)calloc(1, sizeof(SigEntry));
    if (!e) return "";
    e->path = strdup(path);
    if (!e->path) { free(e); return ""; }
    read_signature(path, e->label, sizeof(e->label), &e->flags);
    e->next = c->sigs; c->sigs = e;
    if (flags_out) *flags_out = e->flags;
    return e->label;
}

static void sigs_free(SigEntry *e) {
    while (e) { SigEntry *n = e->next; free(e->path); free(e); e = n; }
}

/* The binary's entitlements, one per line, for the info report — the part of a
 * macOS signature that says what the program is ALLOWED to do (sandboxed? camera?
 * automation?). Only the keys: the values are mostly `true`, and the ones that
 * are not (arrays of file paths, app groups) would drown the report.
 * Returns 1 when at least one was written. */
static int read_entitlements(const char *path, char *out, size_t outlen) {
    out[0] = 0;
    CFStringRef ps = CFStringCreateWithCString(NULL, path, kCFStringEncodingUTF8);
    if (!ps) return 0;
    CFURLRef url = CFURLCreateWithFileSystemPath(NULL, ps, kCFURLPOSIXPathStyle, false);
    CFRelease(ps);
    if (!url) return 0;
    SecStaticCodeRef code = NULL;
    OSStatus rc = SecStaticCodeCreateWithPath(url, kSecCSDefaultFlags, &code);
    CFRelease(url);
    if (rc != errSecSuccess || !code) return 0;
    CFDictionaryRef info = NULL;
    int wrote = 0;
    if (SecCodeCopySigningInformation(code, kSecCSRequirementInformation, &info) == errSecSuccess && info) {
        CFDictionaryRef ents = CFDictionaryGetValue(info, kSecCodeInfoEntitlementsDict);
        if (ents) {
            CFIndex n = CFDictionaryGetCount(ents);
            const void **keys = (const void **)calloc((size_t)(n > 0 ? n : 1), sizeof(void *));
            if (keys) {
                CFDictionaryGetKeysAndValues(ents, keys, NULL);
                size_t used = 0;
                for (CFIndex i = 0; i < n; i++) {
                    char key[256] = "";
                    cf_to_utf8((CFStringRef)keys[i], key, sizeof(key));
                    if (!key[0]) continue;
                    int len = snprintf(out + used, outlen - used, "  %s\n", key);
                    if (len < 0 || used + (size_t)len >= outlen) break;
                    used += (size_t)len;
                    wrote = 1;
                }
                free(keys);
            }
        }
        CFRelease(info);
    }
    CFRelease(code);
    return wrote;
}

/* ---- other users' numbers, without being root (F-394) -------------------
 *
 * `proc_pidinfo` answers for processes of our own uid and for nobody else, which
 * on this machine leaves about a quarter of the rows blank — root's daemons, and
 * they are often the interesting ones. The usual answer is a privileged helper,
 * which needs a Developer ID this project does not have.
 *
 * It is not needed: /bin/ps is setuid root and prints CPU and resident size for
 * every process. Reading it costs ~50 ms for 1200 processes, so it runs at most
 * every few seconds and only when there is something it could fill in.
 *
 * The numbers are NOT the same measurement, and the columns say so: `ps` reports
 * a decayed lifetime average for CPU where this plugin computes the delta between
 * two refreshes, and it reports resident size where our own processes also have a
 * memory footprint. Resident size is therefore its own column, filled from either
 * source; the footprint column stays empty for processes whose footprint nobody
 * will tell us. */
#define PS_INTERVAL_NS (4ull * 1000000000ull)

static void refresh_ps(Conn *c) {
    uint64_t now = mono_ns();
    if (c->ps && c->ps_wall && now - c->ps_wall < PS_INTERVAL_NS) return;
    /* LC_ALL=C: with a German locale ps prints "0,4" and strtod stops at the comma. */
    FILE *p = popen("LC_ALL=C /bin/ps -axo pid=,%cpu=,rss=,state= 2>/dev/null", "r");
    if (!p) return;
    int cap = 1024, n = 0;
    PsRow *rows = (PsRow *)malloc((size_t)cap * sizeof(PsRow));
    if (!rows) { pclose(p); return; }
    char line[256];
    while (fgets(line, sizeof(line), p)) {
        int pid = 0; double cpu = 0; long long rss = 0; char state[8] = "";
        if (sscanf(line, "%d %lf %lld %7s", &pid, &cpu, &rss, state) < 3 || pid <= 0) continue;
        if (n == cap) {
            int nc = cap * 2;
            PsRow *nr = (PsRow *)realloc(rows, (size_t)nc * sizeof(PsRow));
            if (!nr) break;
            rows = nr; cap = nc;
        }
        rows[n].pid = pid; rows[n].cpu = cpu; rows[n].rss = (int64_t)rss * 1024;   /* ps prints KB */
        snprintf(rows[n].state, sizeof(rows[n].state), "%s", state);
        n++;
    }
    pclose(p);
    if (n == 0) { free(rows); return; }
    free(c->ps);
    c->ps = rows; c->ps_n = n; c->ps_wall = now;
}

/* A uid's login name, remembered per connection.
 *
 * `getpwuid` is a directory-services lookup, and the row formatter called it once per row: on this
 * machine that is 1200 lookups for the four users that actually own anything. Together with
 * resolving the signer alongside the snapshot, a full column prefetch over 1191 rows went from
 * 8.5 ms to 4.4 ms — main-thread time, every two seconds, while the mount is open. */
static const char *user_name(Conn *c, uid_t uid) {
    for (int i = 0; i < c->users_n; i++) if (c->users[i].uid == uid) return c->users[i].name;
    if (c->users_n == (int)(sizeof(c->users) / sizeof(c->users[0]))) return "";   /* pathological */
    struct passwd *pw = getpwuid(uid);
    UserName *u = &c->users[c->users_n++];
    u->uid = uid;
    snprintf(u->name, sizeof(u->name), "%s", (pw && pw->pw_name) ? pw->pw_name : "");
    return u->name;
}

static const PsRow *ps_find(Conn *c, int pid) {
    for (int i = 0; i < c->ps_n; i++) if (c->ps[i].pid == pid) return &c->ps[i];
    return NULL;
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

        /* Footprint, disk I/O and wakeups (F-392). One extra call, and it reaches
         * exactly as far as the task info above — the same processes, no new
         * permission question. */
        struct rusage_info_v4 ri;
        if (proc_pid_rusage(pid, RUSAGE_INFO_V4, (rusage_info_t *)&ri) == 0) {
            p->have_rusage = 1;
            p->footprint = ri.ri_phys_footprint;
            p->io_read   = ri.ri_diskio_bytesread;
            p->io_write  = ri.ri_diskio_byteswritten;
            p->wakeups   = ri.ri_interrupt_wkups;
        }
        m++;
    }
    free(kp);

    /* Replace the snapshot; the old one (read above for baselines) is freed. */
    free(c->cur);
    c->cur = rows;  c->cur_n = m;  c->cur_wall = wall;

    /* `ps` fills two holes at once (F-394, F-397): the metrics proc_pidinfo will not give us for
     * another user's process, and the process state for ALL of them — `p_stat` reports SRUN for
     * 1196 of 1197 processes on this macOS, so the State column was answering "R" to every question.
     * That is why this runs on its own interval rather than only when metrics are missing. */
    refresh_ps(c);
    for (int i = 0; i < c->cur_n; i++) {
        const PsRow *r = ps_find(c, c->cur[i].pid);
        if (r && r->state[0])
            snprintf(c->cur[i].state_str, sizeof(c->cur[i].state_str), "%s", r->state);
        if (c->cur[i].have_task || !r) continue;
        c->cur[i].from_ps = 1;
        c->cur[i].rss = r->rss;
        c->cur[i].cpu_pct = r->cpu;
    }

    /* Read a few more signatures (F-393), newest rows first, under a time budget:
     * the listing must not wait a second for a column, and the cache makes every
     * later refresh free. Blank cells fill in over the next few refreshes. */
    uint64_t deadline = mono_ns() + 80ull * 1000000ull;   /* 80 ms of this refresh */
    int budget_left = 1;
    for (int i = 0; i < c->cur_n; i++) {
        if (budget_left && mono_ns() >= deadline) budget_left = 0;
        /* Resolved with the snapshot, where the cache is being filled anyway, rather than walked
         * again while each row is formatted. */
        c->cur[i].signer = sig_label(c, c->cur[i].command, budget_left, NULL);
    }

    /* Prune the terminate-escalation set to PIDs still alive (a died-then-reused
     * PID must not be force-killed on its owner's first delete). */
    int w = 0;
    for (int i = 0; i < c->terming_n; i++)
        if (find_proc(c, c->terming[i])) c->terming[w++] = c->terming[i];
    c->terming_n = w;
}

/* ---- a process's open files, as directory entries (F-391) --------------- */

/* Collect the files `pid` currently has open, one row per distinct path.
 *
 * Distinct *path*, not distinct fd: two fds on one file are one file, and the
 * row the user wants to act on is the file. Same reach as everything else here —
 * the caller's own uid; another user's process yields nothing rather than an
 * error, so an unreadable process is an empty folder and not a failure. */
static FileRow *collect_open_files(int pid, int *count) {
    *count = 0;
    int bufsize = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, NULL, 0);
    if (bufsize <= 0) return NULL;
    struct proc_fdinfo *fds = (struct proc_fdinfo *)malloc((size_t)bufsize);
    if (!fds) return NULL;
    int n = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, fds, bufsize);
    int nfd = n > 0 ? n / (int)sizeof(struct proc_fdinfo) : 0;
    FileRow *rows = (FileRow *)calloc((size_t)(nfd > 0 ? nfd : 1), sizeof(FileRow));
    if (!rows) { free(fds); return NULL; }
    int m = 0;
    for (int i = 0; i < nfd; i++) {
        if (fds[i].proc_fdtype != PROX_FDTYPE_VNODE) continue;   /* sockets/pipes have no path */
        struct vnode_fdinfowithpath vi;
        if (proc_pidfdinfo(pid, fds[i].proc_fd, PROC_PIDFDVNODEPATHINFO,
                           &vi, sizeof(vi)) != (int)sizeof(vi)) continue;
        const char *p = vi.pvip.vip_path;
        if (!p[0]) continue;
        char enc[1024];
        enc_path(p, enc, sizeof(enc));
        int dup = 0;
        for (int k = 0; k < m && !dup; k++) if (strcmp(rows[k].name, enc) == 0) dup = 1;
        if (dup) continue;
        strncpy(rows[m].name, enc, sizeof(rows[m].name) - 1);
        rows[m].size  = (int64_t)vi.pvip.vip_vi.vi_stat.vst_size;
        rows[m].mtime = (int64_t)vi.pvip.vip_vi.vi_stat.vst_mtime;
        rows[m].mode  = vi.pvip.vip_vi.vi_stat.vst_mode & 07777;
        m++;
    }
    free(fds);
    *count = m;
    return rows;
}

/* ---- directory enumeration --------------------------------------------
 * Two levels: "/" lists the processes, "/<name> (<pid>)" lists that process's
 * open files. A process is a container of files, which is the one thing a file
 * manager can say about it that a task manager cannot. */
void *PfxFindFirst(void *conn, const char *dir) {
    Conn *c = (Conn *)conn;
    if (!c || !dir) return NULL;
    if (strcmp(dir, "/") == 0 || dir[0] == 0) {
        rebuild_snapshot(c);
        Find *f = (Find *)calloc(1, sizeof(Find));
        if (f) f->c = c;
        return f;   /* may be NULL on OOM; host treats that as "not a directory" */
    }
    const char *sub = NULL;
    int pid = split_process_path(dir, &sub);
    if (pid <= 0 || sub) return NULL;         /* only one level below a process */
    Find *f = (Find *)calloc(1, sizeof(Find));
    if (!f) return NULL;
    f->c = c;
    f->rows = collect_open_files(pid, &f->n);   /* NULL + n == 0: an empty folder */
    return f;
}

int PfxFindNext(void *find, PfxFindData *out) {
    if (!find || !out) return 0;
    Find *f = (Find *)find;
    memset(out, 0, sizeof(*out));
    if (f->rows || f->n) {                      /* inside a process: its open files */
        if (f->index >= f->n) return 0;
        const FileRow *r = &f->rows[f->index++];
        strncpy(out->name, r->name, sizeof(out->name) - 1);
        out->size  = r->size;
        out->mtime = r->mtime;
        out->mode  = r->mode;
        out->isDir = 0;     /* an open directory is listed, but not descended into */
        return 1;
    }
    if (f->index >= f->c->cur_n) return 0;
    const Proc *p = &f->c->cur[f->index++];
    snprintf(out->name, sizeof(out->name), "%s (%d)", p->name, p->pid);
    out->size  = p->have_task ? p->rss : -1;
    out->mtime = p->start;
    out->isDir = 1;         /* enterable: the files it has open (F-391) */
    return 1;
}

void PfxFindClose(void *find) {
    if (!find) return;
    free(((Find *)find)->rows);
    free(find);
}

int PfxStat(void *conn, const char *path, PfxFindData *out) {
    Conn *c = (Conn *)conn;
    if (!c || !path || !out) return PC_E_NOT_SUPPORTED;
    if (strcmp(path, "/") == 0) {   /* the mount root */
        memset(out, 0, sizeof(*out));
        strcpy(out->name, "/"); out->isDir = 1; out->size = -1;
        return PC_OK;
    }
    const char *sub = NULL;
    int pid = split_process_path(path, &sub);
    if (sub) {                      /* an open file of that process */
        char real[1024];
        dec_path(sub, real, sizeof(real));
        struct stat st;
        if (stat(real, &st) != 0) return PC_E_EOPEN;
        memset(out, 0, sizeof(*out));
        strncpy(out->name, sub, sizeof(out->name) - 1);
        out->size  = (int64_t)st.st_size;
        out->mtime = (int64_t)st.st_mtime;
        out->mode  = st.st_mode & 07777;
        out->isDir = 0;
        return PC_OK;
    }
    const Proc *p = find_proc(c, pid);
    if (!p) return PC_E_EOPEN;
    memset(out, 0, sizeof(*out));
    snprintf(out->name, sizeof(out->name), "%s (%d)", p->name, p->pid);
    out->size  = p->have_task ? p->rss : -1;
    out->mtime = p->start;
    out->isDir = 1;
    return PC_OK;
}

/* ---- content-column facet ----------------------------------------------
 * The start time is carried by the entry's built-in mtime (the host's Date
 * column). Memory is NOT carried by the size any more: a process row is a
 * directory since F-391 and the host draws "<DIR>" for a directory's size, so
 * memory became a column of its own — as PFX_FT_SIZE, which the host renders in
 * KB/MB and sorts by the byte count behind it. */
int PfxContentFieldCount(void) { return 13; }

void PfxContentField(int index, PfxFieldInfo *out) {
    if (!out) return;
    memset(out, 0, sizeof(*out));
    struct { const char *name, *title; int type, w; } F[] = {
        { "pid",     "PID",     PFX_FT_NUMERIC,  56 },
        { "cpu",     "CPU %",   PFX_FT_NUMERIC,  60 },
        { "mem",     "Memory",  PFX_FT_SIZE,     84 },
        { "rss",     "Resident", PFX_FT_SIZE,    84 },
        { "threads", "Threads", PFX_FT_NUMERIC,  64 },
        { "state",   "State",   PFX_FT_STRING,   52 },
        { "user",    "User",    PFX_FT_STRING,   90 },
        { "ppid",    "PPID",    PFX_FT_NUMERIC,  56 },
        { "read",    "Read",    PFX_FT_SIZE,     84 },
        { "written", "Written", PFX_FT_SIZE,     84 },
        { "wakeups", "Wakeups", PFX_FT_NUMERIC,  74 },
        { "signed",  "Signed",  PFX_FT_STRING,  150 },
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
    /* Resident size comes from the task info for our own processes and from `ps`
     * for everyone else's; both are the same measurement, so one column carries
     * them. Thread counts have no such fallback and stay blank. */
    char res[32] = "";
    if (p->have_task || p->from_ps) snprintf(res, sizeof(res), "%lld", (long long)p->rss);
    /* What `ps` reports, which on this OS is the only source that distinguishes anything; the
     * kernel's own letter is the fallback for a process it did not list. */
    char st[8];
    if (p->state_str[0]) snprintf(st, sizeof(st), "%s", p->state_str);
    else { st[0] = p->state; st[1] = 0; }

    const char *user = user_name(c, p->uid);

    /* Byte counts go out as plain numbers — PFX_FT_SIZE means the host renders
     * them. A blank stays blank: a process whose metrics we may not read must not
     * claim "0 bytes read", which is a measurement and not a missing one. */
    char mem[32] = "", rd[32] = "", wr[32] = "", wk[32] = "";
    if (p->have_rusage) {
        snprintf(mem, sizeof(mem), "%llu", (unsigned long long)p->footprint);
        snprintf(rd,  sizeof(rd),  "%llu", (unsigned long long)p->io_read);
        snprintf(wr,  sizeof(wr),  "%llu", (unsigned long long)p->io_write);
        snprintf(wk,  sizeof(wk),  "%llu", (unsigned long long)p->wakeups);
    }

    /* Resolved when the snapshot was built; empty until its signature has been read. */
    const char *sig = p->signer ? p->signer : "";

    /* Order MUST match PfxContentField:
     * pid,cpu,mem,rss,threads,state,user,ppid,read,written,wakeups,signed,command */
    snprintf(out, (size_t)maxlen, "%d\t%s\t%s\t%s\t%s\t%s\t%s\t%d\t%s\t%s\t%s\t%s\t%s",
             p->pid, cpu, mem, res, thr, st, user, p->ppid, rd, wr, wk, sig, p->command);
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

/* ---- lookup facet: "file:<path>" -> processes holding that file open ---- */

#define HANDLE_READ  1
#define HANDLE_WRITE 2

/* How process `pid` has the file (dev,ino) open: a HANDLE_READ|HANDLE_WRITE mask
 * over all of its vnode fds, 0 if it does not hold it (or we may not look).
 *
 * Identity is the (device, inode) pair rather than the path string: the same file
 * has many spellings — /tmp vs /private/tmp, a relative open, a hard link, a path
 * longer than vip_path's MAXPATHLEN tail — and each of them would be a miss.
 *
 * Like the port scan, this only sees the caller's own processes unprivileged.
 * Mapped images (a loaded dylib, the executable itself) and the working directory
 * are NOT fds and so are deliberately not reported. */
static int pid_file_handles(int pid, uint32_t dev, uint64_t ino) {
    int bufsize = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, NULL, 0);
    if (bufsize <= 0) return 0;
    struct proc_fdinfo *fds = (struct proc_fdinfo *)malloc((size_t)bufsize);
    if (!fds) return 0;
    int n = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, fds, bufsize);
    int count = n > 0 ? n / (int)sizeof(struct proc_fdinfo) : 0;
    int mask = 0;
    for (int i = 0; i < count; i++) {
        if (fds[i].proc_fdtype != PROX_FDTYPE_VNODE) continue;
        struct vnode_fdinfowithpath vi;
        if (proc_pidfdinfo(pid, fds[i].proc_fd, PROC_PIDFDVNODEPATHINFO,
                           &vi, sizeof(vi)) != (int)sizeof(vi)) continue;
        if (vi.pvip.vip_vi.vi_stat.vst_dev != dev ||
            vi.pvip.vip_vi.vi_stat.vst_ino != ino) continue;
        /* `fi_openflags` is the kernel's f_flag, NOT the O_* flags open() was given:
         * they differ by one (FFLAGS(oflags) == oflags + 1), so O_RDONLY arrives as
         * FREAD == O_WRONLY's value. Testing it as O_ACCMODE reports every reader as
         * a writer — which it did, until a read-only handle came back "w". */
        if (vi.pfi.fi_openflags & FREAD)  mask |= HANDLE_READ;
        if (vi.pfi.fi_openflags & FWRITE) mask |= HANDLE_WRITE;
        if (mask == (HANDLE_READ | HANDLE_WRITE)) break;   /* cannot get any richer */
    }
    free(fds);
    return mask;
}

/* Every process holding `path` open, one per line: "/<name> (<pid>)\t<r|w|b>".
 * r = read-only handles, w = write-only, b = both (an O_RDWR handle, or one of
 * each). Truncated cleanly at `maxlen` — a half-written last line would be a row
 * the host cannot match to any process. */
static int lookup_file(Conn *c, const char *path, char *out, int maxlen) {
    struct stat st;
    if (!path || !path[0] || stat(path, &st) != 0) return 0;
    if (c->cur_n == 0) rebuild_snapshot(c);
    size_t used = 0;
    int hits = 0;
    for (int i = 0; i < c->cur_n; i++) {
        int mask = pid_file_handles(c->cur[i].pid, (uint32_t)st.st_dev, (uint64_t)st.st_ino);
        if (!mask) continue;
        char line[512];
        int len = snprintf(line, sizeof(line), "%s/%s (%d)\t%s", used ? "\n" : "",
                           c->cur[i].name, c->cur[i].pid,
                           mask == (HANDLE_READ | HANDLE_WRITE) ? "b"
                               : (mask == HANDLE_WRITE ? "w" : "r"));
        if (len < 0) continue;
        if (used + (size_t)len + 1 > (size_t)maxlen) break;   /* +1 for the NUL */
        memcpy(out + used, line, (size_t)len);
        used += (size_t)len;
        hits++;
    }
    out[used] = 0;
    return hits > 0;
}

int PfxLookup(void *conn, const char *query, char *out, int maxlen) {
    Conn *c = (Conn *)conn;
    if (!c || !query || !out || maxlen <= 0) return 0;
    if (strncmp(query, "file:", 5) == 0) return lookup_file(c, query + 5, out, maxlen);
    if (strncmp(query, "port:", 5) != 0) return 0;   /* "port:<n>" or "file:<path>" */
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
    const char *sub = NULL;
    (void)split_process_path(path, &sub);
    /* Deleting a row inside a process would mean deleting a file the process has
     * open — this plugin lists those, it does not remove them. Refused explicitly,
     * because `pid_from_path` used to answer with the parent's pid for such a path:
     * F8 on an open file would have signalled the process that had it open. */
    if (sub) return PC_E_NOT_SUPPORTED;
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

/* Copy an open file out, so F3 on a row inside a process shows the file itself
 * rather than a report about it. The host asked for a local copy; a plugin path
 * is not one, even when the bytes happen to live on this disk. */
static int copy_out(const char *src, const char *dst) {
    struct stat st;
    if (stat(src, &st) != 0) return PC_E_EOPEN;
    if (S_ISDIR(st.st_mode)) return PC_E_NOT_SUPPORTED;   /* a directory fd is not a file */
    FILE *in = fopen(src, "rb");
    if (!in) return PC_E_EOPEN;
    FILE *out = fopen(dst, "wb");
    if (!out) { fclose(in); return PC_E_ECREATE; }
    char buf[65536];
    size_t got;
    int rc = PC_OK;
    while ((got = fread(buf, 1, sizeof(buf), in)) > 0) {
        if (fwrite(buf, 1, got, out) != got) { rc = PC_E_EWRITE; break; }
    }
    if (ferror(in)) rc = PC_E_EREAD;
    fclose(in); fclose(out);
    return rc;
}

int PfxGetFile(void *conn, const char *remotePath, const char *localPath) {
    Conn *c = (Conn *)conn;
    if (!c || !remotePath || !localPath) return PC_E_NOT_SUPPORTED;
    const char *sub = NULL;
    (void)split_process_path(remotePath, &sub);
    if (sub) {
        char real[1024];
        dec_path(sub, real, sizeof(real));
        return copy_out(real, localPath);
    }
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
    fprintf(f, "State:     %s (%s)\n",
            state_name(p->state_str[0] ? p->state_str[0] : p->state),
            p->state_str[0] ? p->state_str : "?");
    if (p->have_task) {
        fprintf(f, "Threads:   %d\n", p->threads);
        /* Both numbers, because they answer different questions and disagree by
         * design: the footprint is what this process is accountable for (what
         * Activity Monitor shows), the resident size includes shared pages it
         * merely touched. */
        if (p->have_rusage)
            fprintf(f, "Memory:    %.1f MB footprint\n", (double)p->footprint / (1024.0 * 1024.0));
        fprintf(f, "Resident:  %lld bytes (%.1f MB)\n",
                (long long)p->rss, (double)p->rss / (1024.0 * 1024.0));
        if (p->cpu_pct >= 0.0) fprintf(f, "CPU:       %.1f %%\n", p->cpu_pct);
        if (p->have_rusage) {
            fprintf(f, "Disk:      %.1f MB read, %.1f MB written\n",
                    (double)p->io_read / (1024.0 * 1024.0),
                    (double)p->io_write / (1024.0 * 1024.0));
            fprintf(f, "Wakeups:   %llu\n", (unsigned long long)p->wakeups);
        }
    } else if (p->from_ps) {
        /* Another user's process, as far as `ps` will say (F-394). Named as such,
         * because the CPU figure is a lifetime average and not the delta the rows
         * above carry — a number without its provenance invites the wrong reading. */
        fprintf(f, "Resident:  %lld bytes (%.1f MB)   [via ps]\n",
                (long long)p->rss, (double)p->rss / (1024.0 * 1024.0));
        if (p->cpu_pct >= 0.0) fprintf(f, "CPU:       %.1f %% (lifetime average)   [via ps]\n", p->cpu_pct);
        fprintf(f, "Threads:   (another user's process — not readable)\n");
    } else {
        /* Not "elevated privileges" in general: these read fine for every process
         * of your own uid. What is missing here is another user's. */
        fprintf(f, "Threads:   (another user's process — not readable)\n");
        fprintf(f, "Memory:    (another user's process — not readable)\n");
    }
    if (p->start > 0) {
        time_t t = (time_t)p->start;
        char tb[64]; struct tm tm;
        localtime_r(&t, &tm);
        strftime(tb, sizeof(tb), "%Y-%m-%d %H:%M:%S", &tm);
        fprintf(f, "Started:   %s\n", tb);
    }
    fprintf(f, "\nExecutable:\n  %s\n", p->command);

    /* Who signed it (F-393) — readable for every process, including root's, and
     * the question Process Explorer's "Verified Signer" column exists to answer. */
    uint32_t sflags = 0;
    const char *sig = sig_label(c, p->command, 1, &sflags);
    if (sig && sig[0]) {
        fprintf(f, "\nSignature:\n");
        fprintf(f, "  Signed by: %s\n", sig);
        fprintf(f, "  Hardened runtime: %s\n", (sflags & kSecCodeSignatureRuntime) ? "yes" : "no");
        if (sflags & kSecCodeSignatureAdhoc)   fprintf(f, "  Ad-hoc signature (no identity)\n");
        if (sflags & kSecCodeSignatureLibraryValidation)
            fprintf(f, "  Library validation enforced\n");
        char ents[4096];
        if (read_entitlements(p->command, ents, sizeof(ents)) && ents[0])
            fprintf(f, "\nEntitlements:\n%s", ents);
    }

    char cmd[4096];
    if (full_cmdline(p->pid, cmd, sizeof(cmd)))
        fprintf(f, "\nCommand line:\n  %s\n", cmd);

    fclose(f);
    return PC_OK;
}
