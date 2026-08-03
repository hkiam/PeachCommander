// SPDX-License-Identifier: Apache-2.0
/* Bridging header: the lister ABI plus the contribution behavior ABI.
 *
 * This plugin is both. `plx` is what F3 routes through; the contribution facet is what puts the
 * decompiled sources into a file panel, where the rest of Peach Commander can reach them. The host
 * loads contributions for any plugin type whose manifest declares them, so one bundle covers both. */
#include "contrib.h"
