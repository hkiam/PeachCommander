// Anchor so the static library is non-empty; no libssh2 wrappers live here —
// Swift calls the libssh2 *_ex functions directly.
int pc_cssh2_link_anchor(void) { return 0; }
