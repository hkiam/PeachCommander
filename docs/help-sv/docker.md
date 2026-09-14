---
title: Docker-containrar och -volymer
slug: docker
section: Insticksprogram
order: 137
related: [plugins, amazon-s3, webdav, copying-files, privacy-and-security]
---

En Docker-containers filsystem kan bläddras i en panel som vilken mapp som helst, och det gäller även en Docker-volym. Välj **Anslut till Docker…** i menyn Nätverk, eller klicka på brickan **Docker** i enhetslisten, så visas motorn i den aktiva panelen.

Det är ett insticksprogram och det **levereras avstängt**. Slå på det under **Konfiguration ▸ Insticksprogram…**. Det börjar avstängt eftersom en anslutning till Docker-tjänsten har samma rättigheter på din Mac som du själv — se *Vad det når* nedan.

## Vad du ser

Den översta nivån är tre mappar:

- **Compose Projects** — alla containrar som Docker Compose har startat, grupperade efter projekt och sedan efter tjänst. En tjänst med en enda container *är* den containern: `my-stack/backend/etc` är backendens `/etc`. En tjänst med flera behåller en nivå för dem, en mapp per container.
- **Standalone Containers** — allt övrigt, oavsett om det körs eller inte.
- **Volumes** — varje Docker-volym, som en egen enhet.

Under dem befinner du dig i ett riktigt filsystem: F3 visar en fil, F4 redigerar den, F5 kopierar den till den andra panelen, F7 skapar en mapp. Den andra panelen kan vara vad som helst — en lokal mapp, ett arkiv, en S3-bucket.

Grupperingen läses ur de etiketter som Compose sätter på sina egna containrar och volymer, så den stämmer även för en stack vars `docker-compose.yml` sedan länge är borta från den här maskinen.

**Volymer listas separat med avsikt.** En volym överlever den container som skapade den, kan delas av flera containrar och innehåller oftast just de data du kom för. En volym som inget monterar just nu går ändå att bläddra i.

## Kolumner

Högerklicka på en panels kolumnrubrik för att lägga till leverantörens egna kolumner:

- **Status** — `● running`, `○ stopped`, `◌ paused`, `! restarting`.
- **Åtkomst** — `RW`, `RO` för ett skrivskyddat rootfs eller en skrivskyddad montering, `VOL` för en Docker-volym, `BIND` för en av dina egna mappar monterad i containern, `TMP` för ett tmpfs.
- **Image**, **ID**.
- **Montering** — på en katalog som i själva verket är en montering: vad den är. `Volume: my-stack_db-data`, eller värdsökvägen bakom en bind-montering. Så hittar du vilken volym under **Volumes** som innehåller en containers data.

## Stoppade containrar

Stoppade containrar listas och deras filsystem går att läsa och skriva. Dockers fil-API svarar för en container som inte har körts på en månad, och det är det som gör att detta känns som en enhet i stället för en processlista.

Två saker kräver en container som verkligen körs: **radera** och **byta namn**. Docker Engine-API:et har ingen operation för någotdera — det enda sättet att ta bort eller flytta en fil inuti en container är att köra något i den — så på en stoppad container avvisas båda i stället för att låtsas.

## Vad du kan förvänta dig

**Skrivningar går in som `root`, raderingar körs som containerns egen användare.** Det är Dockers upplägg, inte ett val som gjorts här: att kopiera in en fil använder motorns arkiv-API, som skriver som root; att radera eller byta namn kör ett kommando inuti containern, som körs som den användare avbilden angett. En radering kan därför avvisas med *åtkomst nekad* på en fil du kunde kopiera in ett ögonblick tidigare. Peach Commander kringgår inte det genom att uppträda som root — det berättar vad containern sade.

**En skrivskyddad container eller montering avvisar skrivning** och rapporterar det som ett rättighetsfel, inte som ett misslyckande.

**Att läsa en symbolisk länk läser det den pekar på.** Panelen visar den fortfarande som en länk i kolumnen Attr; F3 visar målets innehåll i stället för en tom fil.

**Roten i en stor stoppad container går kanske inte att lista.** Docker har inget anrop som listar en katalog. Att läsa en katalog innebär att begära den som ett arkiv, vilket innehåller allt under den — för en stoppad container byggd på en fullstor avbild kan det vara många gigabyte, och listningen avvisas i stället för att läsa alltihop. Djupare kataloger påverkas inte, och en *körande* container inte heller: en katalog som är för stor för att läsas som arkiv listas av containern själv. Vill du bara ha arkivvägen, se inställningen nedan.

**Att kopiera ut en hel container kopierar hela dess filsystem** — inklusive `/proc` och `/dev`. Kopiera den katalog du vill ha, inte `/`.

## Vad det når

Insticksprogrammet talar med samma motor som du skulle nå från en terminal: `DOCKER_HOST` om du har satt den, annars din aktuella `docker context`, annars de vanliga socketarna för Docker Desktop, Colima, Rancher Desktop, Lima och Podman. Podman fungerar eftersom det erbjuder samma API.

Åtkomst till en Docker-tjänst innebär i regel mycket långtgående åtkomst till maskinen den körs på. Insticksprogrammet har exakt dina rättigheter och begär inga fler: det sparar inga inloggningsuppgifter, rör aldrig Dockers egna kataloger på din disk och utför inga privilegierade åtgärder för din räkning.

Det enda det skapar är en **engångscontainer** — och bara för att nå en volym som ingen befintlig container monterar, eftersom en volym bara syns inifrån något som monterar den. Den startas aldrig, den är märkt som Peach Commanders och den tas bort när du lämnar enheten.

## Åtgärder på en container eller en volym

Ett högerklick på en container eller en volym erbjuder i undermenyn **Docker** det som en enhet ensam inte kan säga:

- **Inspect** — allt motorn vet om den, som formaterad JSON i ett fönster som går att rulla och
  markera i.
- **Show Logs** — de senaste 500 raderna containern har skrivit.
- **Show Mounts** — varje montering den bär, vad den är och om det går att skriva i den.
- **Copy ID** — containerns fullständiga id, eller volymens namn, till urklipp. Det *fullständiga*
  id:t, inte de tolv tecknen i ID-kolumnen: det här är till för att klistras in i ett `docker`-kommando,
  och ett kort id är ett prefix som kan sluta vara unikt.
- **Jump to Volume** — på en katalog som egentligen är en volym, gå till den volymen under
  **Volumes**. Det är den andra halvan av Montering-kolumnen: kolumnen namnger volymen, det här tar dig dit.
- **Open Compose Project** — gå till projektet containern hör till.
- **Start**, **Stop**, **Restart**, **Pause**, **Unpause** — dessa ändrar containern i stället för
  att läsa den, så de frågar först. Start är också vägen ut ur de två avslagen ovan: radera och byta
  namn kräver en körande container.

Posterna visas bara inuti en Docker-enhet; över en egen mapp finns de inte alls.

## Inställningar

**Konfiguration ▸ Inställningar ▸ Docker** innehåller allt detta. Samma värden finns i en liten fil i `~/Library/Application Support/PeachCommander/Docker/docker.ini`, som är den du redigerar om du sätter upp en maskin från ett skript:

- `Endpoint` — en adress att använda i stället för den som hittades.
- `ExecFallback` — `0` gör att insticksprogrammet bara använder Dockers arkiv-API: det kör då aldrig något inuti en container, till priset av att inte kunna lista en mycket stor katalog, radera eller byta namn.
- `ProbeBudgetMB`, `MaxBudgetMB`, `MaxBudgetSeconds` — hur mycket av en katalogs arkiv som är värt att läsa innan det faller tillbaka eller ger upp.
- `HelperImage` — den avbild engångscontainern ovan skapas av (som standard vilken avbild som helst som redan finns på maskinen).
- `ShowAnonymousVolumes` — `0` döljer de volymer som Docker gav en lång hash som namn därför att ingen annan namngav dem.

## Inte med i den här versionen

Fjärrmotorer över SSH eller TLS, att starta och stoppa containrar, containerloggar som fil, ett interaktivt skal, och avbilder som skrivskyddade filsystem.
