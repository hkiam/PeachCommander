---
title: Flytta och byta namn
slug: moving-and-renaming
section: Filer och mappar
order: 26
related: [copying-files, multi-rename]
---

Flytt omplacerar filer och mappar istället för att dubblera dem, och namnbyte ändrar deras namn utan att röra deras innehåll. Eftersom Peach Commander visar två paneler sida vid sida handlar flytt bara om att välja det du vill ha i den ena panelen och skicka det till mappen som är öppen i den andra. Du kan även byta namn på ett objekt på plats, eller ge flyttade objekt nya namn i farten med hjälp av en jokermask.

## Flytta filer till den andra panelen

1. Öppna i källpanelen mappen som innehåller objekten du vill flytta, och öppna målmappen i den andra panelen.
2. Markera filen eller mappen som ska flyttas. För att flytta flera samtidigt, markera dem alla först (se *Markera filer*).
3. Tryck på F6, eller välj **Arkiv > Flytta**.
4. Kontrollera målmappen som visas i dialogen och klicka på **OK** (eller tryck på Return) för att starta flytten.

![Flyttdialogen som visar målsökvägsfältet, alternativ och en kryssruta för kön](screenshots/copy-dialog.png)
*(Figur: Flyttdialogen använder samma målfält som kopiering – skriv en sökväg, eller lägg till en jokermask för att byta namn medan du flyttar.)*

Flyttar på samma disk sker nästan omedelbart. När målet ligger på en annan disk kopierar Peach Commander objekten och tar sedan bort originalen först efter att varje fil har anlänt säkert.

## Byt namn på plats

1. Markera en enskild fil eller mapp.
2. Tryck på Shift+F6, eller välj **Arkiv > Byt namn**.
3. Redigera namnet direkt i panelen, och tryck sedan på Return för att bekräfta eller Esc för att avbryta.

## Byt namn medan du flyttar

Målfältet i flyttdialogen accepterar en jokermask, så att du kan byta namn på objekt allteftersom de flyttas:

1. Markera objekten och tryck på F6.
2. I målfältet, lägg till en namnmask efter målmappen, till exempel `/Users/you/Archive/*_backup.*`.
3. `*` står för det ursprungliga namnet och `.*` för det ursprungliga filtillägget. Bekräfta för att flytta och byta namn i ett steg.

## Kortkommandon

| Åtgärd | Kortkommando |
| --- | --- |
| Flytta till den andra panelen | F6 |
| Byt namn på plats | Shift+F6 |

## Tips

- Flyttdialogen erbjuder samma alternativknapp och kryssruta för bakgrundskön som kopiering, så att du kan köa stora flyttar och låta dem köras i bakgrunden.
- Att flytta inom samma disk är en snabb operation på plats, så det är säkert för mycket stora mappar. En flytt mellan diskar tar längre tid eftersom data först kopieras och sedan tas källan bort.
- För att byta namn på många filer samtidigt med numrering, sök-och-ersätt eller mönster, använd Verktyget för massnamnbyte istället (se *Massnamnbyte*).
