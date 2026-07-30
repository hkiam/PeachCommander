---
title: Redigera filer
slug: editing-files
section: Visa och redigera
order: 72
related: [viewing-files]
---

När du behöver ändra en fil snarare än bara titta på den öppnar Peach Commander den i en inbyggd redigerare. Text- och kodfiler öppnas i en fullständig redigerare med syntaxfärgning, sök och ersätt, en översikt över symbolerna i din kod, och en minikarta för snabb navigering. Binärfiler kan öppnas i en separat hex-redigerare, där du kan granska och ändra enskilda byte. Du behöver aldrig lämna appen för att göra en snabb ändring.

## Redigera en text- eller kodfil

1. Flytta markören till filen du vill ändra i endera panelen.
2. Tryck på F4, eller välj Arkiv ▸ Redigera. Filen öppnas i redigeringsfönstret.
3. Gör dina ändringar. Om filen är ett igenkänt programmerings- eller dataformat färgas nyckelord, strängar och kommentarer automatiskt.
4. Tryck på Cmd+S (eller klicka på Spara) för att skriva dina ändringar. Den första sparningen behåller en säkerhetskopia av originalet bredvid filen, så att du alltid kan falla tillbaka på den.

För att starta en helt ny textfil på den aktuella platsen, tryck på Shift+F4.

![Den inbyggda textredigeraren som visar syntaxfärgning, symbolöversikten och minikartan](screenshots/editor.png)
*(Figur: Redigeraren med syntaxfärgning, symbolöversikten till vänster och minikartan till höger.)*

## Sök, ersätt och navigera

- Tryck på Cmd+F för att öppna sökfältet. För att ersätta text, öppna sökfältet och växla det till ersättningsvyn, eller klicka på Sök/Ersätt i verktygsfältet.
- Klicka på Formatera JSON/XML för att indentera om ett JSON- eller XML-dokument till en ren, läsbar layout.
- Klicka på Symboler (eller tryck på Cmd+Shift+O) för att visa en sidopanel som listar klasserna, funktionerna och metoderna i din kod. Klicka på en post för att hoppa direkt till den.
- Tryck på Cmd+L för att hoppa till en specifik rad.
- Tryck på Cmd+\ för att hoppa mellan en klammer och dess matchande partner.
- Klicka på kartknappen för att visa eller dölja minikartan, en skalad översikt över hela filen som du kan klicka på för att rulla.
- Använd menyn Kodning i verktygsfältet om filen sparades i något annat än standardtextkodningen.

## Redigera en fil byte för byte

1. Markera filen i en panel.
2. Välj Arkiv ▸ Redigera som hex (eller högerklicka på filen och välj Redigera som hex).
3. Skriv hex-siffror för att skriva över byte, eller använd piltangenterna för att röra dig genom filen. Backspace och Delete tar bort byte.
4. Tryck på Cmd+S för att spara. Precis som med textredigeraren behålls en engångssäkerhetskopia av originalet.

## Kortkommandon

| Åtgärd | Tangent |
|---|---|
| Redigera fil | F4 |
| Skapa och redigera en ny textfil | Shift+F4 |
| Spara | Cmd+S |
| Sök | Cmd+F |
| Visa/dölj symbolöversikt | Cmd+Shift+O |
| Gå till rad | Cmd+L |
| Hoppa till matchande klammer | Cmd+\ |
| Ångra / gör om (hex-redigerare) | Cmd+Z / Cmd+Shift+Z |

## Anteckningar

- Syntaxfärgning täcker JSON, C, C#, Java, JavaScript, TypeScript, Python och Rust. Andra filtyper öppnas och redigeras ändå normalt med grundläggande färgning, men detaljerad färgning och symbolöversikten är endast tillgängliga för de språk som stöds.
- Symbolöversikten och funktionen Gå till rad gäller textredigeraren. Hex-redigeraren är avsedd för binärgranskning och redigeringar på byte-nivå, inte för text.
- Båda redigerarna behåller en säkerhetskopia av originalfilen första gången du sparar, så att en oavsiktlig ändring är lätt att ångra genom att återställa den säkerhetskopian.
