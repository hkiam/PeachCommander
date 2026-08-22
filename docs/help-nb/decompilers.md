---
title: Dekompilere Java og .NET
slug: decompilers
section: Programtillegg
order: 131
related: [plugins, viewing-files, searching]
---

Trykk **F3** på en kompilert fil og se kildekode i stedet for byte. To programtillegg gjør dette — ett for Java (`.class`, `.jar`, `.apk`, `.dex`) og ett for .NET (`.dll`, `.exe`, `.winmd`, `.netmodule`) — og de oppfører seg likt, så denne siden dekker begge. Hvert av dem kan slås av eller fjernes for seg under **Konfigurasjon ▸ Programtillegg…**.

Et arkiv vises som et tre av klassene sine; en enkelt klasse som én fil. **Dekompiler til kilde** i Kommandoer-menyen skriver ut resultatet og legger det i et panel, så du kan søke, sammenligne og kopiere i det som i enhver annen kildekodemappe.

## Motoren installerer du selv

Ingen dekompilator følger med, og ingenting lastes ned for deg. Det er med vilje, av to grunner: JD-Core, den mest kjente Java-dekompilatoren, er GPLv3 og kunne ikke leveres inne i en Apache-2.0-app — og motorer blir bedre, så å bytte en bør ikke kreve en ny versjon av Peach Commander.

**Motormappe…** i viseren åpner mappen de hører hjemme i. README-filen der navngir hver motor og lisensen dens.

| | |
| --- | --- |
| Java | CFR, Vineflower, Procyon, jadx (for Androids `.dex` og `.apk`) og `javap` for ren bytekode |
| .NET | ILSpy, og `monodis` for IL |

**Kontroller motorer** kjører versjonskommandoen til hver motor og skiller mellom tre ting: installert og fungerer, ikke installert, og *installert, men ute av stand til å kjøre* — et Java-verktøy uten JDK er til stede og starter likevel ikke, og bare det å faktisk kjøre det avslører dette.

En motor beskrives av data og ikke av kode, så du kan legge til en selv:

```
[cfr]
kinds  = class, jar
tool   = java
args   = -jar {engine} {input}
engine = ~/Library/Application Support/PeachCommander/decompilers/cfr.jar
output = stdout
```

Når flere motorer klarer en fil, brukes den første tilgjengelige med mindre du velger en. Med to installert viser **Sammenlign** begge resultatene side om side — nyttig når den ene motoren gir opp på en metode den andre klarer.

## Å søke i kompilert kode

**Søk i alle klasser** går gjennom den dekompilerte teksten i stedet for bytene, så du kan finne en tekststreng eller et metodenavn i en JAR.

Å dekompilere under et *innholdssøk* over mange filer er en egen innstilling, av som standard: å produsere teksten kan bety at motoren kjøres én gang per klasse, noe som på en treg maskin ikke er rimelig å bruke på et søk. Hovedsøkevinduet spør separat; her avvises det også.

## Buffer og grenser

Resultater bufres, for å dekompilere den samme klassen to ganger er ren venting. I innstillingene står hvor mange dager resultater beholdes, og en **størrelsesgrense** for bufferen; **Tøm bufferen nå** tømmer den og melder hvor mye som ble frigjort.

To tidsgrenser beskytter mot en motor som ikke blir ferdig: én for én klasse eller type, én for et helt arkiv. Begge godtar 0, som betyr «bruk motorens egen standard».
