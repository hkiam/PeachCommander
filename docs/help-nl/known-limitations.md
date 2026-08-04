---
title: Bekende beperkingen
slug: known-limitations
section: Hulp en probleemoplossing
order: 144
related: [troubleshooting]
---

Peach Commander doet veel, maar een paar functies hebben in de huidige versie eerlijke beperkingen. Die vooraf kennen voorkomt verwarring als iets zich onverwacht gedraagt. Deze pagina somt de huidige beperkingen op en, waar mogelijk, een eenvoudige tijdelijke oplossing.

## Archieven

- **Gesplitste archieven (in meerdere delen) kunnen niet worden geopend.** Standaard-ZIP — inclusief ZIP64, dus meer dan 65.535 items of groter dan 4 GB — en ook TAR en met gzip gecomprimeerde TAR openen direct als map. Een archief dat over meerdere bestanden is verdeeld (`.z01`, `.zip.001`) wordt niet ondersteund: voeg de delen eerst samen of pak het uit met het programma dat het heeft gemaakt.
- **Versleutelde ZIP-archieven** (zowel ouder ZipCrypto als WinZip AES) worden ondersteund om te doorbladeren, maar er wordt om het wachtwoord gevraagd.
- Andere formaten zoals CPIO, ISO, CAB, LZH, XAR en PAX openen via een hulpprogramma in plaats van de ingebouwde lezer.

## Netwerk (SFTP / SCP)

- **Bestandsattributen wijzigen via SFTP heeft in deze versie geen effect.** Je kunt bladeren, downloaden en uploaden via SFTP/SCP, maar verzoeken om rechten, eigendom of tijdstempels op een externe server te wijzigen worden stilzwijgend genegeerd. Maak die wijzigingen op de server zelf, of via een ander protocol.
- Bij de eerste verbinding met een SFTP-server wordt gevraagd de hostsleutel te vertrouwen. Peach Commander onthoudt die daarna (vertrouwen bij eerste gebruik).

## Downloaden van een URL

- De opdracht **Downloaden van URL** (Netwerk-menu) gebruikt momenteel de sneltoets Cmd+Shift+D, dezelfde sneltoets als Ga > Bureaublad. Als beide beschikbaar zijn, kunnen de menu's botsen — start de download rechtstreeks vanuit het Netwerk-menu om zeker te zijn.

## Map verversen

- **Alleen mappen op deze Mac worden op wijzigingen van buiten gecontroleerd.** Een map op deze Mac werkt zichzelf bij zodra een ander programma er een bestand aanmaakt, wijzigt of verwijdert. Een externe locatie (FTP of SFTP) en de binnenkant van een archief worden niet gecontroleerd, omdat die protocollen geen manier bieden om bericht te krijgen — druk daar op F2 of Ctrl+R om opnieuw te lezen.

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
