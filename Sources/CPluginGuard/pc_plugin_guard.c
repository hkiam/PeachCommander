// pc_plugin_guard.c - Fatal-signal guard for plugin C calls (F-230).

#include "pc_plugin_guard.h"

#include <signal.h>
#include <setjmp.h>
#include <stddef.h>
#include <pthread.h>

// The signals a crashing plugin is likely to raise.
static const int kSignals[] = { SIGSEGV, SIGBUS, SIGILL, SIGFPE };
enum { kNumSignals = 4 };

// Per-thread recovery point + state, so concurrent guards on different threads
// don't clobber each other. The handler runs on the crashing thread, so it sees
// that thread's own recovery point.
static _Thread_local sigjmp_buf t_jmp;
static _Thread_local volatile sig_atomic_t t_active = 0;
static _Thread_local volatile int t_signal = 0;

// Previous handlers (process-wide; installed once).
static struct sigaction g_prev[kNumSignals];

static void guard_handler(int signo) {
    if (t_active) {
        // Inside a guarded call: record + unwind back to pc_guard_call. Clearing
        // t_active first so a fault during unwinding falls through to default.
        t_active = 0;
        t_signal = signo;
        siglongjmp(t_jmp, signo);
    }
    // Not guarding: restore the default action and re-raise so ordinary crashes
    // still terminate the process and reach the crash reporter.
    for (int i = 0; i < kNumSignals; i++) {
        if (kSignals[i] == signo) {
            sigaction(signo, &g_prev[i], NULL);
            break;
        }
    }
    raise(signo);
}

static pthread_once_t g_once = PTHREAD_ONCE_INIT;
static void install_handlers(void) {
    struct sigaction sa;
    sa.sa_handler = guard_handler;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = SA_NODEFER;   // don't block the signal inside its own handler
    for (int i = 0; i < kNumSignals; i++) {
        sigaction(kSignals[i], &sa, &g_prev[i]);
    }
}

int pc_guard_call(void (*fn)(void *), void *ctx) {
    pthread_once(&g_once, install_handlers);
    t_signal = 0;
    // savesigs = 1 so the signal mask is restored on siglongjmp (the faulting
    // signal isn't left blocked).
    if (sigsetjmp(t_jmp, 1) == 0) {
        t_active = 1;
        fn(ctx);
        t_active = 0;
        return 0;
    }
    t_active = 0;
    return t_signal;
}
