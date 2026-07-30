#!/usr/bin/env bash
# pc-universal.sh — shared helpers so the external plugin bundles are built
# universal (arm64 + x86_64), matching the app itself.
#
# Sourced, not executed. Every Tools/build-*-plugin*.sh pulls this in and calls
# pc_swiftc / pc_clang instead of swiftc / clang.
#
# Why: the plugins used to be compiled for "$(uname -m)" only. Since the app is a
# universal build (project.yml sets ARCHS = arm64 x86_64), that produced a DMG
# whose app launched on Intel but whose plugins could not be loaded at all —
# silently dropping Git, Archive, WebDAV, Disk Map and the rest.
#
# clang takes several -arch flags in one invocation and emits a fat binary itself.
# swiftc does not: it accepts a single -target, so each slice is compiled
# separately and the results are merged with lipo.
#
# Override the slice list for a fast local build:
#   PC_PLUGIN_ARCHS=arm64 Tools/build-all-plugins.sh

PC_PLUGIN_ARCHS="${PC_PLUGIN_ARCHS:-arm64 x86_64}"
PC_PLUGIN_DEPLOY="${PC_PLUGIN_DEPLOY:-13.0}"

# Host triple, kept for scripts that still pass -target "$TARGET" — pc_swiftc
# replaces it per slice, so its value only matters if swiftc is called directly.
TARGET="$(uname -m)-apple-macos${PC_PLUGIN_DEPLOY}"

# pc_clang <clang args...> — same call, but fat.
pc_clang() {
  local archflags=() arch
  for arch in $PC_PLUGIN_ARCHS; do archflags+=(-arch "$arch"); done
  clang "${archflags[@]}" "$@"
}

# pc_swiftc <swiftc args...> — build every slice and lipo them together.
# Understands `-o <path>`; any `-target <triple>` the caller passes is dropped in
# favour of one triple per slice.
pc_swiftc() {
  local swiftc_bin
  # type -P searches PATH only, so this cannot resolve back to a shell function.
  swiftc_bin="$(type -P swiftc)" || { echo "error: swiftc not found in PATH" >&2; return 1; }

  local -a argv=("$@") args=()
  local out="" i=0 n=$#
  while [ "$i" -lt "$n" ]; do
    case "${argv[$i]}" in
      -o)       out="${argv[$((i + 1))]}"; i=$((i + 2)) ;;
      -target)  i=$((i + 2)) ;;
      *)        args+=("${argv[$i]}"); i=$((i + 1)) ;;
    esac
  done
  [ -n "$out" ] || { echo "error: pc_swiftc needs -o <output>" >&2; return 1; }

  local -a archs=($PC_PLUGIN_ARCHS)
  if [ "${#archs[@]}" -le 1 ]; then
    "$swiftc_bin" -target "${archs[0]}-apple-macos${PC_PLUGIN_DEPLOY}" "${args[@]}" -o "$out"
    return
  fi

  local tmp slices=() arch
  tmp="$(mktemp -d)" || return 1
  for arch in "${archs[@]}"; do
    if ! "$swiftc_bin" -target "${arch}-apple-macos${PC_PLUGIN_DEPLOY}" "${args[@]}" \
           -o "$tmp/$arch.dylib"; then
      rm -rf "$tmp"
      echo "error: swiftc failed for $arch" >&2
      return 1
    fi
    slices+=("$tmp/$arch.dylib")
  done
  lipo -create "${slices[@]}" -output "$out" || { rm -rf "$tmp"; return 1; }
  rm -rf "$tmp"
}
