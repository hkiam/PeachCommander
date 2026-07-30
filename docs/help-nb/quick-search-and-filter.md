---
title: Hurtigsøk og filter
slug: quick-search-and-filter
section: Organisere visningen
order: 44
related: [searching, view-modes-and-sorting]
---

Når en mappe inneholder hundrevis av elementer, trenger du sjelden å rulle. Peach Commander lar deg hoppe rett til en fil ved å skrive navnet (hurtigsøk), skjære listen ned til bare elementene du bryr deg om (hurtigfilter), og vise eller skjule punktfilene macOS normalt holder skjult. Alle tre fungerer inne i det aktive panelet uten å åpne en dialog.

## Hopp til en fil ved å skrive (hurtigsøk)

1. Klikk på et filpanel slik at det blir aktivt.
2. Begynn å skrive begynnelsen av et navn. Markøren hopper til det første samsvarende elementet.
3. Fortsett å skrive for å forfine treffet, eller trykk samme bokstav igjen for å bla gjennom elementer som begynner med den bokstaven.
4. Den innskrevne teksten fjernes etter en kort pause, slik at du kan starte et nytt søk når som helst.

Som standard går rene bokstaver til kommandolinjen, og hurtigsøk utløses med Ctrl+Option+bokstav (den klassiske oppførselen). Du kan bytte hurtigsøk til å svare på ren skriving i stedet, eller slå det av, i Konfigurasjon-innstillingene.

## Filtrer listen (hurtigfilter)

1. I det aktive panelet trykker du Ctrl+S for å slå på hurtigfilteret.
2. Skriv en filtermaske. Panelet snevres inn i sanntid til samsvarende elementer mens du skriver.
3. Trykk Esc for å fjerne filteret og vise alt igjen.

Filteret godtar flere typer masker:

- **Ren tekst** samsvarer med ethvert navn som inneholder det du skrev (for eksempel viser `report` hvert element med "report" hvor som helst i navnet).
- **Jokertegn** bruker `*` (et hvilket som helst antall tegn) og `?` (ett tegn). Skill flere masker med et semikolon og legg til unntak etter en loddrett strek, for eksempel `*.jpg;*.png|*thumb*` for å vise bilder, men skjule miniatyrbilder.
- **Finder-etiketter** filtrerer etter etikettfarge: skriv `tag:red` (eller `#red`) for å vise bare rødmerkede elementer, eller et bart `tag:` for å vise alt som bærer en etikett.

## Vis skjulte filer

Trykk Ctrl+H, eller velg kommandoen fra Vis-menyen, for å veksle skjulte elementer (navn som begynner med et punktum og systemskjulte filer). Innstillingen gjelder det aktive panelet og huskes mellom økter.

## Snarveier

| Handling | Snarvei |
| --- | --- |
| Hurtigsøk (klassisk modus) | Ctrl+Option+bokstav |
| Hurtigfilter på/av | Ctrl+S |
| Fjern filter / avbryt | Esc |
| Vis/skjul skjulte filer | Ctrl+H |

## Merknader

- Hurtigsøk flytter bare markøren; hurtigfilter endrer faktisk hvilke elementer som listes opp. Bruk filteret når du vil arbeide på et delsett (for eksempel merke eller kopiere bare treffene).
- Filter- og skjulte-filer-innstillingene er per panel, så de to sidene kan vise ulike ting samtidig.
- Hurtigsøk samsvarer med navn fra begynnelsen; hurtigfilterets ren-tekst-modus samsvarer hvor som helst i navnet. Bruk et jokertegn som `*text*` hvis du vil at filteret skal oppføre seg på samme måte.
