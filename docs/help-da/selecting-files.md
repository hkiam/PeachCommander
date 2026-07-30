---
title: Markering af filer
slug: selecting-files
section: Filer og mapper
order: 22
related: [copying-files, searching]
---

Før du kopierer, flytter, sletter eller pakker noget, fortæller du først Peach Commander, hvilke emner der skal handles på. Emnet, din markør sidder på, er altid det aktuelle emne, men du kan også *markere* én eller flere filer og mapper, så en kommando kører på dem alle på én gang. Markerede emner skiller sig ud med en tydelig navnefarve i panelet.

## Markér filer og mapper

1. Klik på en række for at flytte markøren til den. Et enkelt klik vælger kun det ene emne.
2. For at markere flere emner på én gang, hold Cmd nede og klik på hvert, eller hold Shift nede og klik for at markere et interval.
3. For at markere emnet under markøren og gå ned i én bevægelse, tryk på Insert. Tryk gentagne gange for hurtigt at markere en række på hinanden følgende emner. Mellemrumstasten skifter også det aktuelle emnes markering (og viser en mappes størrelse).
4. For at markere alt i panelet, vælg Markér > Vælg alle (Ctrl+Num+), eller tryk på Cmd+A. Vælg Markér > Fravælg alle (Ctrl+Num-) for at rydde alle markeringer.

## Vælg eller fravælg efter et mønster

1. Vælg Markér > Vælg gruppe… (Num+) for at tilføje emner, hvis navne matcher et mønster, eller Markér > Fravælg gruppe… (Num-) for at fjerne matchende emner fra de aktuelle markeringer.
2. Indtast en jokertegnmaske. Brug `*` for vilkårlige tegn og `?` for et enkelt tegn. Adskil flere masker med semikolon, og angiv undtagelser efter en lodret streg — for eksempel markerer `*.jpg;*.png` alle billeder, og `*.*|*.bak` markerer alt undtagen sikkerhedskopifiler.

![Dialogen Vælg gruppe med en jokertegnmaske indtastet i mønsterfeltet](screenshots/select-by-mask.png)
*(Figur: markering af filer efter en jokertegnmaske.)*

## Inverter, samme filtype og gendan

- **Inverter markering** (Num*, Markér-menuen) vender hver markering: markerede emner bliver umarkerede og omvendt — praktisk til "alt undtagen disse".
- **Vælg alle med samme filtype** (Alt+Num+, Markér-menuen) markerer hver fil, der deler filtypen på emnet under markøren, så ét tastetryk fanger for eksempel alle `.pdf`-filer.
- **Gendan markering** (Num/, Markér-menuen) bringer dit forrige sæt markeringer tilbage — nyttigt hvis en kommando ryddede dem, eller du markerede den forkerte gruppe.

## Genveje

| Handling | Tast |
|---|---|
| Skift markering, gå ned | Insert |
| Skift markering (aktuelt emne) | Mellemrum |
| Vælg alle / Fravælg alle | Ctrl+Num+ / Ctrl+Num- |
| Vælg alle (alternativ) | Cmd+A |
| Vælg gruppe efter maske | Num+ |
| Fravælg gruppe efter maske | Num- |
| Inverter markering | Num* |
| Vælg alle med samme filtype | Alt+Num+ |
| Gendan forrige markering | Num/ |

## Bemærkninger

- Markeringer og markøren er uafhængige: at flytte markøren med piletasterne ændrer ikke, hvad der er markeret.
- Den overordnede mappe-post (`..`) kan aldrig markeres.
- Vælg gruppe, Fravælg gruppe og Inverter markering matcher på filnavnet, så du kan inkludere eller udelade mapper afhængigt af dialogens indstillinger.
- Efter en kopiering, flytning eller sletning er færdig, fravælges emner, der blev håndteret korrekt, automatisk, mens dem der mislykkedes forbliver markeret, så du kan prøve dem igen.
