---
title: Vergelijken & synchroniseren
slug: comparing-and-syncing
section: Krachtige hulpmiddelen
order: 90
related: [multi-rename]
---

Wanneer je twee kopieën van dezelfde map bijhoudt — een werkmap en een back-up, een laptop en een netwerkshare, een project en zijn archief — helpt Peach Commander je precies te zien wat er is veranderd en de twee kanten weer op één lijn te brengen. Je kunt twee mappen synchroniseren, individuele bestanden regel voor regel vergelijken, en bestanden byte voor byte inspecteren wanneer je zekerheid nodig hebt tot op het laatste teken.

## Twee mappen synchroniseren

1. Open de map die je wilt synchroniseren in het linkerpaneel en de map om ermee te vergelijken in het rechterpaneel.
2. Kies **Opdrachten ▸ Mappen synchroniseren…**. De twee mappaden worden ingevuld vanuit je panelen.
3. Stel in hoe grondig de vergelijking moet zijn: submappen opnemen, vergelijken **op inhoud** (niet alleen op datum en grootte), of de wijzigingsdatum negeren.
4. Voeg een filtermasker toe (bijvoorbeeld `*.jpg;*.png`) als je alleen bepaalde bestanden wilt synchroniseren.
5. Bekijk het resultatenraster. Elke rij toont een bestand links, een richtingspijl in het midden en het overeenkomende bestand rechts. De pijlen vertellen je wat er zal gebeuren: **→** kopieert van links naar rechts, **←** kopieert van rechts naar links, en **=** betekent dat de twee identiek zijn.
6. Pas individuele rijen aan als je het niet eens bent met een voorgestelde richting, en klik vervolgens op de synchroniseerknop om de wijzigingen uit te voeren.

![Het venster Mappen synchroniseren met twee mappaden en een resultatenraster van bestanden met linker-, gelijk- en rechterpijlen](screenshots/sync-dialog.png)
*(Afbeelding: Het venster Mappen synchroniseren vergelijkt beide kanten en stelt voor elk bestand een kopieerrichting voor.)*

## Twee bestanden op inhoud vergelijken

1. Selecteer één bestand in elk paneel (of twee bestanden in hetzelfde paneel).
2. Kies **Bestand ▸ Op inhoud vergelijken…**.
3. De twee bestanden openen naast elkaar met hun verschillen gemarkeerd. Gebruik de volgende/vorige-bediening om tussen gewijzigde blokken te springen.
4. Als je de bewerkmodus aanzet, kun je beide bestanden rechtstreeks aanpassen en je wijzigingen bewaren.

![Het vergelijkvenster met twee tekstbestanden naast elkaar met verschillende regels gemarkeerd](screenshots/diff-window.png)
*(Afbeelding: Twee tekstbestanden vergelijken; gewijzigde regels worden aan beide kanten gemarkeerd.)*

## Bestanden byte voor byte vergelijken

Wanneer twee bestanden er hetzelfde uitzien maar je moet bewijzen dat ze werkelijk identiek zijn (of de ene byte vinden die verschilt), gebruik je de binaire vergelijking. Deze toont beide bestanden in een hex-weergave met niet-overeenkomende bytes gemarkeerd, wat ideaal is om downloads te verifiëren, gecodeerde gegevens te controleren of een exacte kopie te bevestigen.

## Mappenlijsten vergelijken

Om in één oogopslag verschillen tussen twee open mappen te ontdekken, kies je **Markeren ▸ Mappen vergelijken** (Shift+F2). Peach Commander markeert de bestanden die verschillen of aan de andere kant ontbreken, zodat je erop kunt inwerken met de gebruikelijke kopieer-, verplaats- en verwijderopdrachten.

## Sneltoetsen

| Actie | Sneltoets |
| --- | --- |
| Mappenlijsten vergelijken (verschillende bestanden markeren) | Shift+F2 |
| Op inhoud vergelijken | Bestand ▸ Op inhoud vergelijken… |
| Mappen synchroniseren | Opdrachten ▸ Mappen synchroniseren… |

## Opmerkingen

- **Op inhoud versus op datum/grootte.** Een snelle vergelijking koppelt bestanden op grootte en wijzigingsdatum, wat snel is maar misleid kan worden wanneer tijdstempels verschillen voor identieke bestanden. Zet **op inhoud** aan voor een betrouwbaar resultaat ten koste van het lezen van elk bestand.
- **Submappen en filters.** Het synchroniseervenster kan in submappen afdalen en kan met een filtermasker worden beperkt, zodat je alleen de bestandstypen kunt synchroniseren die je interesseren.
- **Jij houdt de controle.** Synchroniseren draait nooit vanzelf — je bekijkt de voorgestelde richtingen in het resultatenraster en kunt ze allemaal wijzigen voordat er iets wordt gekopieerd.
- **Voorinstellingen.** Veelgebruikte synchronisatieconfiguraties kunnen worden opgeslagen en hergebruikt zodat je niet elke keer dezelfde opties opnieuw invoert.
