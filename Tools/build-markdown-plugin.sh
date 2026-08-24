#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# build-markdown-plugin.sh — build Markdown.plxplugin, the renderer for .md and .html.
#
# This plugin is the application's ONLY renderer for those formats: the core gave both up, so a
# build that silently skips this script produces an app in which pressing F3 on a README shows its
# source. Hence the hard failures below rather than warnings.
#
# The parser is swift-markdown over cmark-gfm, compiled in below. That is the freedom this plugin was
# created for: the application links neither, and never will.
#
# It links two of the host's frameworks and carries no copy of what they provide:
#
#   * PCFoundation — SyntaxHighlighter (so a fence is coloured the way the editor colours the same
#     language) and DeclarationOutline (so the plugin's outline and the host's agree).
#   * PCVFS — EncodingDetector, which is what makes a Windows-written HTML file readable.
#
# The framework-locating and architecture-clamping logic is build-ai-plugin.sh's, for the reason
# stated there: a plugin can only be as universal as the frameworks it links against, and asking
# xcodebuild for BUILT_PRODUCTS_DIR answers with a DerivedData tree that may never have been built.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$(pwd)"
DEFAULT_DIR="$HOME/Library/Application Support/PeachCommander/plugins"
OUT_DIR="${1:-$DEFAULT_DIR}"
BUNDLE="$OUT_DIR/Markdown.plxplugin"
# Universal (arm64 + x86_64) plugin builds — see Tools/lib/pc-universal.sh.
source "$ROOT/Tools/lib/pc-universal.sh"

FWDIR="${PC_FRAMEWORKS_DIR:-}"
if [ -z "$FWDIR" ]; then
  for cand in "$ROOT/build/Build/Products/Debug" \
              "$(xcodebuild -project "$ROOT/PeachCommander.xcodeproj" -scheme PeachCommander \
                 -configuration Debug -showBuildSettings 2>/dev/null \
                 | awk -F' = ' '/ BUILT_PRODUCTS_DIR /{print $2; exit}')"; do
    if [ -n "$cand" ] && [ -d "$cand/PCFoundation.framework" ]; then FWDIR="$cand"; break; fi
  done
fi
for fw in PCFoundation PCVFS; do
  [ -d "$FWDIR/$fw.framework" ] || {
    echo "$fw.framework not found in '$FWDIR' — build the app first" >&2; exit 1; }
done

# Clamp the slice list to what the frameworks actually contain (see the header note).
FW_BIN="$FWDIR/PCFoundation.framework/Versions/A/PCFoundation"
[ -f "$FW_BIN" ] || FW_BIN="$FWDIR/PCFoundation.framework/PCFoundation"
if [ -f "$FW_BIN" ]; then
  FW_ARCHS="$(lipo -archs "$FW_BIN" 2>/dev/null || echo "")"
  if [ -n "$FW_ARCHS" ]; then
    CLAMPED=""
    for a in $PC_PLUGIN_ARCHS; do
      case " $FW_ARCHS " in *" $a "*) CLAMPED="${CLAMPED:+$CLAMPED }$a" ;; esac
    done
    if [ -z "$CLAMPED" ]; then
      echo "error: PCFoundation.framework has [$FW_ARCHS], none of the requested [$PC_PLUGIN_ARCHS]" >&2
      exit 1
    fi
    if [ "$CLAMPED" != "$PC_PLUGIN_ARCHS" ]; then
      echo "note: building for [$CLAMPED] — PCFoundation.framework provides only [$FW_ARCHS]"
    fi
    PC_PLUGIN_ARCHS="$CLAMPED"
  fi
fi

# ---- The parser -----------------------------------------------------------------------------
#
# swift-markdown over cmark-gfm, compiled into the plugin. Referenced, not vendored: both are pinned
# in project.yml and resolved into build/spm, exactly as build-terminal-plugin.sh does with SwiftTerm
# and for the reason it gives — 30 000 lines of somebody else's code stay out of this repository,
# while Tools/generate-third-party-notices.py still reads their licences from Package.resolved.
#
# No CMake is needed, which was the assumption this step had to check first: swift-cmark ships a
# prebuilt `cmark-gfm_config.h` for exactly the case where CMake did not run (`CMARK_USE_CMAKE_HEADERS`
# undefined), so the C sources compile with nothing but include paths.
SPM_DIR="$ROOT/build/spm"
CMARK="$SPM_DIR/checkouts/swift-cmark"
MARKDOWN="$SPM_DIR/checkouts/swift-markdown"
if [ ! -d "$CMARK/src" ] || [ ! -d "$MARKDOWN/Sources/Markdown" ]; then
  echo "==> Resolving swift-markdown + swift-cmark (pinned in project.yml) into build/spm…"
  if [ ! -f "$ROOT/PeachCommander.xcodeproj/project.pbxproj" ]; then
    echo "==> No generated project yet; running xcodegen for the pins"
    (cd "$ROOT" && xcodegen generate >/dev/null)
  fi
  xcodebuild -project "$ROOT/PeachCommander.xcodeproj" -resolvePackageDependencies \
    -clonedSourcePackagesDirPath "$SPM_DIR" >/dev/null
fi
for d in "$CMARK/src" "$CMARK/extensions" "$MARKDOWN/Sources/Markdown" "$MARKDOWN/Sources/CAtomic"; do
  [ -d "$d" ] || { echo "error: missing after resolve: $d" >&2; exit 1; }
done

# The C half: cmark-gfm, its extensions, and swift-markdown's one-file atomics shim. clang takes
# several -arch flags and emits a fat object, so this is one call however many slices are wanted.
COBJ_DIR="$(mktemp -d)"
trap 'rm -rf "$COBJ_DIR"' EXIT
CMARK_INCLUDES=(-I "$CMARK/src/include" -I "$CMARK/extensions/include"
                -I "$MARKDOWN/Sources/CAtomic/include")
(cd "$COBJ_DIR" && pc_clang -c -O2 -std=gnu11 -mmacosx-version-min="$PC_PLUGIN_DEPLOY" \
   "${CMARK_INCLUDES[@]}" \
   "$CMARK"/src/*.c "$CMARK"/extensions/*.c "$MARKDOWN/Sources/CAtomic/CAtomic.c")
CMARK_OBJS=()
while IFS= read -r -d '' o; do CMARK_OBJS+=("$o"); done < <(find "$COBJ_DIR" -name '*.o' -print0)
[ "${#CMARK_OBJS[@]}" -gt 0 ] || { echo "error: cmark produced no objects" >&2; exit 1; }

# The Swift half. swift-markdown's directories have SPACES in them ("Block Nodes"), so the file list
# goes through an array and -print0 — word splitting and swiftc response files both break on it, and
# the failure reads as "error opening input file 'Blocks/BlockQuote.swift'", naming a path that does
# not exist and no file that does.
MARKDOWN_SOURCES=()
while IFS= read -r -d '' f; do MARKDOWN_SOURCES+=("$f"); done \
  < <(find "$MARKDOWN/Sources/Markdown" -name '*.swift' -print0 | sort -z)
[ "${#MARKDOWN_SOURCES[@]}" -gt 0 ] || { echo "error: no swift-markdown sources found" >&2; exit 1; }

# Compiled into the plugin's own module rather than a separate `Markdown` one. A two-step build would
# keep the names namespaced, but `pc_swiftc` compiles one slice per architecture and a per-slice
# module path cannot be threaded through it — and there is no collision to solve: swift-markdown's
# Document, Table, Text and Image meet nothing of ours. Should one ever appear, the fix is a
# per-architecture loop here, not a rename over there.
MODULE_FLAGS=(
  -Xcc -I"$CMARK/src/include"
  -Xcc -I"$CMARK/extensions/include"
  -Xcc -I"$MARKDOWN/Sources/CAtomic/include"
  -Xcc -fmodule-map-file="$CMARK/src/include/module.modulemap"
  -Xcc -fmodule-map-file="$CMARK/extensions/include/module.modulemap"
  -Xcc -fmodule-map-file="$MARKDOWN/Sources/CAtomic/include/module.modulemap"
)

rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS"
cp "$ROOT/Plugins/Markdown/Info.plist" "$BUNDLE/Contents/Info.plist"

pc_swiftc -emit-library -O \
  -module-name PCMarkdownPlugin \
  -target "$TARGET" \
  -framework AppKit -framework WebKit \
  -F "$FWDIR" -framework PCFoundation -framework PCVFS \
  -Xlinker -rpath -Xlinker "$FWDIR" \
  -Xlinker -rpath -Xlinker "@executable_path/../Frameworks" \
  -import-objc-header "$ROOT/Plugins/Markdown/MarkdownBridging.h" \
  -Xcc -I"$ROOT/Plugins/SDK" \
  "${MODULE_FLAGS[@]}" \
  -o "$BUNDLE/Contents/MacOS/Markdown" \
  "${MARKDOWN_SOURCES[@]}" \
  "${CMARK_OBJS[@]}" \
  "$ROOT/Plugins/Markdown/MarkdownHTML.swift" \
  "$ROOT/Plugins/Markdown/markdown_lister.swift" \
  "$ROOT/Plugins/Markdown/MarkdownListerView.swift" \
  "$ROOT/Plugins/Markdown/MarkdownWebView.swift" \
  "$ROOT/Plugins/Markdown/MarkdownThumbnail.swift" \
  "$ROOT/Plugins/Markdown/MarkdownAssets.swift" \
  "$ROOT/Plugins/Markdown/MarkdownOptions.swift" \
  "$ROOT/Plugins/Markdown/MarkdownSettings.swift" \
  "$ROOT/Plugins/SDK/PluginLoc.swift" \
  "$ROOT/Plugins/Markdown/MarkdownEngines.swift" \
  "$ROOT/Plugins/Markdown/MarkdownDocument.swift"

if [ -d "$ROOT/Plugins/Markdown/Resources" ]; then
  mkdir -p "$BUNDLE/Contents/Resources"
  cp -R "$ROOT/Plugins/Markdown/Resources/." "$BUNDLE/Contents/Resources/"
fi

# The rendering engines, from the repository's single vendored copy. Copied rather than duplicated
# into Plugins/Markdown/Resources: Vendor/mermaid is 3.2 MB and the documentation website ships the
# same file (docs/scripts/build-site.py), so a second copy in git would be the wrong kind of
# convenience. A missing engine is a hard failure — the plugin would otherwise load, claim every .md
# and draw no diagram, which is worse than not building.
ENGINES="$BUNDLE/Contents/Resources/engines"
mkdir -p "$ENGINES/fonts"
for f in "$ROOT/Vendor/mermaid/mermaid.min.js" \
         "$ROOT/Vendor/katex/katex.min.js" \
         "$ROOT/Vendor/katex/katex.min.css" \
         "$ROOT/Vendor/katex/auto-render.min.js"; do
  [ -f "$f" ] || { echo "error: vendored engine missing: ${f#"$ROOT"/}" >&2; exit 1; }
  cp "$f" "$ENGINES/"
done
cp "$ROOT/Vendor/katex/"fonts/*.woff2 "$ENGINES/fonts/"
# The licences travel with the files they cover, as they do beside the FSImage plugin's zstd.
cp "$ROOT/Vendor/mermaid/LICENSE" "$ENGINES/mermaid-LICENSE.txt"
cp "$ROOT/Vendor/katex/LICENSE" "$ENGINES/katex-LICENSE.txt"

echo "Built $BUNDLE"
echo "  linked PCFoundation + PCVFS from: $FWDIR"
