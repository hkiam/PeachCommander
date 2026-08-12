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

Bredvid kolumnen Datum (starttid) lägger Task Manager till processkolumner. Storleken på en processrad visar `DIR`, eftersom en process är en mapp du kan öppna (se nedan) — minnet har egna kolumner:

| Kolumn | Betydelse |
| --- | --- |
| **PID** | Process-id |
| **CPU %** | Nyligen processoranvändning (behöver en andra uppdatering för att visas) |
| **Memory** | Minnesavtryck — vad den här processen svarar för (siffran som Aktivitetskontroll visar) |
| **Resident** | Resident storlek, delade sidor inräknade; ifylld för varje process |
| **Threads** | Antal trådar |
| **State** | R körs · S sover · T stoppad · Z zombie · I inaktiv, plus ändelserna som `ps` lägger till (s = sessionsledare, + = förgrund, N = låg prioritet) |
| **User** | Ägare |
| **PPID** | Överordnad process-id |
| **Read** | Byte lästa från disken sedan processen startade |
| **Written** | Byte skrivna till disken sedan processen startade |
| **Wakeups** | Avbrottsuppvakningar sedan processen startade |
| **Signed** | Vem som signerade programmet: Apple, ett Developer ID-team, ad-hoc eller osignerat |
| **Command** | Fullständig kommandorad |

Sortera efter valfri kolumn (till exempel CPU % eller Storlek/minne) precis som du skulle göra i en vanlig mapp.

## Granska eller avsluta en process

- **Visa (F3)** visar en rapport med *Processinformation*: namn, PID, överordnad, användare, tillstånd, trådar, minne, CPU, starttid, sökväg till körbar fil och den fullständiga kommandoraden.
- **Ta bort (F8)** avslutar processen. Den första borttagningen skickar en artig **quit** (SIGTERM); att ta bort en process som fortfarande körs en andra gång trappar upp till en **force quit** (SIGKILL). Insticksprogrammet riktar sig aldrig mot PID 1.

## Hitta processerna som använder en fil

Högerklicka på valfri rad och välj **Sök processer efter fil…**, ange sedan sökvägen till en fil. Varje process som har den filen öppen just nu markeras, och markören hoppar till den första som kan ändra den:

- **Blå** — processen läser bara filen.
- **Orange** — processen skriver bara till den.
- **Lila** — processen gör bådadera.

Sökvägen fylls i från markören i den andra panelen, så du kan peka på en fil där och fråga utan att skriva. **Sök process efter port…** i samma meny svarar på systerfrågan: vilken process som lyssnar på en TCP/UDP-port. Välj **Rensa filmarkering** för att ta bort färgerna; att lämna processlistan tar också bort dem.

## Öppna en process för att se dess filer

Tryck Retur på en process — eller dubbelklicka på den — så listar panelen de filer processen har öppna just nu, som vanliga filrader med sin verkliga storlek och sitt datum. Därifrån:

- **Visa (F3)** öppnar själva filen.
- **Gå till filen** visar den i den andra panelen, där du kan arbeta med den.
- **Visa i Finder** lämnar över den till Finder.

Bara öppna filer räknas: ett bibliotek som processen bara lagt i minnet, och dess arbetskatalog, är inte öppna filer. En annan användares process visar en tom mapp.

## Anmärkningar

- Grundläggande uppgifter (PID, förälder, användare, tillstånd, signatur) går att läsa för varje process. Minnesavtryck, trådar, disk-I/O och listan över öppna filer går att läsa för **dina egna** processer, vilket på en vanlig Mac är merparten av listan. För andra användares processer fylls CPU och Resident i från `ps` i stället — ett genomsnitt över hela livstiden i stället för skillnaden mellan två mätningar som de andra raderna bär — och trådar och avtryck förblir tomma.
- CPU % är en förändring mellan två sampel, så den är tom tills panelen uppdateras en andra gång (panelen uppdateras ungefär varannan sekund).
- Listan är skrivskyddad förutom att avsluta en process — du kan inte kopiera filer till den.
- Markeringsfärgerna följer ditt färgtema: Norton-paletten använder grönt, rött och magenta i stället.
- Endast handtag som ditt konto får titta på hittas, vilket i praktiken betyder dina egna processer. Ett bibliotek som en process bara har lagt i minnet, eller dess arbetskatalog, är inte ett öppet handtag och rapporteras inte.
- Kolumnen **Signed** fylls i under de första sekunderna: att läsa en signatur tar ungefär en millisekund och det finns hundratals olika program, så några läses per uppdatering och kommer sedan ihåg. En tom cell betyder ”inte läst än”, inte ”osignerat”.
- **Signed** säger vem som signerade programmet, inte om det är notariserat: att kontrollera notarisering innebär att hasha hela programmet, vilket skulle ta sekunder för vart och ett.
- Snabbfiltret (Ctrl+S) träffar här även kolumnerna och inte bara namnet, och en term kan namnge kolumnen den gäller: `user:root state:R` frågar vad root kör just nu. Termer skiljs åt med mellanslag och alla måste stämma; text som inte namnger någon kolumn förblir en enda vanlig delsträng, mellanslag inkluderade.
