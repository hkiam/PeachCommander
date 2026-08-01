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

## Infosiden i sidepanelet

Sidepanelet (**Vis > Forhåndsvisningspanel**, eller Cmd+Skift+P) har en side **Info** som viser objektet under markøren slik Finders infosidepanel gjør.

- Forhåndsvisningen fyller bredden på panelet: gjør du panelet bredere, vokser forhåndsvisningen med. Dra i panelets venstre kant for å gjøre det bredere eller smalere; bredden huskes.
- Det er en ekte macOS-forhåndsvisning, ikke en liten miniatyr: alle formater Kikk kan vise fungerer her, og et dokument på flere sider blar du side for side inne i forhåndsvisningen.
- Under står navn, type og størrelse, og deretter når objektet ble opprettet og endret, og hvilken mappe det ligger i.

Når markøren flyttes, oppdateres navn og opplysninger straks; forhåndsvisningen følger et øyeblikk etter, slik at en holdt piltast gjennom en lang mappe ikke starter en forhåndsvisning for hver rad.

## Merknader

- Visningen er skrivebeskyttet. For å endre en fil, bruk redigeringsprogrammet i stedet (se Redigere filer).
- Svært store filer åpnes uten forsinkelse: tekst åpner en rask, rullbar visning, og heksadesimalvisningen strømmer rett fra disken uansett størrelse.
- Trykk F3 på en mappe for å se et sammendrag av innholdet og total størrelse i stedet for filbytes.
- Gjengitt-modus viser formatert innhold som nettsider; heksmodus viser de rå bytene side om side med tegnene deres, noe som er praktisk for å inspisere binærfiler.
