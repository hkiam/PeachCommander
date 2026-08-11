---
title: WebDAV-tjenere
slug: webdav
section: Plugins
order: 130
related: [plugins, ftp-and-sftp, network-shares]
---

En WebDAV-tjener — Nextcloud, ownCloud, en Synology, et universitets fillager — kan bla gjennom i et panel som enhver annen mappe. Velg **Koble til WebDAV…** i menyen Nettverk, oppgi en URL, så dukker tjeneren opp i det aktive panelet.

Det er et programtillegg: du kan slå det av eller fjerne det under **Konfigurasjon ▸ Programtillegg…**.

## Å koble til

URL-en er samlingen du vil lande i, med brukernavnet ditt foran verten:

```
https://anna@files.example.com/remote.php/dav/files/anna/
```

Passordet spørres om separat og havner i **nøkkelringen** via appen, aldri i en oppsettsfil. La det stå tomt ved en senere tilkobling, så brukes det lagrede.

Hver URL du kobler til, huskes — de siste tretti, den nyeste først — og tilbys neste gang i lokalmenyen. Den listen ligger i `~/Library/Application Support/PeachCommander/webdav/sites.json` og inneholder **bare URL-er**; et passord skrives aldri dit.

## Bruk https

Autentiseringen er HTTP Basic, som betyr at brukernavnet og passordet ditt reiser base64-kodet — kodet, ikke kryptert. Over `https://` beskytter forbindelsen dem. Over `http://` ligger de i praksis i klartekst, og alt mellom deg og tjeneren kan lese dem. Rent `http://` godtas, fordi en tjener på din egen maskin eller på et lukket labnett er et legitimt tilfelle — noe godt standardvalg er det ikke.

## Hva du kan gjøre

Å liste, lese, skrive, opprette mapper, slette, gi nytt navn og flytte fungerer alt sammen — det svarer til WebDAV-verbene `PROPFIND`, `GET`, `PUT`, `MKCOL`, `DELETE` og `MOVE`. Et panel på en WebDAV-tjener oppfører seg altså i det daglige som et panel på en disk.

## Hva du kan vente deg

**Overføringer gjelder hele filen.** En fil hentes eller sendes i ett stykke; det finnes ingen intervalloverføring, så en avbrutt overføring av en stor fil begynner på nytt i stedet for å fortsette.

**Å kopiere inne på tjeneren går via Macen din.** Programtillegget bruker ikke verbet `COPY`, så å duplisere en fil på tjeneren laster den ned og opp igjen. På en treg linje er det mye raskere å flytte — noe tjeneren gjør selv — enn å kopiere.

**Ingenting låses.** WebDAVs `LOCK` brukes ikke, så hvis to personer skriver den samme filen samtidig, avgjør den som arkiverer sist — akkurat som på en nettverksressurs uten låsing.

**Bare Basic-autentisering.** Tjenere som krever Digest, et bearer-token eller en enkeltpålogging, avviser tilkoblingen. Mange av dem tilbyr i stedet et appspesifikt passord, og det fungerer her.
