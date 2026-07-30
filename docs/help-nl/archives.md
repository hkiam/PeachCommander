---
title: Werken met archieven
slug: archives
section: Archieven
order: 80
related: [copying-files]
---

Peach Commander behandelt archieven als mappen. Je kunt een ZIP, TAR of ander ondersteund archief binnengaan, de inhoud doorbladeren en er bestanden uit kopiëren — allemaal zonder eerst naar schijf uit te pakken. Wil je een archief maken, dan bundelt de opdracht Inpakken je selectie in een ZIP, 7z, TAR of ander formaat, met optionele versleuteling en gesplitste volumes. Dit is handig om bestanden te bundelen om te versturen, een map te verkleinen voor opslag, of even in een download te kijken voordat je besluit uit te pakken.

## Een archief als map doorbladeren

1. Zet in een paneel de cursor op een archiefbestand (bijvoorbeeld een `.zip` of `.tar.gz`).
2. Druk op Return of Ctrl+PageDown om het binnen te gaan, net zoals je een map opent.
3. Blader normaal door de inhoud. Druk op Backspace of Ctrl+PageUp om terug omhoog te gaan en het archief te verlaten.
4. Om bestanden eruit te halen, selecteer je ze en kopieer je (F5) naar het andere paneel.

![In een archief bladeren alsof het een map is](screenshots/archive-browse.png)
*(Afbeelding: Een geopend archief getoond als een gewone maplijst, met de bestanden klaar om eruit te kopiëren.)*

ZIP, TAR en met gzip gecomprimeerde TAR worden rechtstreeks gelezen. Andere formaten zoals CPIO, ISO, CAB, LZH, XAR en PAX worden via ingebouwde systeemhulpmiddelen gelezen. Versleutelde ZIP-archieven (zowel klassiek als AES) kunnen worden geopend zodra je het wachtwoord opgeeft.

## Bestanden in een nieuw archief inpakken

1. Selecteer in het actieve paneel de bestanden en mappen die je wilt opnemen.
2. Kies Bestand ▸ Inpakken… of druk op Alt+F5. (Om in te pakken en daarna de originelen te verwijderen, gebruik je Alt+Shift+F5.)
3. Kies in het venster het archiefformaat (ZIP, 7z, TAR, tar.gz, bzip2, xz of RAR), het compressieniveau en waar het wordt bewaard.
4. Zet eventueel AES-256-versleuteling aan en stel een wachtwoord in, of splits het archief in volumes van vaste grootte.
5. Bevestig om het archief te maken.

![Het venster Inpakken met opties voor formaat, compressie, versleuteling en splitsen](screenshots/pack-dialog.png)
*(Afbeelding: Het venster Inpakken, waar je het formaat kiest en versleuteling en gesplitste volumes instelt.)*

## Een archief uitpakken of testen

1. Zet het archief dat je wilt uitpakken in het actieve paneel en de bestemmingsmap in het andere paneel.
2. Kies Bestand ▸ Uitpakken… of druk op Alt+F9, en bevestig de bestemming.
3. Om een archief op schade te controleren zonder uit te pakken, kies je Bestand ▸ Archief testen.

## Een ZIP ter plekke bewerken

Je kunt bestanden in een bestaande ZIP toevoegen of verwijderen zonder hem uit te pakken. Open de ZIP als een map, en kopieer er dan bestanden in of verwijder bestanden zoals gebruikelijk — de wijziging wordt direct terug naar het archief geschreven.

## Sneltoetsen

| Actie | Sneltoets |
| --- | --- |
| Archief onder cursor binnengaan | Return of Ctrl+PageDown |
| Archief verlaten (omhoog) | Backspace of Ctrl+PageUp |
| Inpakken | Alt+F5 |
| Inpakken en originelen verwijderen | Alt+Shift+F5 |
| Uitpakken | Alt+F9 |

## Opmerkingen

- Inpakken naar 7z, xz, bzip2 en RAR steunt op externe hulpmiddelen. RAR vereist met name dat het gesloten RAR-programma is geïnstalleerd; zonder dat is dat formaat niet beschikbaar.
- Een ZIP ter plekke bewerken herschrijft het hele archief, dus de wijzigingstijdstempels van bestanden erin blijven niet behouden.
- Zeer grote afzonderlijke leden worden bij uitpakken begrensd op 512 MiB. Uitpakken kan tijdens het uitvoeren worden geannuleerd.
- Extreem grote (ZIP64) archieven worden niet ondersteund.
