---
title: WebDAV-servere
slug: webdav
section: Plugins
order: 130
related: [plugins, ftp-and-sftp, network-shares]
---

En WebDAV-server — Nextcloud, ownCloud, en Synology, et universitets fillager — kan gennemses i et panel som enhver anden mappe. Vælg **Forbind via WebDAV…** i menuen Netværk, angiv en URL, og serveren dukker op i det aktive panel.

Det er et plugin: du kan slå det fra eller fjerne det under **Konfiguration ▸ Plugins…**.

## At forbinde

URL’en er den samling, du vil lande i, med dit brugernavn foran værten:

```
https://anna@files.example.com/remote.php/dav/files/anna/
```

Der spørges særskilt om adgangskoden, og den havner i **nøgleringen** via appen, aldrig i en konfigurationsfil. Lad den stå tom ved en senere forbindelse, så bruges den gemte.

Hver URL, du forbinder til, huskes — de seneste tredive, den nyeste først — og tilbydes næste gang i lokalmenuen. Den liste ligger i `~/Library/Application Support/PeachCommander/webdav/sites.json` og indeholder **kun URL’er**; der skrives aldrig en adgangskode dertil.

## Brug https

Godkendelsen er HTTP Basic, hvilket betyder, at dit brugernavn og din adgangskode rejser base64-kodet — kodet, ikke krypteret. Over `https://` beskytter forbindelsen dem. Over `http://` ligger de reelt i klartekst, og alt mellem dig og serveren kan læse dem. Rent `http://` accepteres, fordi en server på din egen maskine eller på et lukket labnetværk er et legitimt tilfælde — nogen god standard er det ikke.

## Hvad du kan

At vise, læse, skrive, oprette mapper, slette, omdøbe og flytte virker alt sammen — det svarer til WebDAV-verberne `PROPFIND`, `GET`, `PUT`, `MKCOL`, `DELETE` og `MOVE`. Et panel på en WebDAV-server opfører sig altså i det daglige som et panel på en disk.

## Hvad du kan forvente

**Overførsler går på hele filen.** En fil hentes eller sendes i ét stykke; der er ingen intervaloverførsel, så en afbrudt overførsel af en stor fil begynder forfra i stedet for at fortsætte.

**At kopiere inde på serveren går gennem din Mac.** Pluginet bruger ikke verbet `COPY`, så at duplikere en fil på serveren henter den ned og sender den op igen. På en langsom forbindelse er det meget hurtigere at flytte — hvilket serveren selv klarer — end at kopiere.

**Intet låses.** WebDAVs `LOCK` bruges ikke, så hvis to personer skriver den samme fil samtidig, afgør den, der arkiverer sidst — præcis som på en netværksdeling uden låsning.

**Kun Basic-godkendelse.** Servere, der kræver Digest, et bearer-token eller et single sign-on-forløb, afviser forbindelsen. Mange af dem tilbyder i stedet en app-specifik adgangskode, og den virker her.
