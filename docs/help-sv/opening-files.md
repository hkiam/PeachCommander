---
title: Öppna filer och mappar
slug: opening-files
section: Filer och mappar
order: 20
related: [viewing-files, selecting-files]
---

Peach Commander öppnar filer och mappar direkt från valfri panel, med samma appar och systemfunktioner som du redan förlitar dig på i Finder. Tryck på en tangent för att öppna objektet under markören i dess standardapp, eller högerklicka för att nå en fullständig åtgärdsmeny — öppna med en annan app, visa objektet i Finder, dela det eller öppna ett terminalfönster precis där du står.

## Öppna ett objekt

1. Klicka på en fil eller mapp i en panel för att placera markören på den (den markerade raden).
2. Tryck på Enter (eller dubbelklicka).
   - En mapp öppnas i samma panel.
   - En fil öppnas i sin macOS-standardapp — samma app som Finder skulle använda.
   - Ett arkiv (till exempel en .zip) öppnas som en mapp så att du kan bläddra inuti det.

![Peach Commanders huvudfönster med båda panelerna som visar filer och mappar](screenshots/main-window.png)
*(Bild: Placera markören på valfritt objekt och tryck sedan på Enter för att öppna det.)*

## Öppna med en annan app, visa eller dela

Högerklicka på en fil (eller tryck på Shift+F10) för att öppna objektets meny och välj sedan:

- **Öppna** eller **Öppna i standardapp** — öppnar filen som Enter skulle göra.
- **Öppna med** — välj valfri installerad app som kan öppna filen, eller välj **Annan…** för att bläddra fram en.
- **Quick Look** — förhandsvisa filen utan att öppna en app.
- **Visa i Finder** — visa filen markerad i ett Finder-fönster.
- **Dela…** — skicka filen via macOS delningsmeny.

Menyn slår även samman de vanliga macOS-**tjänsterna** för den valda filen och lägger till **Taggar** så att du kan använda de vanliga Finder-färgtaggarna.

## Öppna en terminal i den aktuella mappen

Välj **Öppna terminal här** från Arkiv- eller Kommandon-menyn (Cmd+Option+T) för att öppna ett terminalfönster som redan pekar på den aktiva panelens mapp.

## Kortkommandon

| Åtgärd | Tangent |
|---|---|
| Öppna objekt under markören | Enter |
| Visa fil (visare) | F3 |
| Redigera fil | F4 |
| Quick Look-förhandsvisning | Cmd+Y |
| Visa info / egenskaper | Option+Enter |
| Öppna objektets meny | Shift+F10 eller högerklick |
| Öppna terminal här | Cmd+Option+T |

## Anmärkningar

- "Standardapp" betyder den app som macOS är inställt på att använda för den filtypen; ändra den i filens info-ruta, precis som i Finder.
- **Visa i Finder**, **Dela…** och **Öppna med ▸ Annan…** gäller objekt på din Macs disk. De är inte tillgängliga för objekt inuti ett arkiv eller på en fjärranslutning (FTP/SFTP).
- Att högerklicka på en process som körs (i en processvy) visar en kortare, processspecifik meny i stället för filåtgärderna.
