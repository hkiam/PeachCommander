// SPDX-License-Identifier: Apache-2.0
/* Bridging header: exposes the contribution behavior C-ABI to the plugin's Swift,
   plus the low-level filesystem APIs the fast scanner uses (getattrlistbulk et al.). */
#include "contrib.h"
#include <sys/attr.h>
#include <sys/vnode.h>
#include <unistd.h>
