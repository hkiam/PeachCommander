---
title: Attributter og tillatelser
slug: attributes-and-permissions
section: Kraftverktøy
order: 96
related: [file-utilities]
---

Peach Commander lar deg inspisere og endre lavnivå-metadataene til filer og mapper som Finder stort sett holder utenfor rekkevidde: POSIX les/skriv/kjør-tillatelser, eieren og gruppen, endret- og opprettet-datoene, macOS-flagg som skjult og låst, og utvidede attributter. Du kan også redigere en fils tilgangskontrolliste (ACL) for finkornede regler per bruker eller per gruppe, opprette lenker og aliaser som peker mot andre elementer, og legge ved dine egne kommentarer. Disse verktøyene er rettet mot avanserte brukere som trenger presis kontroll over hvordan elementer oppfører seg og hvem som kan røre dem.

## Endre attributter

1. Merk ett eller flere elementer i det aktive panelet.
2. Velg **Fil > Endre attributter…**.
3. Angi det du trenger: veksle les/skriv/kjør-boksene for eier, gruppe og alle (eller skriv inn en oktal verdi direkte), endre eier eller gruppe, snu skjult- eller låst-flaggene, og sett endret- eller opprettet-datoen. Bruk **Bruk gjeldende** for gjeldende tidspunkt, eller kopier en dato fra en annen fil.
4. For å bruke den samme endringen gjennom en mappes innhold, slå på det rekursive alternativet og velg om det påvirker filer, mapper eller begge.
5. Klikk OK for å kjøre endringen. Rekursive endringer kjøres som en bakgrunnsoppgave med en fremdriftslinje.

![Endre attributter-dialogen som viser tillatelsesrutenettet, flaggene og datofeltene](screenshots/attributes-dialog.png)
*(Figur: Endre attributter-dialogen. Blandede verdier på tvers av et utvalg med flere filer vises som en strek til du angir dem.)*

## Rediger en ACL

For regler utover den grunnleggende eier/gruppe/alle-modellen, rediger elementets tilgangskontrolliste.

1. Åpne **Fil > Endre attributter…** og åpne ACL-redigeringsprogrammet derfra.
2. Hver rad er én regel: brukeren eller gruppen den gjelder for, om den tillater eller nekter, og hvilke tillatelser (les, skriv, slett og så videre) den gir.
3. Legg til, fjern eller rediger rader, og lagre deretter for å skrive listen tilbake til elementet.

## Opprett lenker, aliaser og kommentarer

- **Fil > Opprett symbolsk lenke…** lager en symbolsk lenke (symlink) som peker mot elementet under markøren via sti.
- **Fil > Opprett hard lenke…** lager en hard lenke til de samme fildataene. Harde lenker fungerer bare for filer på samme volum.
- **Fil > Opprett alias…** lager et macOS-alias som Finder også kan følge.
- **Fil > Rediger kommentar…** (Ctrl+Z) åpner et tekstredigeringsprogram for en kommentar per fil. Kommentarer kan vises i sin egen kolonne og i statustips.

## Snarveier

| Handling | Snarvei |
| --- | --- |
| Rediger kommentar | Ctrl+Z |

## Merknader

- Å endre eier eller gruppe krever vanligvis privilegier du ikke har som en vanlig bruker; når det skjer, rapporteres endringen som mislykket i stedet for å bli brukt, og resten av endringene dine går fortsatt gjennom.
- Kommentarer lagres i en `descript.ion`-fil ved siden av elementene dine og kan også beholdes som Finder-kommentarer, avhengig av innstillingene dine. Begge leses når en kommentar vises.
- En symbolsk lenke og et alias peker begge mot et mål, men en symbolsk lenke lagrer en ren sti mens et alias lagrer en macOS-referanse som fortsetter å fungere hvis målet flyttes eller får nytt navn. En hard lenke er et andre navn for de samme fildataene, ikke en peker.
