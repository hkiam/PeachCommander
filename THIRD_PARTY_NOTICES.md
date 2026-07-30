# Third-Party Notices

Peach Commander gratefully builds on the work of the open-source community. Thank you to all the authors and contributors of the projects listed here.

This product includes the following open-source software. The full license text of each is in `Resources/Licenses/`.

## Sparkle 2.6.3

- **License:** MIT
- **Copyright (c) 2006 Andy Matuschak and Sparkle contributors.**
- Software update framework that powers the app's in-app updates.
- Repository: https://github.com/sparkle-project/Sparkle
- License text: `Resources/Licenses/Sparkle.txt`

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
