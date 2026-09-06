---
title: Insticksprogram
slug: plugins
section: Insticksprogram
order: 120
related: [disk-map, ai-assistant, git, system-monitor, task-manager, uninstaller, filesystem-images, archives, ftp-and-sftp]
---

Insticksprogram utökar Peach Commander med extra verktyg, filformat och platser att bläddra i. Ett dussin insticksprogram är inbyggda, så att du kan börja använda dem direkt, och du kan slå på eller av enskilda insticksprogram — eller installera nya — från ett enda fönster. Använd insticksprogram när du vill ha funktioner utöver vardaglig kopiering och bläddring: visualisera vad som fyller en disk, ansluta till en WebDAV-server, kontrollera tillståndet för ett Git-arkiv, övervaka systemaktivitet med mera.

Insticksprogram kommer i några varianter: vissa lägger till en **panel eller sidopanel** (en vy), vissa lägger till **kolumner** i fillistan, vissa lägger till en **plats du navigerar in i** som en enhet, och vissa lär appen ett nytt **arkivformat**. Var och en aktiveras oberoende.

## Vad de inbyggda insticksprogrammen tillför

Flera insticksprogram har sitt eget detaljerade hjälpavsnitt — följ länken för hela historien:

- **[Disk Map](disk-map.md)** — visualiserar vad som fyller en mapp eller volym som en trädkarta eller solstråle, avstämt mot ledigt, rensbart och dolt utrymme, med en samlare för uppstädning.
- **[AI Assistant](ai-assistant.md)** — en valfri, borttagbar assistent som sammanfattar, byter namn på, översätter, tabellerar och städar filer i vanligt språk, på enheten eller via en molnmodell.
- **[Git](git.md)** — visar varje fils status i arbetsträdet och den aktuella grenen som panelkolumner, och lägger till en **Git**-meny för status, köa, checka in, hämta och skicka.
- **[System Monitor](system-monitor.md)** — en avläsning i realtid av CPU, minne, disk, nätverk (och, där tillgängligt, GPU, batteri, sensorer) i fönstrets namnlist, med genomklickbara detaljgrafer.
- **[Task Manager](task-manager.md)** — monterar dina processer som körs som en bläddringsbar **TaskManager**-enhet; sortera dem, granska dem som filer eller avsluta dem med Ta bort.
- **[Filsystemsavbilder](filesystem-images.md)** — öppnar en filsystemsavbild (SquashFS, ext, Btrfs, JFFS2, UBIFS, cramfs, initramfs, FAT, exFAT, NTFS) som ett arkiv, även diskavbilder med flera partitioner. Endast läsning, och avstängd tills du slår på den.
- **[Uninstaller](uninstaller.md)** — tar bort ett program **och** de stödfiler, cacheminnen och inställningar det lämnar efter sig, efter att ha visat dig exakt vad som kommer att försvinna.

De återstående inbyggda insticksprogrammen är mindre och behöver ingen egen sida:

- **Amazon S3** — anslut till Amazon S3 eller S3-kompatibel lagring (**Nät ▸ Anslut till Amazon S3…**) och bläddra i buckets som mappar, med läsning, skrivning, namnbyte och borttagning. Hemliga nycklar förvaras i macOS-nyckelhanteraren.
- **WebDAV** — anslut till en WebDAV-server (**Nätverk ▸ Anslut till WebDAV…**) och bläddra, ladda upp, ladda ner, byt namn på och ta bort på den som om den vore en mapp. Lösenord förvaras i macOS nyckelring.
- **iCloud Drive** — lägger till en post *iCloud Drive* i enhetsraden som hoppar direkt till din lokala iCloud Drive-mapp. Den visas bara när iCloud Drive är konfigurerat på din Mac.
- **Notes** — behåll en anteckning bredvid vilken fil eller mapp som helst. En liten **●**-bricka markerar objekt som har en; redigera anteckningar i en dockad **Notes**-sidopanel eller en fullständig redigerare för rik text (**Kommandon ▸ Redigera anteckning…**), och bläddra bland dem alla med **Anteckningsöversikt…**.
- **Log Viewer** — öppna en fil som en färgkodad, nivåklassificerad, live-följande logg (**Arkiv ▸ Visa som logg…**), med filter per nivå, sökning och stöd för vanliga loggformat plus dina egna regex-format. Hanterar loggar på flera gigabyte omedelbart.
- **Markdown and HTML** — tryck F3 på en `.md`- eller `.html`-fil och läs den formaterad i stället för som källtext, med ` ```mermaid `-diagram ritade och `$…$`-matematik satt på din Mac. Inget laddas ned och ingen del av dokumentet skickas någonstans.
- **CSV Lister** — tryck F3 på en `.csv`- eller `.tsv`-fil och den öppnas som en riktig tabell med sorterbara kolumner i stället för rå text. Avgränsaren upptäcks automatiskt, så semikolonseparerade exporter ställer också upp sig, och visarens sökning hittar värden cell för cell.
- **AI Column** — lägger till en kolumn *AI Language* som identifierar varje textfils dominerande språk på enheten (med Apples NaturalLanguage-ramverk — inte en molnmodell).
- **Arkivformat** — lär appen att bläddra i och packa upp fler arkivtyper (7z, tar-familjen, gzip/bzip2/xz/zstd, och RAR där ett hjälpverktyg är installerat), som sedan öppnas som mappar.

## Slå på eller av insticksprogram

1. Välj Konfiguration ▸ Insticksprogram… för att öppna insticksfönstret.
2. Varje installerat insticksprogram visas i listan med sitt namn, sin typ och en kryssruta "Aktiverad".
3. Markera eller avmarkera kryssrutan för att aktivera eller inaktivera ett insticksprogram. Ändringar träder i kraft direkt — aktiverade insticksprogram lägger till sina menyer, kolumner och funktioner; inaktiverade håller sig undan.

![Insticksfönstret som listar installerade insticksprogram med kryssrutor och knapparna Installera och Ta bort](screenshots/plugins-window.png)
*(Bild: Insticksfönstret, där du aktiverar, inaktiverar, installerar eller tar bort insticksprogram.)*

## Installera ett nytt tillägg

Ett tillägg du hämtar kommer som ett **tilläggspaket** — en fil som slutar på `.pcplug`. Det finns fyra sätt att installera ett, och alla slutar vid samma bekräftelse:

- **Dubbelklicka på det** i Finder. Peach Commander öppnas och frågar.
- **Tryck på Retur** på det i en panel. Peach Commander är en filhanterare — filen ligger oftast redan där.
- **Dra det till tilläggsfönstret** (Inställningar ▸ Tillägg…).
- Välj **Inställningar ▸ Tillägg… ▸ Installera…** och välj paketet, en `.zip` med ett tillägg i, eller ett uppackat tilläggsbunt.

Innan något laddas visar en dialogruta tilläggets namn, version, identifierare och typ, samt vilka filtyper det tar över — ett tillägg som gör anspråk på `.iso` blir appens läsare för de filerna. Ingenting installeras förrän du klickar på **Installera**.

Finns redan ett tillägg med samma identifierare installerat säger dialogrutan det och visar båda versionerna, så att en uppdatering läses som en uppdatering ("1.0.0 → 1.1.0") och ett steg bakåt påpekas som just det.

## Innan du installerar ett

Ett tillägg är ett program som körs inuti Peach Commander, med samma åtkomst till dina filer som Peach Commander har. Det finns ingen sandlåda runt det. Installera bara tillägg från källor du litar på, precis som med vilket annat program som helst.

Tillägg som hämtats från internet sätts i karantän av macOS. Att installera ett säger åt macOS att tillåta att det läses in — därför säger bekräftelserutan det, och därför är det ett beslut du fattar och inte något som sker i tysthet.

## Ta bort ett tillägg

1. Markera tillägget i listan i tilläggsfönstret.
2. Klicka på **Ta bort**. Inbyggda funktioner påverkas inte; bara det markerade tillägget tas bort.

Ett tillägg som följer med appen går inte att radera — "Ta bort" stänger av det i stället.

## Anmärkningar

- Listan visar varje tilläggs version, typ och gränssnittsversion bredvid namn och plats, så att du kan se vad som är installerat.
- Kräver ett tillägg en nyare version av Peach Commander än din avvisas det med ett meddelande som säger det, i stället för att misslyckas obegripligt. Detsamma gäller åt andra hållet: ett tillägg byggt för ett äldre gränssnitt fortsätter fungera så länge det gränssnittet stöds.
- Vissa tillägg lägger bara till sina kolumner, menyalternativ eller panelplatser medan de är påslagna. Saknas en funktion du väntade dig, kontrollera här att dess tillägg är på.
- Hur du själv skriver eller publicerar ett tillägg står i utvecklardokumentationen, inte här.
