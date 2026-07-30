---
title: Bekende beperkingen
slug: known-limitations
section: Hulp en probleemoplossing
order: 144
related: [troubleshooting]
---

Peach Commander doet veel, maar een paar functies hebben in de huidige versie eerlijke beperkingen. Die vooraf kennen voorkomt verwarring als iets zich onverwacht gedraagt. Deze pagina somt de huidige beperkingen op en, waar mogelijk, een eenvoudige tijdelijke oplossing.

## Archieven

- **Zeer grote ZIP-bestanden (ZIP64) kunnen niet door de ingebouwde lezer worden geopend.** Standaard ZIP-, TAR- en met gzip gecomprimeerde TAR-archieven openen rechtstreeks als mappen. ZIP64-archieven — gebruikt wanneer een archief meer dan ongeveer 65.000 items bevat of groter is dan 4 GB — vallen buiten wat de ingebouwde lezer aankan, dus ze kunnen mislukken bij het openen of onvolledig worden getoond.
- **Versleutelde ZIP-archieven** (zowel ouder ZipCrypto als WinZip AES) worden ondersteund om te doorbladeren, maar er wordt om het wachtwoord gevraagd.
- Andere formaten zoals CPIO, ISO, CAB, LZH, XAR en PAX openen via een hulpprogramma in plaats van de ingebouwde lezer.

## Netwerk (SFTP / SCP)

- **Bestandsattributen wijzigen via SFTP heeft in deze versie geen effect.** Je kunt bladeren, downloaden en uploaden via SFTP/SCP, maar verzoeken om rechten, eigendom of tijdstempels op een externe server te wijzigen worden stilzwijgend genegeerd. Maak die wijzigingen op de server zelf, of via een ander protocol.
- Bij de eerste verbinding met een SFTP-server wordt gevraagd de hostsleutel te vertrouwen. Peach Commander onthoudt die daarna (vertrouwen bij eerste gebruik).

## Downloaden van een URL

- De opdracht **Downloaden van URL** (Netwerk-menu) gebruikt momenteel de sneltoets Cmd+Shift+D, dezelfde sneltoets als Ga > Bureaublad. Als beide beschikbaar zijn, kunnen de menu's botsen — start de download rechtstreeks vanuit het Netwerk-menu om zeker te zijn.

## Map verversen

- **Een paneel merkt externe wijzigingen met een korte vertraging op, niet meteen.** Peach Commander controleert de huidige map ongeveer elke 2 seconden op wijzigingen, dus een door een andere app toegevoegd of verwijderd bestand kan even duren voordat het verschijnt. Wil je niet wachten, ververs het actieve paneel dan handmatig met F2 of Ctrl+R.

## Overige huidige beperkingen

- **Sommige zeer lange absolute paden** (diep geneste mappen met een ongewoon lang volledig pad) worden mogelijk niet betrouwbaar verwerkt. Dichter bij de top van de mapstructuur werken vermijdt dit.
- **Deze previewversie is niet ondertekend.** macOS Gatekeeper kan de eerste keer waarschuwen dat de app van een niet-geïdentificeerde ontwikkelaar is. Klik met de rechtermuisknop op de app en kies Open, bevestig daarna, om hem uit te voeren. Automatische updates zijn in deze versie nog niet beschikbaar.

## Sneltoetsen

| Actie | Sneltoets |
| --- | --- |
| Actief paneel verversen | F2 of Ctrl+R |
| Downloaden van URL | Cmd+Shift+D |

## Opmerkingen

Dit zijn beperkingen van de huidige versie en zullen naar verwachting in latere releases verbeteren. Kom je gedrag tegen dat hier niet is beschreven, zie dan het onderwerp probleemoplossing.
