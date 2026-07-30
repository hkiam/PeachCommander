---
title: De knoppenbalk
slug: toolbar
section: Aanpassen
order: 110
related: [keyboard-shortcuts, settings]
---

De knoppenbalk is de strook met pictogramknoppen boven aan het venster. Elke knop is een sneltoets met één klik die je zelf definieert: voer een ingebouwde opdracht uit, start een extern programma of app, spring naar een map, of open een hele subbalk met meer knoppen. Het is de snelste manier om de acties die je het meest gebruikt binnen handbereik te plaatsen, en je kunt de balk precies afstemmen op de manier waarop je werkt.

## De knoppenbalk aanpassen

1. Kies **Configuratie > Werkbalk aanpassen…**, of klik met de rechtermuisknop op de balk en kies **Knoppenbalk bewerken…**.
2. De lijst links toont de huidige knoppen. Gebruik **+** om een knop toe te voegen, **—** om een scheiding toe te voegen, **−** om de geselecteerde knop te verwijderen, en **↑ / ↓** om de volgorde te wijzigen.
3. Selecteer een knop en vul het formulier rechts in:
   - **Opdracht** — typ een ingebouwde opdracht, of klik op **Kiezen…** om er een uit een lijst te selecteren. Je kunt ook het pad naar een programma of app invoeren, een map om te openen, of een andere knoppenbalk om als subbalk te gebruiken.
   - **Bijschrift** — het label en de tooltip die voor de knop worden getoond.
   - **Parameters** en **Startpad** — doorgegeven aan externe programma's. Plaatsaanduidingen zoals `%P` (bronmap), `%N` (huidig bestand) en `%S` (geselecteerde bestanden) worden ingevuld wanneer de knop wordt uitgevoerd.
   - **Pictogram** — kies een SF Symbol of gebruik het eigen pictogram van een bestand of app; zet **alleen pictogram** aan om het bijschrift te verbergen.
4. Klik op **Bewaar**. De strook wordt onmiddellijk opnieuw geladen.

![De knoppenbalk boven aan het venster met pictogramknoppen](screenshots/button-bar-crop.png)
*(Afbeelding: De knoppenbalk staat boven de bestandspanelen; elke knop voert een opdracht, programma, map of subbalk uit.)*

## Subbalken en overloop

Een knop kan een *subbalk* openen — een tweede set knoppen die over de eerste heen wordt gelegd. Klik erop om af te dalen; een **◀**-knop links brengt je terug naar de vorige balk. Wanneer er meer knoppen zijn dan in de vensterbreedte passen, worden de extra knoppen ingeklapt achter een **»**-chevron aan de rechterkant; klik erop om ze te bereiken.

## Bestanden op een knop neerzetten

Je kunt bestanden of mappen rechtstreeks op een knop slepen:

- **Mapknop** — de neergezette items worden op de achtergrond naar die map gekopieerd.
- **Programmaknop** — het programma wordt uitgevoerd met de neergezette items als selectie.
- **Opdrachtknop** — de opdracht wordt zoals gebruikelijk uitgevoerd.

## Verticale knoppenbalk

Om de strook van de bovenkant van het venster naar een kolom langs de linkerkant te verplaatsen, kies je **Weergave > Verticale knoppenbalk**. Kies het opnieuw om terug te schakelen naar de horizontale strook.

## Opmerkingen

- De balk wordt opgeslagen in een standaard knoppenbalkbestand dat compatibel is met Total Commander, zodat balken die je al hebt hergebruikt kunnen worden.
- Standaard zijn er geen sneltoetsen aan deze acties toegewezen, maar je kunt je eigen toevoegen — zie [Sneltoetsen](keyboard-shortcuts).
- Een knop zonder pictogram en zonder opdracht wordt getoond als een gewone scheiding, handig om verwante knoppen te groeperen.
