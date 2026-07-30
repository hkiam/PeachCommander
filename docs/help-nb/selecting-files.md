---
title: Merke filer
slug: selecting-files
section: Filer og mapper
order: 22
related: [copying-files, searching]
---

Før du kopierer, flytter, sletter eller pakker noe, forteller du først Peach Commander hvilke elementer den skal handle på. Elementet markøren din står på er alltid gjeldende element, men du kan også *merke* én eller mange filer og mapper slik at en kommando kjøres på dem alle på én gang. Merkede elementer skiller seg ut med en tydelig navnefarge i panelet.

## Merk filer og mapper

1. Klikk på en rad for å flytte markøren til den. Ett enkelt klikk velger bare det ene elementet.
2. For å merke flere elementer samtidig, hold Cmd og klikk på hvert enkelt, eller hold Shift og klikk for å merke et område.
3. For å merke elementet under markøren og gå ned i én bevegelse, trykk Insert. Trykk gjentatte ganger for å merke en rekke påfølgende elementer raskt. Mellomromstasten veksler også merkingen av gjeldende element (og viser en mappes størrelse).
4. For å merke alt i panelet, velg Merk > Merk alt (Ctrl+Num+), eller trykk Cmd+A. Velg Merk > Fjern merking på alt (Ctrl+Num-) for å fjerne alle merkinger.

## Merk eller fjern merking etter et mønster

1. Velg Merk > Merk gruppe… (Num+) for å legge til elementer hvis navn samsvarer med et mønster, eller Merk > Fjern merking på gruppe… (Num-) for å fjerne samsvarende elementer fra de gjeldende merkingene.
2. Skriv en jokertegnmaske. Bruk `*` for et hvilket som helst antall tegn og `?` for ett enkelt tegn. Skill flere masker med semikolon, og list unntak etter en loddrett strek — for eksempel merker `*.jpg;*.png` alle bilder, og `*.*|*.bak` merker alt bortsett fra sikkerhetskopifiler.

![Merk gruppe-dialogen med en jokertegnmaske skrevet inn i mønsterfeltet](screenshots/select-by-mask.png)
*(Figur: Merking av filer etter en jokertegnmaske.)*

## Inverter, samme filendelse og gjenopprett

- **Inverter merking** (Num*, Merk-menyen) snur hver merking: merkede elementer blir umerkede og omvendt — praktisk for "alt bortsett fra disse".
- **Merk alt med samme filendelse** (Alt+Num+, Merk-menyen) merker hver fil som deler filendelsen til elementet under markøren, slik at ett tastetrykk fanger for eksempel alle `.pdf`-filer.
- **Gjenopprett merking** (Num/, Merk-menyen) henter tilbake ditt forrige sett med merkinger — nyttig hvis en kommando fjernet dem eller du merket feil gruppe.

## Snarveier

| Handling | Tast |
|---|---|
| Veksle merking, gå ned | Insert |
| Veksle merking (gjeldende element) | Space |
| Merk alt / Fjern merking på alt | Ctrl+Num+ / Ctrl+Num- |
| Merk alt (alternativ) | Cmd+A |
| Merk gruppe etter maske | Num+ |
| Fjern merking på gruppe etter maske | Num- |
| Inverter merking | Num* |
| Merk alt med samme filendelse | Alt+Num+ |
| Gjenopprett forrige merking | Num/ |

## Merknader

- Merkinger og markøren er uavhengige: å flytte markøren med piltastene endrer ikke hva som er merket.
- Oppføringen for overordnet mappe (`..`) kan aldri merkes.
- Merk gruppe, Fjern merking på gruppe og Inverter merking samsvarer på filnavnet, så du kan inkludere eller utelate mapper avhengig av dialogens alternativer.
- Etter at en kopiering, flytting eller sletting er fullført, fjernes merkingen automatisk på elementer som ble håndtert vellykket, mens de som mislyktes forblir merket slik at du kan prøve dem på nytt.
