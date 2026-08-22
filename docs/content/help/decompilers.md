---
title: Decompiling Java and .NET
slug: decompilers
group: Plugins
section: Plugins
order: 131
related: [plugins, viewing-files, searching]
---

Press **F3** on a compiled file and see source instead of bytes. Two plugins do this — one for Java (`.class`, `.jar`, `.apk`, `.dex`) and one for .NET (`.dll`, `.exe`, `.winmd`, `.netmodule`) — and they behave the same way, so this page covers both. Each can be turned off or removed on its own in **Configuration ▸ Plugins…**.

An archive shows as a tree of its classes; a single class shows as one file. **Decompile to Sources** in the Commands menu writes the result out and puts it in a panel, so you can search, compare and copy from it like any other folder of source.

## You install the engine

No decompiler is bundled and nothing is downloaded for you. That is deliberate on two counts: JD-Core, the best-known Java decompiler, is GPLv3 and could not ship inside an Apache-2.0 app — and engines improve, so swapping one should not require a new version of Peach Commander.

**Engine Folder…** in the viewer opens the folder they belong in. The README there names each engine and its licence.

| | |
| --- | --- |
| Java | CFR, Vineflower, Procyon, jadx (for Android `.dex` and `.apk`), and `javap` for plain bytecode |
| .NET | ILSpy, and `monodis` for IL |

**Check Engines** runs each engine's version command and tells you three different things apart: installed and working, not installed, and *installed but unable to run* — a Java tool without a JDK is present and still cannot start, and only actually running it reveals that.

An engine is described by data rather than code, so you can add one yourself:

```
[cfr]
kinds  = class, jar
tool   = java
args   = -jar {engine} {input}
engine = ~/Library/Application Support/PeachCommander/decompilers/cfr.jar
output = stdout
```

When more than one engine can handle a file, the first available is used unless you pick one. With two installed, **Compare** shows both results side by side — useful when one engine gives up on a method the other handles.

## Searching inside compiled code

**Search all classes** looks through the decompiled text rather than the bytes, so you can find a string literal or a method name in a JAR.

Decompiling during a *content search* over many files is a separate switch, off by default: producing the text can mean running the engine once per class, which on a slow machine is not a reasonable thing to spend a search on. The main search dialog asks separately; this refuses it here too.

## Cache and limits

Results are cached, because decompiling the same class twice is pure waiting. The settings hold how many days to keep results and a **size limit** for the cache; **Clear Cache Now** empties it and reports how much it freed.

Two timeouts guard against an engine that will not finish: one for a single class or type, one for a whole archive. Both accept 0, which means "use the engine's own default".
