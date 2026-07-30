---
title: Bestanden vinden
slug: searching
section: Bestanden vinden
order: 60
related: [selecting-files, quick-search-and-filter]
---

Wanneer je bestanden ergens op je Mac wilt opsporen — op naam, op wat ze bevatten, of op grootte en datum — gebruik je het venster Bestanden zoeken. Het doorzoekt een of meer mappen (en hun submappen), kan in tekstbestanden en archieven kijken, en laat je alles wat het vindt rechtstreeks in een paneel sturen zodat je met de resultaten kunt werken alsof het een gewone map is.

## Bestanden op naam vinden

1. Kies in het paneel dat de map toont die je wilt doorzoeken **Opdrachten > Bestanden zoeken…** (of druk op Cmd+Shift+F).
2. Typ op het tabblad **Algemeen** een naampatroon in **Zoeken naar**. Je kunt jokertekens gebruiken zoals `*.pdf` of `report_*.docx`. Om meerdere mappen tegelijk te doorzoeken, vermeld je ze in het startmapveld gescheiden door een puntkomma (`;`).
3. Klik op **Start**. Overeenkomsten verschijnen in de resultatenlijst eronder zodra ze worden gevonden.
4. Dubbelklik op een resultaat om naar dat bestand in het actieve paneel te springen, of selecteer een resultaat en klik op **Bekijken** (F3) om het in de ingebouwde viewer te openen.

![Het venster Bestanden zoeken op het tabblad Algemeen, met het naampatroon, de map en de resultatenlijst](screenshots/find-files-general.png)
*(Afbeelding: Het tabblad Algemeen — zoek op naampatroon over een of meer mappen.)*

## Zoeken op inhoud, grootte en datum

1. Om binnen bestanden te zoeken, selecteer je **Tekst zoeken** op het tabblad Algemeen en typ je de te zoeken tekst. Met opties kun je het **Hoofdlettergevoelig** maken, alleen een **Heel woord** laten overeenkomen, de tekst als een **Reguliere expressie** behandelen, een **Hex-inhoudszoekopdracht** uitvoeren, of bestanden vinden die de tekst **Niet bevatten**.
2. Schakel naar het tabblad **Geavanceerd** om resultaten te versmallen op **Grootte** (bijvoorbeeld `10K` tot `5M`), op **gewijzigde datum**-bereik, of op bestanden die in de laatste N dagen zijn gewijzigd.
3. Zet **In archieven zoeken** aan om binnen zip-achtige archieven te kijken (zip, jar, war en dergelijke).
4. Om de zoekopdracht te beperken tot wat je al hebt gekozen, zet je **Alleen in geselecteerde items zoeken** aan voordat je begint.

![Het venster Bestanden zoeken op het tabblad Geavanceerd, met grootte- en datumfilters](screenshots/find-files-advanced.png)
*(Afbeelding: Het tabblad Geavanceerd — filter op grootte, datum en andere attributen.)*

Als je plug-ins hebt die inhoudsvelden toevoegen (zoals afbeeldingsafmetingen), laat het tabblad **Plug-ins** je een veld aan een voorwaarde laten voldoen — bijvoorbeeld alleen afbeeldingen breder dan 1000 pixels.

![Het venster Bestanden zoeken op het tabblad Plug-ins, met een inhoudsveldvoorwaarde](screenshots/find-files-plugins.png)
*(Afbeelding: Het tabblad Plug-ins — vind overeenkomsten op door plug-ins geleverde inhoudsvelden.)*

## Snelle zoekopdrachten met Spotlight

Voor lokale mappen die macOS al heeft geïndexeerd, zet je **Spotlight gebruiken** aan op het tabblad Algemeen voor vrijwel directe resultaten. Spotlight doorzoekt de index in plaats van bestanden te scannen, dus het negeert reguliere expressies, dieptelimieten voor submappen en de reikwijdte alleen-selectie.

## Je resultaten hergebruiken en doorgeven

- **Naar lijst sturen** plaatst elk resultaat in het actieve paneel als een tijdelijke lijst, zodat je de hele set tegelijk kunt kopiëren, verplaatsen of verwijderen.
- Kies op het tabblad **Laden / Bewaren** de optie **Bewaren als sjabloon…** om de huidige zoekopdracht (patronen en opties) op te slaan en later opnieuw te kiezen uit de sjabloonlijst.

## Sneltoetsen

| Actie | Sneltoets |
| --- | --- |
| Open Bestanden zoeken | Cmd+Shift+F of Option+F7 |
| Zoekopdracht starten / stoppen | Startknop in het venster |
| Bekijk het geselecteerde resultaat | F3 |

## Opmerkingen

- Inhoudszoeken leest hele bestanden voor lokale mappen; op andere locaties worden zeer grote bestanden overgeslagen (ruwweg 16 MB, of 64 MB bij gebruik van een reguliere expressie).
- Zoeken binnen archieven daalt af tot vier niveaus van geneste archieven.
- **Mappen in resultaten opnemen** vermeldt ook mappen waarvan de namen overeenkomen, niet alleen bestanden.
- Spotlight dekt alleen geïndexeerde lokale mappen; laat het voor netwerklocaties of op patronen gebaseerde overeenkomsten uit en laat Bestanden zoeken scannen.
