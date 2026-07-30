---
title: Netwerkshares
slug: network-shares
section: Netwerk en op afstand
order: 104
related: [ftp-and-sftp]
---

Peach Commander kan verbinding maken met bestandsservers op je lokale netwerk of bedrijfsnetwerk — SMB- (Windows/Samba) en AFP-shares — en de inhoud ervan in een paneel tonen, net als een map op je eigen Mac. Zodra een share verbonden is, kun je erin bladeren en bestanden kopiëren, verplaatsen, hernoemen en openen, precies zoals lokaal, inclusief kopiëren tussen de share en je andere paneel.

## Verbinding maken met een server

1. Klik op het paneel dat je wilt verbinden (de verbonden share opent in het actieve paneel).
2. Druk op Cmd+K, of kies **Netwerk > Netwerkomgeving > Netwerkshare koppelen…**.
3. Typ in het venster **Verbind met server** het serveradres. Je kunt invoeren:
   - een SMB-adres, bijvoorbeeld `smb://fileserver/projects`
   - een AFP-adres, bijvoorbeeld `afp://fileserver/projects`
   - een Windows-pad, bijvoorbeeld `\\fileserver\projects`
   - een gewone `server/share`-naam
4. Klik op Verbind (of druk op Return). Als de server een naam en wachtwoord nodig heeft, toont macOS zijn standaard inlogvenster — voer daar je gegevens in.
5. Zodra de share klaar is, opent het actieve paneel deze automatisch. Blader en werk ermee zoals met elke andere map.

## Verbinding verbreken

Een verbonden share verschijnt als een gekoppeld volume op je Mac. Om de verbinding te verbreken, werp je het op de gebruikelijke macOS-manier uit — bijvoorbeeld vanuit de Finder-navigatiekolom of vanuit de schijvenlijst in Peach Commander.

## Sneltoetsen

| Actie | Sneltoets |
| --- | --- |
| Netwerkshare koppelen… | Cmd+K |

## Opmerkingen

- Authenticatie (gebruikersnaam, wachtwoord en de keuze "bewaar in mijn sleutelhanger") wordt afgehandeld door het standaard macOS-inlogvenster, dus opgeslagen serverwachtwoorden werken net als in de Finder.
- Als je een adres invoert dat niet begrepen kan worden, vraagt Peach Commander om een SMB/AFP-adres, een Windows-pad of een `server/share`-naam, en wordt er niets gekoppeld.
- Na je bevestiging kan verbinden even duren terwijl macOS de share koppelt; het paneel schakelt erover zodra deze beschikbaar is.
- Dit maakt verbinding met gedeelde schijven op een netwerk. Zie het gerelateerde onderwerp hieronder om in plaats daarvan een FTP-, FTPS- of SFTP-server te bereiken.
