---
title: Bestanden kopiëren
slug: copying-files
section: Bestanden en mappen
order: 24
related: [moving-and-renaming, background-transfers]
---

Peach Commander is opgebouwd rond twee panelen naast elkaar: het ene bevat de bestanden waarmee je werkt, het andere is de bestemming. Kopiëren neemt wat in het actieve paneel geselecteerd is en plaatst een duplicaat in de map die in het andere paneel wordt getoond, waarbij de originelen op hun plaats blijven. Dit is de snelste manier om bestanden en mappen tussen twee locaties te dupliceren zonder te slepen.

## Een selectie naar het andere paneel kopiëren

1. Open in het ene paneel de map met de items die je wilt kopiëren.
2. Open in het andere paneel de map waar de kopieën naartoe moeten.
3. Selecteer de bestanden en mappen om te kopiëren. Als er niets is geselecteerd, wordt het item onder de cursor gebruikt.
4. Druk op F5. Het kopieervenster opent, met het bestemmingspad al ingevuld.

![Het kopieervenster met het bestemmingspad en opties](screenshots/copy-dialog.png)
*(Afbeelding: Het kopieervenster. Het doelpad wijst naar het andere paneel; gebruik de opties om het kopiëren fijn af te stemmen.)*

5. Pas indien nodig de bestemming aan en bevestig vervolgens om het kopiëren te starten.

## Kopieeropties

Voordat je bevestigt, kun je wijzigen hoe het kopiëren zich gedraagt:

- **Alleen nieuwere bestanden** — slaat elk item over waarvan de kopie al bestaat en even oud of nieuwer is, zodat alleen gewijzigde bestanden worden bijgewerkt.
- **Metadata behouden** — behoudt datums, machtigingen en andere bestandsattributen op de kopieën. Dit staat standaard aan.
- **Snelheidslimiet** — begrenst de overdrachtssnelheid zodat een grote kopieerbewerking je schijf of netwerkverbinding niet verzadigt.
- **Hernoemmasker** — typ een jokertekenpatroon in het doelveld (bijvoorbeeld `*.bak`) om items te hernoemen terwijl ze worden gekopieerd.

Je kunt de taak ook naar de achtergrondwachtrij sturen in plaats van ernaar te kijken — zie Achtergrondoverdrachten.

## Voortgang

Een voortgangsvenster toont het huidige bestand en de totale taak met afzonderlijke balken, plus de overdrachtssnelheid. Je kunt op elk moment pauzeren en hervatten, of de lopende kopieerbewerking naar de achtergrondoverdrachtsbeheerder sturen om door te werken terwijl deze afrondt.

![Het voortgangsvenster voor overdrachten met een voortgangsbalk, bestands- en byte-aantallen, en de knoppen Pauzeer en Annuleer](screenshots/progress-dialog.png)
*(Afbeelding: Het voortgangsvenster dat tijdens een kopieer- of verplaatsbewerking wordt getoond.)*

## Bestanden die al bestaan afhandelen

Als een kopieerbewerking een bestaand bestand zou vervangen, stopt Peach Commander en vraagt wat te doen. Een voorbeeld van beide bestanden helpt je te beslissen.

![Het conflictvenster voor overschrijven waarin twee bestanden worden vergeleken](screenshots/overwrite-dialog.png)
*(Afbeelding: Het overschrijfvenster vergelijkt het bestaande bestand met het bestand dat wordt gekopieerd.)*

Je keuzes zijn onder andere:

- **Overschrijf** het bestaande bestand, of **Overschrijf alles** om dat op elk resterend conflict toe te passen.
- **Sla over** dit bestand, of **Sla alles over** wat er aan conflicten resteert.
- **Hernoem** de binnenkomende kopie automatisch zodat beide bestanden behouden blijven.
- **Voeg toe** de binnenkomende gegevens aan het eind van het bestaande bestand.
- Overschrijf alleen wanneer de bron **nieuwer** of **groter** is dan het bestaande bestand.

## Sneltoetsen

| Actie | Toets |
|---|---|
| Selectie naar het andere paneel kopiëren | F5 |
| Kopiëren in dezelfde map (een hernoemd duplicaat maken) | Shift+F5 |
| Open de achtergrondoverdrachtsbeheerder | Cmd+Shift+B |

## Opmerkingen

- Kopiëren tussen twee locaties op dezelfde schijf gebruikt een snelle kloon wanneer de schijf dit ondersteunt, zodat grote bestanden vrijwel direct kopiëren en weinig extra ruimte gebruiken.
- Mappen worden gekopieerd met alles wat erin zit.
- Om bestanden te verplaatsen in plaats van te kopiëren, gebruik je F6. Om taken in de wachtrij te bekijken of te beheren, open je de achtergrondoverdrachtsbeheerder met Cmd+Shift+B.
