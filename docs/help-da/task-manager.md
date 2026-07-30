---
title: Opgavehåndtering
slug: task-manager
section: Plugins
order: 125
related: [plugins, viewing-files, deleting-files]
---

Task Manager-pluginet gør de kørende processer på din Mac til en mappe, du kan gennemse. Det vises som et **TaskManager**-drev i drevlinjen; åbn det, og hver proces er en række, du kan sortere, granske som en fil eller afslutte — med de samme taster, du allerede bruger til filer. Det er et plugin, så du kan slå det fra eller fjerne det i **Konfiguration ▸ Plugins…**.

## Åbn det

1. Klik på **📊 TaskManager**-emnet i drevlinjen (det sidder lige efter dit startdrev).
2. Panelet fyldes med én række pr. kørende proces. Hver rækkes navn er procesnavnet efterfulgt af dens PID, for eksempel `Finder (462)`.

![Task Manager der viser kørende processer med kolonnerne PID, CPU, hukommelse og kommando](screenshots/task-manager.png)
*(Figur: kørende processer vist som en filliste, du kan sortere og handle på.)*

## Hvad hver kolonne betyder

Ved siden af de sædvanlige kolonner Størrelse (hukommelse) og Dato (starttidspunkt) tilføjer Task Manager proceskolonner:

| Kolonne | Betydning |
| --- | --- |
| **PID** | Proces-id |
| **CPU %** | Nylig processorbrug (kræver en anden opdatering for at dukke op) |
| **Threads** | Antal tråde |
| **State** | R kører · S sover · T stoppet · Z zombie · I inaktiv |
| **User** | Ejer |
| **PPID** | Forældreprocessens id |
| **Command** | Fuld kommandolinje |

Sortér efter enhver kolonne (for eksempel CPU % eller Størrelse/hukommelse), præcis som du ville gøre i en almindelig mappe.

## Granske eller afslutte en proces

- **Vis (F3)** viser en rapport med *Procesoplysninger*: navn, PID, forælder, bruger, tilstand, tråde, hukommelse, CPU, starttidspunkt, sti til den eksekverbare fil og den fulde kommandolinje.
- **Slet (F8)** afslutter processen. Den første sletning sender en pæn **quit** (SIGTERM); at slette en proces, der stadig kører, en anden gang eskalerer til en **force quit** (SIGKILL). Pluginet retter sig aldrig mod PID 1.

## Bemærkninger

- Grundlæggende oplysninger (PID, forælder, bruger, tilstand) kan læses for hver proces, ligesom `ps`. Hukommelse, tråde og CPU kan kun læses for **dine egne** processer; andre processer viser de kolonner blanke (de kræver forhøjede rettigheder, en senere tilføjelse).
- CPU % er en ændring mellem to målinger, så den er blank, indtil panelet opdaterer en anden gang (panelet opdateres omtrent hvert andet sekund).
- Listen er skrivebeskyttet bortset fra at afslutte en proces — du kan ikke kopiere filer ind i den.
