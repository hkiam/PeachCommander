---
title: Markera filer
slug: selecting-files
section: Filer och mappar
order: 22
related: [copying-files, searching]
---

Innan du kopierar, flyttar, raderar eller packar något talar du först om för Peach Commander vilka objekt som ska bearbetas. Objektet som markören står på är alltid det aktuella objektet, men du kan även *markera* en eller flera filer och mappar så att ett kommando körs på dem alla på en gång. Markerade objekt sticker ut med en tydlig namnfärg i panelen.

## Markera filer och mappar

1. Klicka på en rad för att flytta markören till den. Ett enkelklick markerar bara det objektet.
2. För att markera flera objekt på en gång, håll ned Cmd och klicka på var och en, eller håll ned Shift och klicka för att markera ett intervall.
3. För att markera objektet under markören och samtidigt stega nedåt, tryck på Insert. Tryck upprepade gånger för att snabbt markera en följd av objekt. Mellanslag växlar också det aktuella objektets markering (och visar en mapps storlek).
4. För att markera allt i panelen, välj Markera > Markera alla (Ctrl+Num+), eller tryck på Cmd+A. Välj Markera > Avmarkera alla (Ctrl+Num-) för att rensa alla markeringar.

## Markera eller avmarkera efter ett mönster

1. Välj Markera > Markera grupp… (Num+) för att lägga till objekt vars namn matchar ett mönster, eller Markera > Avmarkera grupp… (Num-) för att ta bort matchande objekt från de aktuella markeringarna.
2. Skriv en jokermask. Använd `*` för valfria tecken och `?` för ett enda tecken. Separera flera masker med semikolon och lista undantag efter ett lodrätt streck — till exempel markerar `*.jpg;*.png` alla bilder, och `*.*|*.bak` markerar allt utom säkerhetskopior.

![Dialogrutan Markera grupp med en jokermask inskriven i mönsterfältet](screenshots/select-by-mask.png)
*(Bild: Markera filer med en jokermask.)*

## Invertera, samma filändelse och återställ

- **Invertera markering** (Num*, Markera-menyn) vänder på varje markering: markerade objekt blir omarkerade och tvärtom — behändigt för "allt utom dessa".
- **Markera alla med samma filändelse** (Alt+Num+, Markera-menyn) markerar varje fil som delar filändelse med objektet under markören, så en tangenttryckning tar till exempel alla `.pdf`-filer.
- **Återställ markering** (Num/, Markera-menyn) hämtar tillbaka din föregående uppsättning markeringar — användbart om ett kommando rensade dem eller du markerade fel grupp.

## Kortkommandon

| Åtgärd | Tangent |
|---|---|
| Växla markering, flytta ned | Insert |
| Växla markering (aktuellt objekt) | Space |
| Markera alla / avmarkera alla | Ctrl+Num+ / Ctrl+Num- |
| Markera alla (alternativ) | Cmd+A |
| Markera grupp efter mask | Num+ |
| Avmarkera grupp efter mask | Num- |
| Invertera markering | Num* |
| Markera alla med samma filändelse | Alt+Num+ |
| Återställ föregående markering | Num/ |

## Anmärkningar

- Markeringar och markören är oberoende: att flytta markören med piltangenterna ändrar inte vad som är markerat.
- Den överordnade mappens post (`..`) kan aldrig markeras.
- Markera grupp, Avmarkera grupp och Invertera markering matchar på filnamnet, så du kan inkludera eller utelämna mappar beroende på dialogrutans alternativ.
- När en kopiering, flytt eller radering är klar avmarkeras objekt som hanterades korrekt automatiskt, medan de som misslyckades förblir markerade så att du kan försöka igen.
