---
title: Nätverksresurser
slug: network-shares
section: Nätverk och fjärr
order: 104
related: [ftp-and-sftp]
---

Peach Commander kan ansluta till filservrar i ditt lokala nätverk eller företagsnätverk — SMB- (Windows/Samba) och AFP-resurser — och visa deras innehåll i en panel precis som en mapp på din egen Mac. När en resurs är ansluten kan du bläddra, kopiera, flytta, byta namn på och öppna filer i den precis som lokalt, inklusive att kopiera mellan resursen och din andra panel.

## Anslut till en server

1. Klicka på den panel du vill ansluta (den anslutna resursen öppnas i den aktiva panelen).
2. Tryck på Cmd+K, eller välj **Nätverk > Nätverksomgivning > Montera nätverksresurs…**.
3. Skriv serveradressen i dialogrutan **Anslut till server**. Du kan ange:
   - en SMB-adress, till exempel `smb://fileserver/projects`
   - en AFP-adress, till exempel `afp://fileserver/projects`
   - en sökväg i Windows-stil, till exempel `\\fileserver\projects`
   - ett enkelt `server/resurs`-namn
4. Klicka på Anslut (eller tryck på Return). Om servern kräver namn och lösenord visar macOS sin vanliga inloggningsruta — ange dina uppgifter där.
5. När resursen är klar öppnar den aktiva panelen den automatiskt. Bläddra och arbeta med den som med vilken annan mapp som helst.

## Koppla från

En ansluten resurs visas som en monterad volym på din Mac. För att koppla från den matar du ut den på vanligt macOS-sätt — till exempel från Finders sidofält eller från enhetslistan i Peach Commander.

## Kortkommandon

| Åtgärd | Kortkommando |
| --- | --- |
| Montera nätverksresurs… | Cmd+K |

## Anmärkningar

- Autentisering (användarnamn, lösenord och valet "spara i min nyckelring") hanteras av den vanliga macOS-inloggningsrutan, så sparade serverlösenord fungerar som i Finder.
- Om du anger en adress som inte kan tolkas ber Peach Commander dig om en SMB/AFP-adress, en sökväg i Windows-stil eller ett `server/resurs`-namn, och inget monteras.
- Efter din bekräftelse kan anslutningen ta en stund medan macOS monterar resursen; panelen växlar till den så snart den blir tillgänglig.
- Detta ansluter till delade enheter i ett nätverk. Se det relaterade ämnet nedan för att i stället nå en FTP-, FTPS- eller SFTP-server.
