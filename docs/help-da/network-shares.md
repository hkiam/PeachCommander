---
title: Netværksshares
slug: network-shares
section: Netværk og fjernadgang
order: 104
related: [ftp-and-sftp]
---

Peach Commander kan oprette forbindelse til filservere på dit lokale netværk eller virksomhedsnetværk — SMB- (Windows/Samba) og AFP-shares — og vise deres indhold i et panel præcis som en mappe på din egen Mac. Når et share er forbundet, kan du gennemse, kopiere, flytte, omdøbe og åbne filer i det præcis som lokalt, inklusive at kopiere mellem sharet og dit andet panel.

## Opret forbindelse til en server

1. Klik på det panel, du vil oprette forbindelse til (det forbundne share åbner i det aktive panel).
2. Tryk på Cmd+K, eller vælg **Netværk > Netværkskvarter > Opret forbindelse til netværksshare…**.
3. I dialogen **Opret forbindelse til server** skal du indtaste serveradressen. Du kan angive:
   - en SMB-adresse, for eksempel `smb://fileserver/projects`
   - en AFP-adresse, for eksempel `afp://fileserver/projects`
   - en sti i Windows-stil, for eksempel `\\fileserver\projects`
   - et simpelt `server/share`-navn
4. Klik på Opret forbindelse (eller tryk på Retur). Hvis serveren har brug for navn og adgangskode, viser macOS sit sædvanlige loginvindue — indtast dine oplysninger der.
5. Når sharet er klar, åbner det aktive panel det automatisk. Gennemse og arbejd med det som med enhver anden mappe.

## Afbryd forbindelsen

Et forbundet share vises som et monteret diskområde på din Mac. For at afbryde forbindelsen skal du skubbe det ud på den sædvanlige macOS-måde — for eksempel fra Finder-sidebjælken eller fra enhedslisten i Peach Commander.

## Genveje

| Handling | Genvej |
| --- | --- |
| Opret forbindelse til netværksshare… | Cmd+K |

## Bemærkninger

- Godkendelse (brugernavn, adgangskode og en valgfri "husk i min nøglering"-mulighed) håndteres af det sædvanlige macOS-loginvindue, så gemte serveradgangskoder virker som i Finder.
- Hvis du angiver en adresse, der ikke kan tolkes, beder Peach Commander om en SMB/AFP-adresse, en sti i Windows-stil eller et `server/share`-navn, og intet monteres.
- Efter du bekræfter, kan forbindelsen tage et øjeblik, mens macOS monterer sharet; panelet skifter til det, så snart det bliver tilgængeligt.
- Dette opretter forbindelse til delte enheder på et netværk. For i stedet at nå en FTP-, FTPS- eller SFTP-server, se det relaterede emne nedenfor.
