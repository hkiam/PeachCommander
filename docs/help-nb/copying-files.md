---
title: Kopiere filer
slug: copying-files
section: Filer og mapper
order: 24
related: [moving-and-renaming, background-transfers]
---

Peach Commander er bygget rundt to paneler side om side: det ene inneholder filene du arbeider med, det andre er målet. Kopiering tar det som er merket i det aktive panelet og legger en duplikat i mappen som vises i det andre panelet, mens originalene blir liggende. Dette er den raskeste måten å duplisere filer og mapper mellom to plasseringer på uten å dra.

## Kopier et utvalg til det andre panelet

1. I det ene panelet åpner du mappen som inneholder elementene du vil kopiere.
2. I det andre panelet åpner du mappen der kopiene skal havne.
3. Merk filene og mappene du vil kopiere. Hvis ingenting er merket, brukes elementet under markøren.
4. Trykk F5. Kopidialogen åpnes og viser målstien allerede utfylt.

![Kopidialogen med målstien og alternativer](screenshots/copy-dialog.png)
*(Figur: Kopidialogen. Målstien peker mot det andre panelet; bruk alternativene til å finjustere kopieringen.)*

5. Juster målet ved behov, og bekreft deretter for å starte kopieringen.

## Kopialternativer

Før du bekrefter, kan du endre hvordan kopieringen oppfører seg:

- **Bare nyere filer** — hopper over ethvert element hvis kopi allerede finnes og er like gammel eller nyere, slik at bare endrede filer oppdateres.
- **Bevar metadata** — beholder datoer, tillatelser og andre filattributter på kopiene. Dette er på som standard.
- **Hastighetsgrense** — begrenser overføringshastigheten slik at en stor kopiering ikke metter disken eller nettverksforbindelsen din.
- **Omdøpingsmaske** — skriv et jokertegnmønster i målfeltet (for eksempel `*.bak`) for å gi elementene nytt navn mens de kopieres.

Du kan også sende jobben til bakgrunnskøen i stedet for å se på den — se Bakgrunnsoverføringer.

## Fremdrift

Et fremdriftsvindu viser gjeldende fil og hele jobben med separate linjer, pluss overføringshastigheten. Du kan sette på pause og gjenoppta når som helst, eller sende den kjørende kopieringen til bakgrunnsoverføringsbehandleren for å fortsette å arbeide mens den fullføres.

![Fremdriftsdialogen for overføring med en fremdriftslinje, fil- og byteantall, og Pause- og Avbryt-knapper](screenshots/progress-dialog.png)
*(Figur: Fremdriftsdialogen som vises under en kopiering eller flytting.)*

## Håndtering av filer som allerede finnes

Hvis en kopiering vil erstatte en eksisterende fil, stopper Peach Commander og spør hva den skal gjøre. En forhåndsvisning av begge filene hjelper deg å bestemme.

![Konfliktdialogen for overskriving som sammenligner to filer](screenshots/overwrite-dialog.png)
*(Figur: Overskrivingsdialogen sammenligner den eksisterende filen med den som kopieres.)*

Valgene dine inkluderer:

- **Overskriv** den eksisterende filen, eller **Overskriv alle** for å bruke det på hver gjenværende konflikt.
- **Hopp over** denne filen, eller **Hopp over alle** gjenværende konflikter.
- **Gi nytt navn** til den innkommende kopien automatisk slik at begge filene beholdes.
- **Legg til** de innkommende dataene på slutten av den eksisterende filen.
- Overskriv bare når kilden er **nyere** eller **større** enn den eksisterende filen.

## Snarveier

| Handling | Tast |
|---|---|
| Kopier utvalg til det andre panelet | F5 |
| Kopier i samme mappe (lag en omdøpt duplikat) | Shift+F5 |
| Åpne bakgrunnsoverføringsbehandleren | Cmd+Shift+B |

## Merknader

- Kopiering mellom to plasseringer på samme disk bruker en rask kloning når disken støtter det, slik at store filer kopieres nesten øyeblikkelig og bruker lite ekstra plass.
- Mapper kopieres med alt inni dem.
- For å flytte filer i stedet for å kopiere dem, bruk F6. For å se på eller administrere jobber i kø, åpne bakgrunnsoverføringsbehandleren med Cmd+Shift+B.
