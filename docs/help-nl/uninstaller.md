---
title: Uninstaller
slug: uninstaller
section: Plug-ins
order: 126
related: [plugins, deleting-files]
---

Een app naar de Prullenmand slepen laat de bijbehorende ondersteuningsbestanden, caches, voorkeuren en containers verspreid over je Bibliotheek-mappen achter. De Uninstaller-plug-in verwijdert een applicatie **én** die overblijfselen: hij vindt alles wat de app heeft achtergelaten, toont je de lijst met een grootte per item en verplaatst het geheel naar de Prullenmand zodra je bevestigt. Het is een plug-in, dus je kunt hem uitschakelen of verwijderen via **Configuratie ▸ Plug-ins…**.

## Een app onder de cursor deïnstalleren

1. Zet de cursor op een applicatie (`.app`) in een paneel.
2. Kies **Bestand ▸ Applicatie deïnstalleren…**, of rechtsklik ▸ **Applicatie deïnstalleren…**, of druk op **Cmd+Shift+U**.
3. Het beoordelingsvenster opent en toont de app plus elk gerelateerd bestand dat het vond, elk voorzien van categorie, pad en grootte.
4. Verwijder het vinkje bij alles wat je wilt behouden en klik vervolgens op **Verplaats naar Prullenmand** (of **Definitief verwijderen**).

![Het beoordelingsvenster van de deïnstallatie met de achtergebleven bestanden van een app, aankruisvakken en groottes](screenshots/uninstaller.png)
*(Afbeelding: bekijk precies wat er wordt verwijderd voordat er iets wordt gewist.)*

## Alle geïnstalleerde apps doorbladeren

Kies **Opdrachten ▸ Applicatie deïnstalleren…** om een doorzoekbare lijst te openen van de apps die op je Mac zijn geïnstalleerd, met per app de naam, grootte en installatiedatum. Selecteer er een (of meerdere), klik op **Deïnstalleren…** en je belandt in hetzelfde beoordelingsvenster. Je kunt de lijst filteren door in het zoekveld te typen.

## Achtergebleven bestanden vinden

Kies **Opdrachten ▸ Achtergebleven bestanden zoeken…** om te scannen naar ondersteuningsbestanden, caches en voorkeuren die horen bij apps die je **al** hebt verwijderd. Beoordeel ze op dezelfde manier en ruim ze op. Als er niets wordt gevonden, meldt de plug-in dat.

## Hoe grondig te scannen

Het beoordelingsvenster heeft een betrouwbaarheidsregelaar:

- **Precise** — bestanden die verankerd zijn aan de bundle-identifier van de app. Hoge betrouwbaarheid; vooraf geselecteerd.
- **Enhanced** — voegt op naam gematchte bestanden toe; blijft onaangevinkt zodat jij kunt beslissen.
- **Deep** — Enhanced plus een Spotlight-veegactie naar al het andere dat de app noemt; blijft eveneens onaangevinkt.

## Opmerkingen

- Niets wordt rechtstreeks door de plug-in verwijderd — items gaan via de Prullenmand of de definitieve verwijdering van de app, precies als bij elke andere bestandsbewerking. Voor het verwijderen van bestanden in `/Library` of `/var` kan een beheerderswachtwoord nodig zijn.
- Voor het verwijderen sluit de plug-in de draaiende app af en ontlaadt hij de achtergronditems (launchd), en biedt vervolgens aan om eventueel nu lege leveranciersmappen op te ruimen.
- Als de app met **Homebrew** is geïnstalleerd, waarschuwt de plug-in je en stelt hij `brew uninstall --cask` voor, zodat Homebrew synchroon blijft. Ook App Store-apps worden vermeld.
- Enhanced- en Deep-matches zijn bewust minder betrouwbaar en beginnen onaangevinkt — beoordeel ze voordat je verwijdert. Sommige achtergronditems die via de moderne login-items-API zijn geïnstalleerd, kunnen hier niet worden verwijderd.
