// SPDX-License-Identifier: Apache-2.0
// FSImageBridging.h — the PCX C ABI, imported into the plugin's Swift sources.

#include "pcx.h"

#include <stddef.h>

/*
 * Zstandard, from the vendored single-file decoder (Vendor/zstddeclib.c).
 *
 * Declared here rather than by including the amalgamation's own header: that file is
 * one 23,000-line translation unit that defines the whole library, and pulling it into
 * the Swift bridging header would compile it into every Swift file. Three prototypes
 * are all the plugin uses, and they are stable public API.
 */
size_t ZSTD_decompress(void *dst, size_t dstCapacity, const void *src, size_t compressedSize);
unsigned ZSTD_isError(size_t code);
const char *ZSTD_getErrorName(size_t code);
