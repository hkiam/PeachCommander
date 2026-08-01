---
title: Vise filer
slug: viewing-files
section: Vise og redigere
order: 70
related: [editing-files, searching]
---

Peach Commander har en innebygd visning som lar deg se inni en fil uten å åpne en annen app eller endre filen. Trykk F3 på elementet under markøren, så åpnes visningen umiddelbart, selv for svært store filer. Den velger automatisk den beste måten å vise innholdet på: lesbar tekst, syntaksfarget kode, en rå heksadesimaldump eller et bilde i full størrelse. Du kan også forhåndsvise en fil rett inne i vinduet ved hjelp av Quick View, eller overlate den til macOS Quick Look.

## Vis en fil

1. Flytt markøren til en fil i det aktive panelet.
2. Trykk F3 (eller velg Vis i Fil-menyen). Visningen åpnes i sitt eget vindu.
3. Bruk verktøylinjen for å bytte hvordan innholdet vises: Tekst, Kode, Heks, Bilde eller Gjengitt. La den stå på den automatiske innstillingen for å la Peach Commander avgjøre.
4. Rull med piltastene, Page Up/Page Down og rullefeltet. For lang tekst, slå på minikart-knappen for å se og hoppe rundt i hele filen med ett blikk.
5. Trykk N for å hoppe til neste merkede fil, eller lukk vinduet med Esc.

![Den innebygde visningen som viser en tekstfil med minikartet til høyre](screenshots/lister-text.png)
*(Figur: Visning av en tekstfil, med representasjonsvelgeren og minikartet i verktøylinjen.)*

## Finn tekst og endre tegnkodingen

- Trykk Ctrl+F for å søke i filen. Trykk F3 for å hoppe til neste treff og Shift+F3 for det forrige.
- Hvis teksten ser forvansket ut, klikk på Tegnkoding i verktøylinjen (eller trykk E) for å bla gjennom tegnkodinger til den leses riktig; den automatiske innstillingen treffer vanligvis riktig.
- Trykk W for å veksle tekstbryting for lange linjer.

## Quick View og Quick Look

Quick View viser en direkte forhåndsvisning i panelet du *ikke* bruker, slik at du kan fortsette å bla på den ene siden mens du forhåndsviser på den andre.

1. Trykk Ctrl+Q. Det inaktive panelet blir til et forhåndsvisningsområde.
2. Flytt markøren over ulike filer i det aktive panelet for å forhåndsvise hver enkelt.
3. Trykk Ctrl+Q igjen, eller Esc, for å få panelet tilbake til en vanlig filliste.

For en rask fullskjerm-forhåndsvisning håndtert av macOS selv, trykk Cmd+Y (Quick Look). Trykk Cmd+Y eller Space igjen for å lukke den.

## Infosiden i sidepanelet

Sidepanelet (**Vis > Forhåndsvisningspanel**, eller Cmd+Skift+P) har en side **Info** som viser objektet under markøren slik Finders infosidepanel gjør.

- Forhåndsvisningen fyller bredden på panelet: gjør du panelet bredere, vokser forhåndsvisningen med. Dra i panelets venstre kant for å gjøre det bredere eller smalere; bredden huskes.
- Det er en ekte macOS-forhåndsvisning, ikke en liten miniatyr: alle formater Kikk kan vise fungerer her, og et dokument på flere sider blar du side for side inne i forhåndsvisningen.
- Under står navn, type og størrelse, og deretter når objektet ble opprettet og endret, og hvilken mappe det ligger i.

Når markøren flyttes, oppdateres navn og opplysninger straks; forhåndsvisningen følger et øyeblikk etter, slik at en holdt piltast gjennom en lang mappe ikke starter en forhåndsvisning for hver rad.

## Dekompiler Java-classfiler

Med programtillegget **Java Decompiler** slått på viser F3 på en `.class`-fil lesbar kode i stedet for binærdata — også for classfiler inne i en JAR eller ZIP, som du kan gå inn i og lese uten å pakke ut.

Tillegget inneholder ingen dekompilator selv. Det styrer en motor du installerer, og du kan bytte motor når som helst:

- **CFR** (MIT-lisens) og **Vineflower** (Apache 2.0) gir Java-kildekode. Legg `cfr.jar` eller `vineflower.jar` i motormappen.
- **Procyon** (Apache 2.0) er en tredje kildekodedekompilator.
- **javap** krever ingen nedlasting: den følger med ethvert JDK og viser bytekode i stedet for Java-kildekode.

Ingenting lastes ned for deg: dette er tredjepartsprogrammer med egne lisenser, og Peach Commander verken henter eller oppdaterer dem. Knappen **Motormappe…** i fremviseren åpner mappen de hører hjemme i og legger igjen et notat som navngir hver motor og hvor den fås. Alle unntatt javap krever installert Java.

Bytt motor med menyen øverst i fremviseren; den du velger brukes straks og resultatet beholdes, så det går umiddelbart å sammenligne to motorer på samme fil.

Tillegget er **av til du slår det på**, under Innstillinger ▸ Programtillegg — de fleste åpner aldri en classfil, og uten motor gjør det ingen nytte.

Legg til din egen motor ved å opprette `decompilers.ini` i motormappen:

```ini
[myengine]
name   = My Decompiler
kinds  = class
tool   = java
args    = -jar {engine} {input}
engine  = my-decompiler.jar   ; a bare name is looked up in this folder
output  = stdout
timeout = 30                  ; seconds before the engine is stopped
```

`{input}`, `{engine}` og `{outdir}` fylles inn når motoren kjøres. Dine egne oppføringer går foran de innebygde, og å gjenbruke et innebygd navn (`cfr`, `vineflower`, `procyon`, `javap`) erstatter det i stedet for å legge til en ny oppføring.

## Snarveier

| Handling | Snarvei |
| --- | --- |
| Vis fil under markøren | F3 |
| Vis bare filen under markøren (ignorer merkede filer) | Shift+F3 |
| Åpne i en ekstern visning | Option+F3 |
| Finn i visningen | Ctrl+F |
| Neste / forrige treff | F3 / Shift+F3 |
| Quick View i det andre panelet | Ctrl+Q |
| Quick Look (macOS-forhåndsvisning) | Cmd+Y |
| Lukk visningen eller Quick View | Esc |

## Merknader

- Visningen er skrivebeskyttet. For å endre en fil, bruk redigeringsprogrammet i stedet (se Redigere filer).
- Svært store filer åpnes uten forsinkelse: tekst åpner en rask, rullbar visning, og heksadesimalvisningen strømmer rett fra disken uansett størrelse.
- Trykk F3 på en mappe for å se et sammendrag av innholdet og total størrelse i stedet for filbytes.
- Gjengitt-modus viser formatert innhold som nettsider; heksmodus viser de rå bytene side om side med tegnene deres, noe som er praktisk for å inspisere binærfiler.
- I modusen Gjengitt kan du merke og kopiere tekst, og Søk søker i den gjengitte siden. Knapper som ikke kan brukes på en gjengitt side — Formater, Tegnkoding, Merk alt, Merkinger og Gå til — er nedtonet i stedet for uten virkning.
- Knappen Formater setter inn nye innrykk i strukturerte filer (JSON, XML, HTML, INI, YAML og flere hvis du har det tilhørende kommandolinjeverktøyet). Den er beskrevet i sin helhet under [Redigere filer](editing-files.md#formatting-a-file) og virker likedan her.
