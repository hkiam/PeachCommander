---
title: Task Manager
slug: task-manager
section: Insticksprogram
order: 125
related: [plugins, viewing-files, deleting-files]
---

Task Manager-insticksprogrammet förvandlar de processer som körs på din Mac till en mapp du kan bläddra i. Det visas som en **TaskManager**-enhet i enhetsraden; öppna den och varje process är en rad du kan sortera, granska som en fil eller avsluta — med samma tangenter som du redan använder för filer. Det är ett insticksprogram, så du kan slå av det eller ta bort det i **Konfiguration ▸ Insticksprogram…**.

## Öppna det

1. Klicka på posten **📊 TaskManager** i enhetsraden (den sitter direkt efter din startenhet).
2. Panelen fylls med en rad per process som körs. Varje rads namn är processnamnet följt av dess PID, till exempel `Finder (462)`.
3. Knappen **TaskManager** förblir vald medan du är i den, och fliken får enhetens namn. Växla till en annan flik och tillbaka — eller avsluta och öppna appen igen — och fliken visar processlistan igen. Du lämnar den genom att gå upp en nivå eller klicka på en annan volym i enhetsraden.

![Task Manager som listar processer som körs med kolumnerna PID, CPU, minne och kommando](screenshots/task-manager.png)
*(Figur: processer som körs visas som en fillista du kan sortera och agera på.)*

## Vad varje kolumn betyder

Vid sidan av de vanliga kolumnerna Storlek (minne) och Datum (starttid) lägger Task Manager till processkolumner:

| Kolumn | Betydelse |
| --- | --- |
| **PID** | Process-id |
| **CPU %** | Nyligen processoranvändning (behöver en andra uppdatering för att visas) |
| **Threads** | Antal trådar |
| **State** | R körs · S sover · T stoppad · Z zombie · I inaktiv |
| **User** | Ägare |
| **PPID** | Överordnad process-id |
| **Command** | Fullständig kommandorad |

Sortera efter valfri kolumn (till exempel CPU % eller Storlek/minne) precis som du skulle göra i en vanlig mapp.

## Granska eller avsluta en process

- **Visa (F3)** visar en rapport med *Processinformation*: namn, PID, överordnad, användare, tillstånd, trådar, minne, CPU, starttid, sökväg till körbar fil och den fullständiga kommandoraden.
- **Ta bort (F8)** avslutar processen. Den första borttagningen skickar en artig **quit** (SIGTERM); att ta bort en process som fortfarande körs en andra gång trappar upp till en **force quit** (SIGKILL). Insticksprogrammet riktar sig aldrig mot PID 1.

## Anmärkningar

- Grundläggande uppgifter (PID, överordnad, användare, tillstånd) är läsbara för varje process, som `ps`. Minne, trådar och CPU kan bara läsas för **dina egna** processer; andra processer visar dessa kolumner tomma (de kräver förhöjda behörigheter, ett senare tillägg).
- CPU % är en förändring mellan två sampel, så den är tom tills panelen uppdateras en andra gång (panelen uppdateras ungefär varannan sekund).
- Listan är skrivskyddad förutom att avsluta en process — du kan inte kopiera filer till den.
