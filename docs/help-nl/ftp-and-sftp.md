---
title: Verbinden met FTP en SFTP
slug: ftp-and-sftp
section: Netwerk en op afstand
order: 100
related: [downloading-from-url, network-shares]
---

Peach Commander kan externe servers doorbladeren alsof het gewone mappen zijn. Eenmaal verbonden toont één paneel de externe bestanden en kopieer, verplaats, hernoem en verwijder je ze met dezelfde toetsen als lokaal. Het spreekt gewoon FTP, beveiligd FTPS en SFTP/SCP over SSH, zodat je alles kunt bereiken, van een klassieke webhost tot een gehardende SSH-server. Bewaarde verbindingen staan in de verbindingsbeheerder, en wachtwoorden worden veilig in je macOS-sleutelhanger bewaard in plaats van in de verbinding zelf.

## Verbinding maken met een server

1. Open het menu **Netwerk** en kies **FTP-verbinding…** (Ctrl+F) om de verbindingsbeheerder te openen.
2. Kies een bewaarde verbinding uit de lijst en klik op **Verbind**, of klik op **Nieuw** om er een te maken. Gebruik mappen in de lijst om verbindingen te groeperen.
3. Voor een snelle eenmalige verbinding kies je **Netwerk > Nieuwe FTP-verbinding…** (Ctrl+N) en typ je het adres rechtstreeks.
4. Voer je wachtwoord in wanneer daarom wordt gevraagd; vink de optie aan om het te bewaren en het gaat voor de volgende keer naar je sleutelhanger.
5. Ben je klaar, kies dan **Netwerk > FTP-verbinding verbreken** (Ctrl+Shift+F).

![De FTP-verbindingsbeheerder met de lijst van bewaarde sessies en knoppen Nieuw, Wijzig en Verwijder](screenshots/ftp-connection-manager.png)
*(Afbeelding: De verbindingsbeheerder bewaart je servers; gebruik Nieuw, Wijzig en Verwijder om ze te beheren.)*

Bij het opzetten van een verbinding kun je het protocol kiezen (FTP, FTPS met expliciet AUTH TLS, impliciet FTPS op poort 990, of SFTP/SCP), passieve of actieve modus, de externe en lokale startmappen, tekstcodering en een optioneel keep-alive-interval om te voorkomen dat inactieve servers je afsluiten. Voor SFTP kun je je aanmelden met je SSH-agent, een wachtwoord of een privésleutelbestand, en kun je SCP kiezen voor overdrachten. Onbekende SSH-hostsleutels worden bij eerste gebruik vertrouwd; verandert de sleutel van een bekende server ooit, dan wordt de verbinding geweigerd om je tegen manipulatie te beschermen.

## De FTP-console

Om precies te zien wat de server zegt, open je de FTP-console vanuit het menu **Netwerk**. Hij toont een live logboek van het besturingskanaal (je wachtwoord is gemaskeerd) en laat je ruwe FTP-opdrachten naar de server typen.

![De FTP-console met het logboek van het besturingskanaal en een veld voor ruwe opdrachten](screenshots/ftp-console.png)
*(Afbeelding: De FTP-console logt elke uitwisseling en accepteert ruwe opdrachten, wat handig is bij probleemoplossing.)*

## Sneltoetsen

| Actie | Sneltoets |
| --- | --- |
| Verbindingsbeheerder openen | Ctrl+F |
| Nieuwe verbinding | Ctrl+N |
| Verbinding verbreken | Ctrl+Shift+F |
| Overdrachtsmodus wijzigen | Ctrl+Shift+M |

## Opmerkingen

- Een afgebroken download gaat verder waar hij stopte: staat het bestand er al deels en accepteert de server een herstart, dan reist alleen de ontbrekende staart. Een server die dat weigert, begint het bestand simpelweg opnieuw. Een upload gaat op dezelfde manier verder, wanneer het bestand op de server korter is dan het verzonden bestand.
- Voor FTPS-servers met een zelfondertekend certificaat zet je de optie om een niet-vertrouwd certificaat te accepteren aan in de instellingen van die verbinding.
- Een SOCKS5-proxy kan per verbinding worden ingesteld voor gewoon FTP. Een versleutelde FTPS-verbinding via een proxy leiden wordt niet ondersteund.
- Bestaande FTP-verbindingen uit Total Commander kunnen worden geïmporteerd.
- SCP wordt alleen gebruikt voor het overdragen van bestanden; opsommen, hernoemen en verwijderen gaan altijd via SFTP.
