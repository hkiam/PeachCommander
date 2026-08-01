---
title: Bestanden bekijken
slug: viewing-files
section: Bekijken en bewerken
order: 70
related: [editing-files, searching]
---

Peach Commander heeft een ingebouwde viewer waarmee je in een bestand kunt kijken zonder een andere app te openen of het bestand te wijzigen. Druk op F3 op het item onder de cursor en de viewer opent onmiddellijk, zelfs voor zeer grote bestanden. Hij kiest automatisch de beste manier om de inhoud te tonen: leesbare tekst, syntaxgekleurde code, een ruwe hex-dump, of een afbeelding op ware grootte. Je kunt ook een voorbeeld van een bestand direct in het venster bekijken met Quick View, of het aan macOS Quick Look overhandigen.

## Een bestand bekijken

1. Verplaats de cursor naar een bestand in het actieve paneel.
2. Druk op F3 (of kies Bekijken in het menu Bestand). De viewer opent in zijn eigen venster.
3. Gebruik de werkbalk om te wisselen hoe de inhoud wordt getoond: Tekst, Code, Hex, Afbeelding of Weergegeven. Laat het op de automatische instelling staan om Peach Commander te laten beslissen.
4. Scroll met de pijltoetsen, Page Up/Page Down en de schuifbalk. Voor lange tekst zet je de minimapknop aan om het hele bestand in één oogopslag te zien en erdoorheen te springen.
5. Druk op N om naar het volgende geselecteerde bestand te springen, of sluit het venster met Esc.

![De ingebouwde viewer die een tekstbestand toont met de minimap rechts](screenshots/lister-text.png)
*(Afbeelding: Een tekstbestand bekijken, met de representatiekiezer en minimap in de werkbalk.)*

## Tekst vinden en de codering wijzigen

- Druk op Ctrl+F om binnen het bestand te zoeken. Druk op F3 om naar de volgende overeenkomst te springen en Shift+F3 voor de vorige.
- Als tekst er verminkt uitziet, klik je op Codering in de werkbalk (of druk je op E) om door tekstcoderingen te bladeren tot het correct leest; de automatische instelling krijgt het meestal goed.
- Druk op W om regelterugloop voor lange regels te wisselen.

## Quick View en Quick Look

Quick View toont een live voorbeeld in het paneel dat je *niet* gebruikt, zodat je aan de ene kant kunt blijven bladeren terwijl je aan de andere kant een voorbeeld bekijkt.

1. Druk op Ctrl+Q. Het inactieve paneel verandert in een voorbeeldgebied.
2. Verplaats de cursor over verschillende bestanden in het actieve paneel om er van elk een voorbeeld te zien.
3. Druk nogmaals op Ctrl+Q, of op Esc, om het paneel terug te brengen naar een normale bestandslijst.

Voor een snel schermvullend voorbeeld dat door macOS zelf wordt verzorgd, druk je op Cmd+Y (Quick Look). Druk nogmaals op Cmd+Y of Space om het te sluiten.

## Sneltoetsen

| Actie | Sneltoets |
| --- | --- |
| Bestand onder cursor bekijken | F3 |
| Alleen het bestand onder de cursor bekijken (gemarkeerde bestanden negeren) | Shift+F3 |
| Openen in een externe viewer | Option+F3 |
| Zoeken binnen de viewer | Ctrl+F |
| Volgende / vorige overeenkomst | F3 / Shift+F3 |
| Quick View in het andere paneel | Ctrl+Q |
| Quick Look (macOS-voorbeeld) | Cmd+Y |
| Sluit de viewer of Quick View | Esc |

## De infopagina in het zijpaneel

Het zijpaneel (**Weergave > Voorvertoningspaneel**, of Cmd+Shift+P) heeft een pagina **Info** die het item onder de cursor toont zoals de infozijbalk van de Finder dat doet.

- De voorvertoning vult de breedte van het paneel: maakt u het paneel breder, dan groeit de voorvertoning mee.
- Het is een echte macOS-voorvertoning, geen kleine miniatuur: elk formaat dat Snelle weergave kan tonen werkt hier, en een document van meerdere pagina’s blader je binnen de voorvertoning pagina voor pagina door.
- Daaronder staan de naam, de soort en de grootte, en vervolgens wanneer het item is aangemaakt en gewijzigd en in welke map het staat.

Bij het verplaatsen van de cursor worden naam en gegevens meteen bijgewerkt; de voorvertoning volgt even later, zodat een ingedrukte pijltoets door een lange map niet voor elke regel een voorvertoning start.

## Opmerkingen

- De viewer is alleen-lezen. Om een bestand te wijzigen, gebruik je in plaats daarvan de editor (zie Bestanden bewerken).
- Zeer grote bestanden openen zonder vertraging: tekst opent een snelle, scrollbare weergave en de hex-weergave streamt bij elke grootte rechtstreeks van schijf.
- Druk op F3 op een map om in plaats van bestandsbytes een samenvatting van de inhoud en totale grootte te zien.
- De modus Weergegeven toont opgemaakte inhoud zoals webpagina's; de hex-modus toont de ruwe bytes naast hun tekens, wat handig is om binaire bestanden te inspecteren.
