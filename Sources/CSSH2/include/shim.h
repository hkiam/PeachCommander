// CSSH2 - libssh2 (+ SFTP) exposed to Swift. Header-only: Swift calls the real
// libssh2 *_ex functions directly (the convenience macros aren't importable),
// linked from the libssh2 dylib via the module map's `link "ssh2"`.
#include <libssh2.h>
#include <libssh2_sftp.h>
