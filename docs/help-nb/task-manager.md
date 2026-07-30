---
title: Task Manager
slug: task-manager
section: Programtillegg
order: 125
related: [plugins, viewing-files, deleting-files]
---

Task Manager-programtillegget gjør prosessene som kjører på Mac-en din, til en mappe du kan bla i. Det vises som en **TaskManager**-stasjon i stasjonslinjen; åpne den, og hver prosess er en rad du kan sortere, granske som en fil eller avslutte – med de samme tastene du allerede bruker for filer. Det er et programtillegg, så du kan slå det av eller fjerne det i **Konfigurasjon ▸ Programtillegg…**.

## Åpne det

1. Klikk på **📊 TaskManager**-oppføringen i stasjonslinjen (den sitter rett etter startstasjonen din).
2. Panelet fylles med én rad per prosess som kjører. Hver rads navn er prosessnavnet etterfulgt av PID-en, for eksempel `Finder (462)`.

![Task Manager som lister prosesser som kjører, med kolonnene PID, CPU, minne og kommando](screenshots/task-manager.png)
*(Figur: prosesser som kjører vist som en filliste du kan sortere og handle på.)*

## Hva hver kolonne betyr

Ved siden av de vanlige kolonnene Størrelse (minne) og Dato (starttid) legger Task Manager til prosesskolonner:

| Kolonne | Betydning |
| --- | --- |
| **PID** | Prosess-id |
| **CPU %** | Nylig prosessorbruk (trenger en ny oppdatering for å vises) |
| **Threads** | Antall tråder |
| **State** | R kjører · S sover · T stoppet · Z zombie · I inaktiv |
| **User** | Eier |
| **PPID** | Overordnet prosess-id |
| **Command** | Full kommandolinje |

Sorter etter en hvilken som helst kolonne (for eksempel CPU % eller Størrelse/minne) akkurat som du ville gjort i en vanlig mappe.

## Gransk eller avslutt en prosess

- **Vis (F3)** viser en *Prosessinformasjon*-rapport: navn, PID, overordnet, bruker, tilstand, tråder, minne, CPU, starttid, kjørbar sti og den fulle kommandolinjen.
- **Slett (F8)** avslutter prosessen. Den første slettingen sender et vennlig **avslutt** (SIGTERM); å slette en prosess som fortsatt kjører en gang til, eskalerer til et **tvangsavslutt** (SIGKILL). Programtillegget retter seg aldri mot PID 1.

## Merknader

- Grunnleggende detaljer (PID, overordnet, bruker, tilstand) er lesbare for hver prosess, som `ps`. Minne, tråder og CPU kan bare leses for **dine egne** prosesser; andre prosesser viser de kolonnene tomme (de trenger hevede rettigheter, en senere tilføyelse).
- CPU % er en endring mellom to prøver, så den er tom til panelet oppdateres en gang til (panelet oppdateres omtrent hvert annet sekund).
- Listen er skrivebeskyttet bortsett fra å avslutte en prosess – du kan ikke kopiere filer inn i den.
