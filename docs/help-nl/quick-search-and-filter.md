---
title: Snelzoeken & filter
slug: quick-search-and-filter
section: Je weergave ordenen
order: 44
related: [searching, view-modes-and-sorting]
---

Wanneer een map honderden items bevat, hoef je zelden te scrollen. Met Peach Commander kun je direct naar een bestand springen door de naam te typen (snelzoeken), de lijst terugbrengen tot alleen de items die je interesseren (snelfilter), en de dotbestanden tonen of verbergen die macOS normaal uit het zicht houdt. Alle drie werken binnen het actieve paneel zonder een venster te openen.

## Naar een bestand springen door te typen (snelzoeken)

1. Klik op een bestandspaneel zodat het actief is.
2. Begin het begin van een naam te typen. De cursor springt naar het eerste overeenkomende item.
3. Blijf typen om de overeenkomst te verfijnen, of druk nogmaals op dezelfde letter om door items te bladeren die met die letter beginnen.
4. De getypte tekst wordt na een korte pauze gewist, zodat je op elk moment een nieuwe zoekopdracht kunt starten.

Standaard gaan gewone letters naar de opdrachtregel en wordt snelzoeken geactiveerd met Ctrl+Option+letter (het klassieke gedrag). Je kunt snelzoeken zo instellen dat het in plaats daarvan op gewoon typen reageert, of het uitzetten, in de Configuratie-instellingen.

## De lijst filteren (snelfilter)

1. Druk in het actieve paneel op Ctrl+S om het snelfilter aan te zetten.
2. Typ een filtermasker. Het paneel wordt live versmald tot overeenkomende items terwijl je typt.
3. Druk op Esc om het filter te wissen en weer alles te tonen.

Het filter accepteert verschillende soorten maskers:

- **Platte tekst** komt overeen met elke naam die bevat wat je hebt getypt (bijvoorbeeld toont `report` elk item met "report" ergens in de naam).
- **Jokertekens** gebruiken `*` (willekeurige tekens) en `?` (één teken). Scheid meerdere maskers met een puntkomma en voeg uitsluitingen toe na een verticale streep, bijvoorbeeld `*.jpg;*.png|*thumb*` om afbeeldingen te tonen maar miniaturen te verbergen.
- **Finder-labels** filteren op labelkleur: typ `tag:red` (of `#red`) om alleen rood-gelabelde items te tonen, of een kaal `tag:` om alles te tonen dat een label draagt.

## Verborgen bestanden tonen

Druk op Ctrl+H, of kies de opdracht uit het menu Weergave, om verborgen items te wisselen (namen die met een punt beginnen en door het systeem verborgen bestanden). De instelling geldt voor het actieve paneel en wordt tussen sessies onthouden.

## Sneltoetsen

| Actie | Sneltoets |
| --- | --- |
| Snelzoeken (klassieke modus) | Ctrl+Option+letter |
| Snelfilter aan/uit | Ctrl+S |
| Filter wissen / annuleren | Esc |
| Verborgen bestanden tonen/verbergen | Ctrl+H |

## Opmerkingen

- Snelzoeken verplaatst alleen de cursor; snelfilter verandert daadwerkelijk welke items worden weergegeven. Gebruik het filter wanneer je op een subset wilt werken (bijvoorbeeld alleen de overeenkomsten selecteren of kopiëren).
- De filter- en verborgen-bestanden-instellingen zijn per paneel, zodat de twee kanten tegelijk verschillende dingen kunnen tonen.
- Snelzoeken vindt overeenkomsten van namen vanaf het begin; de platte-tekstmodus van het snelfilter vindt overeenkomsten overal in de naam. Gebruik een jokerteken zoals `*text*` als je wilt dat het filter zich op dezelfde manier gedraagt.
