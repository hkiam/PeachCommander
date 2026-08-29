---
title: De knoppenbalk
slug: toolbar
section: Aanpassen
order: 110
related: [keyboard-shortcuts, settings, macros]
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

## Een programma op de balk slepen

U hoeft de editor niet te openen om een hulpmiddel op de balk te zetten. Sleep een programma, een app of een script vanuit een paneel — of vanuit de Finder — naar **vrije ruimte** op de balk. Een streepje toont waar het terechtkomt; loslaten maakt daar de knop.

- **Programma’s, apps en scripts** worden een knop die ze op uw huidige selectie uitvoert: de parameters van de nieuwe knop staan op `%S`, de geselecteerde bestandsnamen. Maak dat veld leeg in de editor voor een hulpmiddel dat geen argumenten hoort te krijgen.
- **Mappen** worden een knop die daarheen springt — en die er bestanden in kopieert als u ze er later op laat vallen.
- Wat niet uitgevoerd kan worden, wordt geweigerd: een gewoon document heeft geen uitvoerrecht, een knop ervoor zou bij de eerste klik mislukken.

Loslaten op een **bestaande** knop behoudt zijn betekenis: die knop wordt met de losgelaten bestanden uitgevoerd. Alleen vrije ruimte maakt een nieuwe aan.

## Bestanden op een knop neerzetten

Je kunt bestanden of mappen rechtstreeks op een knop slepen:

- **Mapknop** — de neergezette items worden op de achtergrond naar die map gekopieerd.
- **Programmaknop** — het programma wordt uitgevoerd met de neergezette items als selectie.
- **Opdrachtknop** — de opdracht wordt zoals gebruikelijk uitgevoerd.

## De knoppenbalk verbergen

Kies **Weergave > Knoppenbalk** om de balk te verbergen, en nogmaals om hem terug te halen. Dezelfde schakelaar staat op de pagina **Lay-out** in de instellingen, en de keuze wordt onthouden.

## Verticale knoppenbalk

Om de strook van de bovenkant van het venster naar een kolom langs de linkerkant te verplaatsen, kies je **Weergave > Verticale knoppenbalk**. Kies het opnieuw om terug te schakelen naar de horizontale strook.

## Opmerkingen

- De balk wordt opgeslagen in een standaard knoppenbalkbestand dat compatibel is met Total Commander, zodat balken die je al hebt hergebruikt kunnen worden.
- Standaard zijn er geen sneltoetsen aan deze acties toegewezen, maar je kunt je eigen toevoegen — zie [Sneltoetsen](keyboard-shortcuts).
- Een knop zonder pictogram en zonder opdracht wordt getoond als een gewone scheiding, handig om verwante knoppen te groeperen.
