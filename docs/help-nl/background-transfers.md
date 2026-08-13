---
title: Overdrachten op de achtergrond
slug: background-transfers
section: Bestanden en mappen
order: 32
related: [copying-files, downloading-from-url]
---

Grote kopieer-, verplaats-, verwijder- en downloadtaken hoeven je werk niet op te houden. Peach Commander kan ze op de achtergrond uitvoeren en ze allemaal op één plek verzamelen: de Achtergrondoverdrachtbeheerder. Daar bekijk je de voortgang en overdrachtssnelheid van elke taak, pauzeer of hervat je hem, annuleer je hem, of zet je taken in de rij om later te starten. Omdat een achtergrondtaak op zichzelf draait, houdt hij je nooit tegen om te bladeren, bestanden te openen of de volgende overdracht te starten.

## Zo doe je dat

1. Start een kopieer-, verplaats-, verwijder- of downloadtaak en kies om hem op de achtergrond uit te voeren. De taak verschijnt in de Achtergrondoverdrachtbeheerder.
2. Open de beheerder op elk moment via **Opdrachten ▸ Achtergrondoverdrachtbeheerder…** (of druk op Cmd+Shift+B).
3. Elke taak toont een titel, een voortgangsbalk en een live regel met voltooide bestanden, overgedragen bytes en huidige snelheid.
4. Gebruik de knoppen per taak om te **Pauzeren**, te **Hervatten** of te **Annuleren** terwijl een taak loopt.
5. Een lopende taak heeft ook een snelheidsmenu. Kies een limiet — 1, 5 of 20 MB/s, of volle snelheid — om één overdracht uit de weg van een andere te halen zonder de rest te vertragen. Het werkt meteen; **Standaard** geeft de taak terug aan de limiet uit Configuratie.
6. Voor taken die u hebt toegevoegd maar nog niet gestart (vastgehouden taken) klikt u op **Start** bij de taak, of op **Alles starten** voor de hele wachtlijst. Met **▲** en **▼** verplaatst u een wachtende taak naar voren of naar achteren in de wachtrij; de knoppen verschijnen alleen waar de verplaatsing mogelijk is, zodat een wachtende taak nooit de al lopende overdracht inhaalt.
7. Als alles wat je belangrijk vindt klaar is, klik je op **Voltooide wissen** om de lijst op te ruimen.

![De Achtergrondoverdrachtbeheerder met actieve en wachtende taken, voortgangsbalken en knoppen Pauzeer, Hervat en Annuleer.](screenshots/transfer-manager.png)

*Elke overdracht is een rij die je onafhankelijk kunt pauzeren, hervatten of annuleren.*

## Sneltoetsen

| Actie | Sneltoets |
| --- | --- |
| De Achtergrondoverdrachtbeheerder openen | Cmd+Shift+B |

## Tips

- **Beperk de snelheid.** Om te voorkomen dat een grote overdracht je verbinding of schijf verzadigt, stel je een snelheidslimiet in het kopieervenster in voordat je de taak start. De beheerder toont dan live de begrensde snelheid.
- **Zet in de wacht voor later.** Wachtende taken staan in de lijst zonder te lopen totdat je op Start (of Start alle) drukt, zodat je meerdere overdrachten kunt klaarzetten en ze samen kunt starten.
- **Meerdere tegelijk.** Taken lopen onafhankelijk, zodat je er een kunt pauzeren terwijl een andere doorgaat.

## Opmerkingen

Omdat een achtergrondtaak loopt zonder dat je toekijkt, kan hij niet stoppen om vragen te stellen. Bestaat er al een bestand op de bestemming, dan overschrijft de achtergrondtaak het; kan een afzonderlijk item niet worden overgedragen, dan wordt dat item overgeslagen en gaat de taak door. Wanneer de taak klaar is, worden overgeslagen items verzameld in een foutenlogboek zodat je precies kunt nagaan wat er misging.
