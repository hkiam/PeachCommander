// SPDX-License-Identifier: Apache-2.0
/*
 * pc_plugin_guard.h - In-process crash guard for plugin C calls (F-230).
 *
 * Runs a callback under a fatal-signal guard so a misbehaving plugin
 * (SIGSEGV/SIGBUS/SIGILL/SIGFPE) does not take down the host: on such a signal
 * during the call, control returns here and the signal number is reported.
 *
 * Caveat: this is a pragmatic in-process guard, not a sandbox. Recovering from a
 * memory-corruption signal means some host state may leak or be inconsistent, so
 * the caller must treat a crashed plugin as untrusted (the Swift wrapper
 * quarantines it). True isolation would require an out-of-process host.
 */
#ifndef PC_PLUGIN_GUARD_H
#define PC_PLUGIN_GUARD_H

/*
 * Run fn(ctx) with the fatal-signal guard active on the current thread.
 * Returns 0 on normal completion, or the caught signal number if fn crashed.
 * Guards are per-thread and may nest across threads; outside a guarded call the
 * original crash behaviour (terminate + report) is preserved.
 */
int pc_guard_call(void (*fn)(void *), void *ctx);

#endif /* PC_PLUGIN_GUARD_H */
