---
title: Dekompilace Javy a .NET
slug: decompilers
section: Zásuvné moduly
order: 131
related: [plugins, viewing-files, searching]
---

Stiskněte **F3** na přeloženém souboru a uvidíte zdrojový kód místo bajtů. Dělají to dva pluginy — jeden pro Javu (`.class`, `.jar`, `.apk`, `.dex`) a jeden pro .NET (`.dll`, `.exe`, `.winmd`, `.netmodule`) — a chovají se stejně, proto tato stránka pokrývá oba. Každý lze samostatně vypnout nebo odstranit v **Konfigurace ▸ Pluginy…**.

Archiv se ukáže jako strom svých tříd, jednotlivá třída jako jeden soubor. **Dekompilovat do zdrojů** v nabídce Příkazy výsledek zapíše a umístí do panelu, takže v něm můžete hledat, porovnávat a kopírovat jako v každé jiné složce se zdroji.

## Engine si nainstalujete sami

Žádný dekompilátor není přibalen a nic se za vás nestahuje. Je to záměr ze dvou důvodů: JD-Core, nejznámější dekompilátor Javy, je pod GPLv3 a nemohl by být dodáván uvnitř aplikace pod Apache-2.0 — a enginy se zlepšují, takže jejich výměna by neměla vyžadovat novou verzi Peach Commanderu.

**Složka s enginy…** v prohlížeči otevře složku, kam patří. Tamní README jmenuje každý engine a jeho licenci.

| | |
| --- | --- |
| Java | CFR, Vineflower, Procyon, jadx (pro androidí `.dex` a `.apk`) a `javap` pro čistý bytekód |
| .NET | ILSpy a `monodis` pro IL |

**Zkontrolovat enginy** spustí u každého enginu příkaz pro zjištění verze a rozliší tři věci: nainstalováno a funkční, nenainstalováno, a *nainstalováno, ale nelze spustit* — nástroj Javy bez JDK je přítomen a přesto se nespustí, a odhalí to teprve skutečné spuštění.

Engine je popsán daty, nikoli kódem, takže si můžete přidat vlastní:

```
[cfr]
kinds  = class, jar
tool   = java
args   = -jar {engine} {input}
engine = ~/Library/Application Support/PeachCommander/decompilers/cfr.jar
output = stdout
```

Zvládne-li soubor více enginů, použije se první dostupný, pokud si jeden nevyberete. Jsou-li nainstalovány dva, **Porovnat** ukáže oba výsledky vedle sebe — hodí se, když jeden engine u metody vzdá to, co druhý zvládne.

## Hledání v přeloženém kódu

**Prohledat všechny třídy** prochází dekompilovaný text místo bajtů, takže v JARu najdete textový literál nebo název metody.

Dekompilace během *hledání v obsahu* napříč mnoha soubory je samostatný přepínač, ve výchozím stavu vypnutý: vytvořit text může znamenat spustit engine jednou na každou třídu, což na pomalém stroji není rozumné utrácet za hledání. Hlavní dialog hledání se ptá zvlášť; zde se to rovněž odmítá.

## Mezipaměť a limity

Výsledky se ukládají do mezipaměti, protože dekompilovat tutéž třídu dvakrát je čisté čekání. V předvolbách je, kolik dní se výsledky uchovávají, a **limit velikosti** mezipaměti; **Vymazat mezipaměť** ji vyprázdní a oznámí, kolik se uvolnilo.

Dva časové limity chrání před enginem, který neskončí: jeden pro jednu třídu či typ, jeden pro celý archiv. Oba přijímají 0, což znamená „použít výchozí hodnotu enginu“.
