---
title: Dekompilering af Java og .NET
slug: decompilers
section: Plugins
order: 131
related: [plugins, viewing-files, searching]
---

Tryk **F3** på en oversat fil, og se kildetekst i stedet for byte. To plugins gør det — et til Java (`.class`, `.jar`, `.apk`, `.dex`) og et til .NET (`.dll`, `.exe`, `.winmd`, `.netmodule`) — og de opfører sig ens, så denne side dækker begge. Hvert af dem kan slås fra eller fjernes for sig under **Konfiguration ▸ Plugins…**.

Et arkiv vises som et træ af sine klasser; en enkelt klasse som én fil. **Dekompiler til kildetekst** i menuen Kommandoer skriver resultatet ud og lægger det i et panel, så du kan søge, sammenligne og kopiere i det som i enhver anden mappe med kildetekst.

## Motoren installerer du selv

Ingen dekompilator følger med, og der hentes intet for dig. Det er med vilje, af to grunde: JD-Core, den mest kendte Java-dekompilator, er GPLv3 og kunne ikke leveres inde i en Apache-2.0-app — og motorer bliver bedre, så at skifte en bør ikke kræve en ny udgave af Peach Commander.

**Motormappe…** i fremviseren åbner den mappe, de hører til i. README-filen dér nævner hver motor og dens licens.

| | |
| --- | --- |
| Java | CFR, Vineflower, Procyon, jadx (til Androids `.dex` og `.apk`) og `javap` til ren bytekode |
| .NET | ILSpy og `monodis` til IL |

**Kontroller motorer** kører hver motors versionskommando og skelner mellem tre ting: installeret og virker, ikke installeret, og *installeret, men ude af stand til at køre* — et Java-værktøj uden JDK er til stede og starter alligevel ikke, og kun ved faktisk at køre det viser det sig.

En motor beskrives af data og ikke af kode, så du kan selv tilføje en:

```
[cfr]
kinds  = class, jar
tool   = java
args   = -jar {engine} {input}
engine = ~/Library/Application Support/PeachCommander/decompilers/cfr.jar
output = stdout
```

Når flere motorer kan klare en fil, bruges den første tilgængelige, medmindre du vælger en. Med to installeret viser **Sammenlign** begge resultater side om side — nyttigt, når den ene motor giver op på en metode, den anden klarer.

## At søge i oversat kode

**Søg i alle klasser** gennemgår den dekompilerede tekst i stedet for byte, så du kan finde en tekstkonstant eller et metodenavn i en JAR.

At dekompilere under en *indholdssøgning* på tværs af mange filer er en særskilt indstilling, slået fra som standard: at frembringe teksten kan betyde, at motoren køres én gang pr. klasse, hvilket på en langsom maskine ikke er noget rimeligt at bruge på en søgning. Hovedsøgevinduet spørger særskilt; her afvises det også.

## Cache og grænser

Resultater gemmes i cachen, for at dekompilere den samme klasse to gange er ren ventetid. I indstillingerne står, hvor mange dage resultater beholdes, og en **størrelsesgrænse** for cachen; **Tøm cachen nu** tømmer den og melder, hvor meget der blev frigjort.

To tidsgrænser beskytter mod en motor, der ikke bliver færdig: én for en enkelt klasse eller type, én for et helt arkiv. Begge accepterer 0, hvilket betyder “brug motorens egen standard”.
