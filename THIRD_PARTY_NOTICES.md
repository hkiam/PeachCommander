# Third-Party Notices

Peach Commander gratefully builds on the work of the open-source community. Thank you to all the authors and contributors of the projects listed here.

This product includes the following open-source software — plus, where a row says so, software that is described here without shipping in the app. The full license text of each is in `Resources/Licenses/`.

## Sparkle 2.6.3

- **License:** MIT
- **Copyright (c) 2006 Andy Matuschak and Sparkle contributors.**
- Software update framework that powers the app's in-app updates.
- Repository: https://github.com/sparkle-project/Sparkle
- License text: `Resources/Licenses/Sparkle.txt`

## SwiftTerm 1ca2441

- **License:** MIT
- **Copyright (c) 2019-2026 Miguel de Icaza; portions (c) 2017-2019 The xterm.js authors; (c) 2014-2016 SourceLair Private Company.**
- Terminal emulator (xterm-compatible) behind the embedded terminal plugin.
- Repository: https://github.com/migueldeicaza/SwiftTerm
- License text: `Resources/Licenses/SwiftTerm.txt`

## Swift Argument Parser 1.8.2

- **License:** Apache-2.0
- **Copyright (c) 2020 Apple Inc. and the Swift project authors.**
- Resolved as a dependency of SwiftTerm's command-line sample target; not compiled into, or shipped with, this application.
- Repository: https://github.com/apple/swift-argument-parser
- License text: `Resources/Licenses/swift-argument-parser.txt`

## Swift Markdown 0.8.0

- **License:** Apache-2.0
- **Copyright (c) 2021 Apple Inc. and the Swift project authors.**
- CommonMark/GitHub-Flavored Markdown parser behind the Markdown lister plugin; its syntax tree is what the plugin walks to emit HTML.
- Repository: https://github.com/apple/swift-markdown
- License text: `Resources/Licenses/swift-markdown.txt`

## swift-cmark (cmark-gfm) gfm (7898f1b)

- **License:** BSD-2-Clause AND MIT
- **Copyright (c) 2014 John MacFarlane; portions (c) 2011 Vicent Marti and (c) 2009 Natacha Porte; GFM extensions (c) 2017 GitHub, Inc.**
- The C parser under Swift Markdown: cmark-gfm and its GitHub-Flavored extensions (tables, task lists, strikethrough, autolinks), compiled into the Markdown lister plugin.
- Repository: https://github.com/apple/swift-cmark
- License text: `Resources/Licenses/swift-cmark.txt`

## SwiftTreeSitter main (0f40435)

- **License:** BSD-3-Clause
- **Copyright (c) 2021, Chime**
- Swift bindings for the tree-sitter parsing library, used for syntax highlighting and the symbol outline.
- Repository: https://github.com/ChimeHQ/SwiftTreeSitter
- License text: `Resources/Licenses/SwiftTreeSitter.txt`

## Neon main (484d6fb)

- **License:** BSD-3-Clause
- **Copyright (c) 2022, Chime**
- Incremental syntax-highlighting engine for the built-in text editor.
- Repository: https://github.com/ChimeHQ/Neon
- License text: `Resources/Licenses/Neon.txt`

## Rearrange 2.1.1

- **License:** BSD-3-Clause
- **Copyright (c) 2019, Chime Systems Inc.**
- Text-range utilities used by Neon (transitive dependency).
- Repository: https://github.com/ChimeHQ/Rearrange
- License text: `Resources/Licenses/Rearrange.txt`

## tree-sitter 0.25.10

- **License:** MIT
- **Copyright (c) 2018-2024 Max Brunsfeld**
- Incremental parsing library; the runtime behind syntax highlighting and the symbol outline.
- Repository: https://github.com/tree-sitter/tree-sitter
- License text: `Resources/Licenses/tree-sitter.txt`

## tree-sitter-json master (001c28d)

- **License:** MIT
- **Copyright (c) 2014 Max Brunsfeld**
- JSON grammar for tree-sitter.
- Repository: https://github.com/tree-sitter/tree-sitter-json
- License text: `Resources/Licenses/tree-sitter-json.txt`

## tree-sitter-c master (b780e47)

- **License:** MIT
- **Copyright (c) 2014 Max Brunsfeld**
- C grammar for tree-sitter.
- Repository: https://github.com/tree-sitter/tree-sitter-c
- License text: `Resources/Licenses/tree-sitter-c.txt`

## tree-sitter-java master (e10607b)

- **License:** MIT
- **Copyright (c) 2017 Ayman Nadeem**
- Java grammar for tree-sitter.
- Repository: https://github.com/tree-sitter/tree-sitter-java
- License text: `Resources/Licenses/tree-sitter-java.txt`

## tree-sitter-javascript v0.25.8

- **License:** MIT
- **Copyright (c) 2014 Max Brunsfeld**
- JavaScript grammar for tree-sitter (vendored).
- Repository: https://github.com/tree-sitter/tree-sitter-javascript
- License text: `Resources/Licenses/tree-sitter-javascript.txt`

## tree-sitter-python v0.25.9

- **License:** MIT
- **Copyright (c) 2016 Max Brunsfeld**
- Python grammar for tree-sitter (vendored).
- Repository: https://github.com/tree-sitter/tree-sitter-python
- License text: `Resources/Licenses/tree-sitter-python.txt`

## Zstandard 1.5.6 (single-file decoder)

- **License:** BSD-3-Clause
- **Copyright (c) Meta Platforms, Inc. and affiliates.**
- Zstandard decompression, used by the Linux filesystem-image plugin to read zstd-compressed SquashFS and Btrfs images. Dual-licensed BSD-3-Clause OR GPL-2.0; this product takes the BSD option. Decompression only.
- Repository: https://github.com/facebook/zstd
- License text: `Resources/Licenses/zstd.txt`

## tree-sitter-rust vendored

- **License:** MIT
- **Copyright (c) 2017 Maxim Sokolov**
- Rust grammar for tree-sitter (vendored).
- Repository: https://github.com/tree-sitter/tree-sitter-rust
- License text: `Resources/Licenses/tree-sitter-rust.txt`

## tree-sitter-c-sharp vendored

- **License:** MIT
- **Copyright (c) 2014-2023 Max Brunsfeld, Damien Guard, Amaan Qureshi, and contributors.**
- C# grammar for tree-sitter (vendored).
- Repository: https://github.com/tree-sitter/tree-sitter-c-sharp
- License text: `Resources/Licenses/tree-sitter-c-sharp.txt`

## tree-sitter-typescript vendored

- **License:** MIT
- **Copyright (c) 2017 Max Brunsfeld**
- TypeScript grammar for tree-sitter (vendored).
- Repository: https://github.com/tree-sitter/tree-sitter-typescript
- License text: `Resources/Licenses/tree-sitter-typescript.txt`

## Mermaid 11.15.0

- **License:** MIT
- **Copyright (c) 2014 - 2022 Knut Sveidqvist**
- _Documentation website, and bundled inside the removable Markdown lister plugin._
- Renders the architecture diagrams on the documentation website, and the ```mermaid blocks in a Markdown file opened with F3. Vendored at Vendor/mermaid/ — served from that site so it needs no CDN, and shipped inside the Markdown lister plugin, which draws the same diagrams in the file viewer; not linked into, bundled with, or invoked by the application.
- Repository: https://github.com/mermaid-js/mermaid
- License text: `Resources/Licenses/mermaid.txt`

## KaTeX 0.16.47

- **License:** MIT
- **Copyright (c) 2013-2020 Khan Academy and other contributors**
- _Bundled inside the removable Markdown lister plugin._
- Typesets $…$ and $$…$$ in a Markdown file opened with F3, inside the removable Markdown lister plugin. Vendored at Vendor/katex/ with its script, its stylesheet, its own auto-render extension and the woff2 faces; nothing is fetched at runtime.
- Repository: https://github.com/KaTeX/KaTeX
- License text: `Resources/Licenses/katex.txt`

## libssh2 1.11.1

- **License:** BSD-3-Clause
- **Copyright (c) 2004-2023 Daniel Stenberg and the libssh2 contributors.**
- _Bundled into installer (DMG) builds._
- SSH2 client library powering the SFTP/SCP support. Bundled into installer (DMG) builds.
- Repository: https://github.com/libssh2/libssh2
- License text: `Resources/Licenses/libssh2.txt`

## OpenSSL 3.6.3

- **License:** Apache-2.0
- **Copyright (c) 1998-2024 The OpenSSL Project Authors. All Rights Reserved.**
- _Bundled into installer (DMG) builds._
- Cryptography and TLS library used by libssh2. Bundled into installer (DMG) builds.
- Repository: https://github.com/openssl/openssl
- License text: `Resources/Licenses/OpenSSL.txt`

## External tools (invoked, not redistributed)

- **7-Zip / p7zip** — LGPL-2.1+ / GNU — https://www.7-zip.org (Invoked as an external command for some archive formats when installed.)
- **libarchive (bsdtar)** — BSD-2-Clause — https://www.libarchive.org (Invoked via /usr/bin/tar for tar/gzip/xz archives.)
- **The Unarchiver (unar/lsar)** — LGPL-2.1 — https://theunarchiver.com (Optionally invoked to read RAR archives when installed.)
