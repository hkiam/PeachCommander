---
title: Bestanden bewerken
slug: editing-files
section: Bekijken en bewerken
order: 72
related: [viewing-files]
---

Wanneer je een bestand wilt wijzigen in plaats van er alleen naar te kijken, opent Peach Commander het in een ingebouwde editor. Tekst- en codebestanden openen in een volledige editor met syntaxkleuring, zoeken en vervangen, een overzicht van de symbolen in je code, en een minimap voor snelle navigatie. Binaire bestanden kunnen in een aparte hex-editor worden geopend, waar je individuele bytes kunt inspecteren en wijzigen. Je hoeft de app nooit te verlaten om een snelle bewerking te doen.

## Een tekst- of codebestand bewerken

1. Verplaats in een van beide panelen de cursor naar het bestand dat je wilt wijzigen.
2. Druk op F4, of kies Bestand ▸ Bewerken. Het bestand opent in het editorvenster.
3. Breng je wijzigingen aan. Als het bestand een herkend programmeer- of gegevensformaat is, worden sleutelwoorden, tekenreeksen en opmerkingen automatisch gekleurd.
4. Druk op Cmd+S (of klik op Bewaar) om je wijzigingen weg te schrijven. De eerste opslag houdt een back-up van het origineel naast het bestand, zodat je er altijd op kunt terugvallen.

Om een gloednieuw tekstbestand op de huidige locatie te starten, druk je op Shift+F4.

![De ingebouwde teksteditor met syntaxkleuring, het symbooloverzicht en de minimap](screenshots/editor.png)
*(Afbeelding: De editor met syntaxkleuring, het symbooloverzicht links en de minimap rechts.)*

## Zoeken, vervangen en navigeren

- Druk op Cmd+F om de zoekbalk te openen. Om tekst te vervangen, open je de zoekbalk en schakel je over naar de vervangweergave, of klik je op Zoeken/Vervangen in de werkbalk.
- Klik op JSON/XML opmaken om een JSON- of XML-document opnieuw in te springen tot een nette, leesbare indeling.
- Klik op Symbolen (of druk op Cmd+Shift+O) om een zijbalk te tonen die de klassen, functies en methoden in je code opsomt. Klik op een item om er direct naartoe te springen.
- Druk op Cmd+L om naar een specifieke regel te springen.
- Druk op Cmd+\ om te springen tussen een haakje en zijn bijbehorende partner.
- Klik op de kaartknop om de minimap te tonen of te verbergen, een geschaald overzicht van het hele bestand waarop je kunt klikken om te scrollen.
- Gebruik het menu Codering in de werkbalk als het bestand is opgeslagen in iets anders dan de standaard tekstcodering.

## Een bestand byte voor byte bewerken

1. Selecteer het bestand in een paneel.
2. Kies Bestand ▸ Bewerken als hex (of klik met de rechtermuisknop op het bestand en kies Bewerken als hex).
3. Typ hex-cijfers om bytes te overschrijven, of gebruik de pijltoetsen om door het bestand te bewegen. Backspace en Delete verwijderen bytes.
4. Druk op Cmd+S om te bewaren. Net als bij de teksteditor wordt er een eenmalige back-up van het origineel bewaard.

## Sneltoetsen

| Actie | Toets |
|---|---|
| Bestand bewerken | F4 |
| Een nieuw tekstbestand maken en bewerken | Shift+F4 |
| Bewaren | Cmd+S |
| Zoeken | Cmd+F |
| Symbooloverzicht tonen/verbergen | Cmd+Shift+O |
| Ga naar regel | Cmd+L |
| Naar bijbehorend haakje springen | Cmd+\ |
| Ongedaan maken / opnieuw (hex-editor) | Cmd+Z / Cmd+Shift+Z |

## Opmerkingen

- Syntaxkleuring dekt JSON, C, C#, Java, JavaScript, TypeScript, Python en Rust. Andere bestandstypen openen en bewerken nog steeds normaal met basiskleuring, maar gedetailleerde kleuring en het symbooloverzicht zijn alleen beschikbaar voor de ondersteunde talen.
- Het symbooloverzicht en de functie Ga naar regel gelden voor de teksteditor. De hex-editor is bedoeld voor binaire inspectie en bewerkingen op byteniveau, niet voor tekst.
- Beide editors bewaren de eerste keer dat je opslaat een back-up van het oorspronkelijke bestand, zodat een onbedoelde wijziging eenvoudig ongedaan te maken is door die back-up te herstellen.
