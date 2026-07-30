---
title: macOS-integration
slug: macos-integration
section: macOS och integritet
order: 130
related: [opening-files, privacy-and-security]
---

Peach Commander fungerar på samma sätt som resten av din Mac. Apparna du använder, Finder-taggarna du förlitar dig på, delningsbladet, Quick Look och till och med styrplattesvep beter sig alla här precis som de gör i Finder – så du behöver sällan lämna appen för att få något gjort.

## Öppna filer med valfri app

Högerklicka på en fil (eller ett urval) för att nå systemåtgärderna för den:

1. Välj **Öppna** för att öppna objektet på samma sätt som Return skulle göra.
2. Välj **Öppna i standardapp** för att lämna det till appen macOS normalt använder för den typen.
3. Peka på **Öppna med** för att välja bland varje app som kan öppna filen. Varje app listas med sitt namn och sin ikon.
4. Längst ned i **Öppna med**, välj **Annat…** för att själv bläddra fram till valfri app.

## Visa, dela och förhandsvisa

- **Visa i Finder** öppnar ett Finder-fönster med objektet markerat – praktiskt när du behöver Finders egna kommandon.
- **Dela…** öppnar det vanliga macOS-delningsbladet för de markerade filerna (Mail, Meddelanden, AirDrop och allt annat du har aktiverat i Systeminställningar).
- **Quick Look** visar en förhandsvisning i full storlek utan att öppna en app. Tryck på Cmd+Y, eller välj det från Visa-menyn eller högerklicksmenyn.

## Finder-taggar

Högerklicka på en fil och peka på **Taggar** för att växla de sju standardfärgtaggarna i Finder (Röd, Orange, Gul, Grön, Blå, Lila, Grå). En bock visar vilka taggar som redan är tillämpade. Taggar som ställs in här är samma Finder-taggar som du ser överallt annars på din Mac.

## Öppna en terminal här

Välj **Arkiv ▸ Öppna terminal här** (eller **Kommandon ▸ Öppna terminal här**), eller tryck på Cmd+Option+T, för att öppna Terminal redan riktad mot den aktiva panelens mapp.

## Tjänster och styrplatta

- Den vanliga macOS-menyn **Tjänster** fungerar på det aktuella urvalet, så alla tjänster som tar emot filer är tillgängliga.
- På en styrplatta flyttar ett tvåfingers horisontellt svep genom panelens historik som en webbläsare: svep höger för att gå **Bakåt**, svep vänster för att gå **Framåt**.

## Kortkommandon

| Åtgärd | Kortkommando |
| --- | --- |
| Quick Look | Cmd+Y |
| Öppna terminal här | Cmd+Option+T |

## Anteckningar

- Styrplattesvepets gest utlöses endast när systemets styrplattegest **Svep mellan sidor** är påslagen i Systeminställningar.
- Öppna terminal här startar Terminal; det är inte tillgängligt medan du bläddrar inuti ett arkiv.
- Taggar, Visa i Finder, Dela och Öppna med gäller riktiga filer på disk, så de erbjuds inte för objekt inuti arkiv eller på raden för den överordnade mappen (..).
- Vissa macOS-funktioner behöver behörighet innan Peach Commander kan läsa varje mapp. Om filer ser ut att saknas, se **Integritet och säkerhet** för guiden om Full Disk Access (Kommandon ▸ Full Disk Access…).
