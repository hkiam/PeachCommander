---
title: Nettverksressurser
slug: network-shares
section: Nettverk og fjerntilgang
order: 104
related: [ftp-and-sftp]
---

Peach Commander kan koble til filtjenere i det lokale nettverket ditt eller bedriftsnettverket – SMB- (Windows/Samba) og AFP-ressurser – og vise innholdet deres i et panel akkurat som en mappe på din egen Mac. Når en ressurs er koblet til, kan du bla, kopiere, flytte, gi nytt navn og åpne filer i den akkurat som lokalt, inkludert å kopiere mellom ressursen og det andre panelet ditt.

## Koble til en tjener

1. Klikk på panelet du vil koble til (den tilkoblede ressursen åpnes i det aktive panelet).
2. Trykk Cmd+K, eller velg **Nettverk > Nettverksnabolag > Koble til nettverksressurs…**.
3. I dialogen **Koble til tjener**, skriv tjeneradressen. Du kan angi:
   - en SMB-adresse, for eksempel `smb://fileserver/projects`
   - en AFP-adresse, for eksempel `afp://fileserver/projects`
   - en bane i Windows-stil, for eksempel `\\fileserver\projects`
   - et enkelt `tjener/ressurs`-navn
4. Klikk på Koble til (eller trykk Return). Hvis tjeneren trenger navn og passord, viser macOS sitt vanlige innloggingsvindu – skriv inn opplysningene dine der.
5. Når ressursen er klar, åpner det aktive panelet den automatisk. Bla og arbeid med den som med en hvilken som helst annen mappe.

## Koble fra

En tilkoblet ressurs vises som et montert volum på din Mac. For å koble fra den, mater du den ut på vanlig macOS-måte – for eksempel fra Finder-sidepanelet eller fra enhetslisten i Peach Commander.

## Snarveier

| Handling | Snarvei |
| --- | --- |
| Koble til nettverksressurs… | Cmd+K |

## Merknader

- Autentisering (brukernavn, passord og et eventuelt «husk i nøkkelringen min»-valg) håndteres av det vanlige macOS-innloggingsvinduet, så lagrede tjenerpassord fungerer som i Finder.
- Hvis du angir en adresse som ikke kan tolkes, ber Peach Commander deg om en SMB/AFP-adresse, en bane i Windows-stil eller et `tjener/ressurs`-navn, og ingenting monteres.
- Etter at du bekrefter, kan tilkoblingen ta et øyeblikk mens macOS monterer ressursen; panelet bytter til den så snart den blir tilgjengelig.
- Dette kobler til delte enheter i et nettverk. For å nå en FTP-, FTPS- eller SFTP-tjener i stedet, se det relaterte emnet nedenfor.
