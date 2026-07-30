---
title: Bestanden & mappen openen
slug: opening-files
section: Bestanden en mappen
order: 20
related: [viewing-files, selecting-files]
---

Peach Commander opent bestanden en mappen rechtstreeks vanuit beide panelen, met dezelfde apps en systeemfuncties waarop je al in Finder vertrouwt. Druk op een toets om het item onder de cursor in zijn standaardapp te openen, of klik met de rechtermuisknop voor een volledig menu met acties — openen met een andere app, het item tonen in Finder, delen, of een Terminal-venster openen precies daar waar je bent.

## Een item openen

1. Klik op een bestand of map in een paneel om de cursor erop te plaatsen (de gemarkeerde rij).
2. Druk op Enter (of dubbelklik).
   - Een map opent in hetzelfde paneel.
   - Een bestand opent in zijn standaard-macOS-app — dezelfde app die Finder zou gebruiken.
   - Een archief (zoals een .zip) opent als een map zodat je erin kunt bladeren.

![Het hoofdvenster van Peach Commander met beide panelen die bestanden en mappen tonen](screenshots/main-window.png)
*(Afbeelding: Plaats de cursor op een willekeurig item en druk vervolgens op Enter om het te openen.)*

## Openen met een andere app, tonen of delen

Klik met de rechtermuisknop op een bestand (of druk op Shift+F10) om het menu van het item te openen en kies vervolgens:

- **Open** of **Openen in standaardapp** — open het bestand zoals Enter zou doen.
- **Openen met** — kies een geïnstalleerde app die dit bestand kan openen, of kies **Andere…** om er een te zoeken.
- **Quick Look** — bekijk een voorbeeld van het bestand zonder een app te openen.
- **Toon in Finder** — toon het bestand geselecteerd in een Finder-venster.
- **Deel…** — verstuur het bestand via het macOS-deelvenster.

Het menu voegt ook de standaard-macOS-**Diensten** voor het geselecteerde bestand samen, en voegt **Labels** toe zodat je de gebruikelijke Finder-kleurlabels kunt toepassen.

## Een Terminal in de huidige map openen

Kies **Open Terminal Here** in het menu Bestand of Opdrachten (Cmd+Option+T) om een Terminal-venster te openen dat al op de map van het actieve paneel is gericht.

## Sneltoetsen

| Actie | Toets |
|---|---|
| Open item onder cursor | Enter |
| Bestand bekijken (viewer) | F3 |
| Bestand bewerken | F4 |
| Quick Look-voorbeeld | Cmd+Y |
| Toon info / eigenschappen | Option+Enter |
| Open menu van item | Shift+F10 of rechtermuisklik |
| Open Terminal hier | Cmd+Option+T |

## Opmerkingen

- "Standaardapp" betekent de app die macOS is ingesteld te gebruiken voor dat bestandstype; wijzig deze in het Toon info-venster van het bestand, precies zoals in Finder.
- **Toon in Finder**, **Deel…** en **Openen met ▸ Andere…** gelden voor items op de schijf van je Mac. Ze zijn niet beschikbaar voor items binnen een archief of op een externe verbinding (FTP/SFTP).
- Met de rechtermuisknop op een lopend proces klikken (in een procesweergave) toont een korter, processpecifiek menu in plaats van de bestandsacties.
