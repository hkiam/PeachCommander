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

- **Via SFTP kunnen rechten en tijdstempels worden gewijzigd, een eigenaar niet.** Het protocol draagt eigenaar en groep alleen als getallen en kan een gebruikersnaam niet opzoeken, dus een eigenaarswijziging wordt geweigerd in plaats van geraden — net als macOS-bestandsvlaggen, die aan de andere kant niet bestaan. Via gewoon FTP kunnen alleen rechten worden gezet, met de optionele opdracht `SITE CHMOD`; een server die die niet aanbiedt, zegt dat in plaats van succes voor te wenden.
- Bij de eerste verbinding met een SFTP-server wordt gevraagd de hostsleutel te vertrouwen. Peach Commander onthoudt die daarna (vertrouwen bij eerste gebruik).

## Map verversen

- **Alleen mappen op deze Mac worden op wijzigingen van buiten gecontroleerd.** Een map op deze Mac werkt zichzelf bij zodra een ander programma er een bestand aanmaakt, wijzigt of verwijdert. Een externe locatie (FTP of SFTP) en de binnenkant van een archief worden niet gecontroleerd, omdat die protocollen geen manier bieden om bericht te krijgen — druk daar op F2 of Ctrl+R om opnieuw te lezen.

## Overige huidige beperkingen

- **Sommige zeer lange absolute paden** (diep geneste mappen met een ongewoon lang volledig pad) worden mogelijk niet betrouwbaar verwerkt. Dichter bij de top van de mapstructuur werken vermijdt dit.
- **Deze voorvertoningsbuild is niet ondertekend.** Gatekeeper blokkeert de eerste start, en hoe je die toestaat hangt af van je macOS-versie. Op **macOS 15 Sequoia en later**: dubbelklik één keer, sluit de waarschuwing en ga naar **Systeeminstellingen ▸ Privacy en beveiliging** en klik op **Toch openen** — Apple heeft de snelkoppeling via rechtsklikken voor niet-ondertekende software in macOS 15 verwijderd, dus rechtsklikken helpt daar niet meer. Op **macOS 13–14**: klik met de rechtermuisknop op de app en kies Open, bevestig daarna. Automatische updates zijn in deze build nog niet beschikbaar.

## Sneltoetsen

| Actie | Sneltoets |
| --- | --- |
| Actief paneel verversen | F2 of Ctrl+R |
| Downloaden van URL | Cmd+Shift+U |

## Opmerkingen

Dit zijn beperkingen van de huidige versie en zullen naar verwachting in latere releases verbeteren. Kom je gedrag tegen dat hier niet is beschreven, zie dan het onderwerp probleemoplossing.
