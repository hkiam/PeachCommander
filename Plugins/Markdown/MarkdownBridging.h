// SPDX-License-Identifier: Apache-2.0
// The C ABI this plugin implements. plx.h forward-declares PcHostServices so it can
// compile standalone; contrib.h completes it, which is what ListLoadEx needs to read
// the host's context.
#include "plx.h"
#include "contrib.h"
