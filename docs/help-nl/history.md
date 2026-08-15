---
title: Globale geschiedenis
slug: history
section: Je weergave ordenen
order: 47
related: [favorites, navigating]
---

De globale geschiedenis is één venster dat je eigen werk onthoudt: bezochte mappen, geopende bestanden, uitgevoerde bewerkingen en uitgevoerde opdrachten. Druk overal op Ctrl+Cmd+H, begin te typen en je bent in een seconde terug bij de map van gisteren — zonder muis.

## De geschiedenis openen

1. Druk op Ctrl+Cmd+H of kies **Ga > Geschiedenis…**. Welk paneel actief is, doet niet ter zake.
2. Typ een paar letters. De overeenkomst hoeft niet exact of aaneengesloten te zijn: `proj rep` vindt `~/Projects/annual-report.txt`.
3. Loop met de pijltjes Omhoog en Omlaag door de resultaten terwijl je doortypt.
4. Return voert de gemarkeerde regel uit, Esc sluit het venster.

Regels staan gesorteerd op hoe recent *en* hoe vaak je ze gebruikte, dus de plekken waar je het meest werkt staan al bovenaan. Vastgezette regels gaan altijd voorop.

![The global history window listing recently visited folders and opened files](screenshots/history-palette.png)
*(Afbeelding: De globale geschiedenis — het zoekveld heeft de focus en de lijst is gesorteerd op hoe recent en hoe vaak je elke regel gebruikte.)*

## Filteren op soort

De knoppen onder het zoekveld beperken de lijst tot alle regels, mappen, bestanden, bewerkingen of favorieten. Option+1 tot Option+5 wisselen ertussen met het toetsenbord.

## Iets met een regel doen

| Actie | Sneltoets |
| --- | --- |
| De gemarkeerde regel openen | Return |
| In het paneel tonen, met de cursor erop | Option+Return |
| Een van de negen meest relevante regels openen | Cmd+1 … Cmd+9 |
| Het paneel wisselen waarin geopend wordt | Tab |
| De regel vastzetten of losmaken | Cmd+P |
| De regel uit de geschiedenis verwijderen | Cmd+Delete |
| Het pad van de regel kopiëren | Option+Cmd+C |
| De regel in de Finder tonen | Cmd+Shift+R |
| De geschiedenis sluiten | Esc |

Return doet wat bij de regel past: een map opent in het doelpaneel, een bestand opent zoals het vanuit het paneel zou doen, en een opdrachtregel komt in de opdrachtregel te staan zodat je hem kunt nakijken en uitvoeren. Het doelpaneel staat onderaan het venster en Tab wisselt het.

## Een bewerking herhalen

Een kopie of verplaatsing verschijnt onder **Bewerkingen**, en Return voert die opnieuw uit — dezelfde items naar dezelfde map, via de gewone overdrachtswachtrij en haar vragen over overschrijven. Items die er niet meer zijn worden overgeslagen, en als er geen over is wordt dat gezegd.

Verwijderingen en naamswijzigingen staan er wel, maar worden nooit herhaald: Return toont in plaats daarvan waar ze gebeurden. Een verwijdering herhalen mag geen toets ver liggen in een lijst die je alleen doorneemt.

## Het in de hand houden

Instellingen ▸ Overig bepaalt of er een geschiedenis wordt bijgehouden, hoeveel regels die bewaart en na hoeveel dagen ze worden vergeten. Vastgezette regels zijn uitgezonderd en 0 dagen bewaart alles; de lijst staat in `history.ini` in je configuratiemap en overleeft herstarts.

## Opmerkingen

- Iets uit de geschiedenis openen geldt als gebruik: daarom blijft stijgen waar je naar terugkeert.
- Mappen binnen een archief, op een server of in een plug-inschijf worden niet onthouden: zo'n pad betekent niets zonder de koppeling die het opleverde, en de eigen geschiedenis van het paneel bewaart ze zolang die open is.
- Dit is niet de eigen mappengeschiedenis van het paneel op Alt+Omlaag, die alleen op volgorde toont waar dat ene paneel is geweest.
