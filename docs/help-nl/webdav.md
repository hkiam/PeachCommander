---
title: WebDAV-servers
slug: webdav
section: Plug-ins
order: 130
related: [plugins, ftp-and-sftp, network-shares]
---

Een WebDAV-server — Nextcloud, ownCloud, een Synology, de opslag van een universiteit — kunt u in een paneel doorbladeren als elke map. Kies **WebDAV verbinden…** in het menu Netwerk, geef een URL op, en de server verschijnt in het actieve paneel.

Het is een plug-in: u kunt hem uitschakelen of verwijderen via **Configuratie ▸ Plug-ins…**.

## Verbinding maken

De URL is de verzameling waarin u wilt landen, met uw gebruikersnaam vóór de host:

```
https://anna@files.example.com/remote.php/dav/files/anna/
```

Het wachtwoord wordt apart gevraagd en gaat via de app naar de **sleutelhanger**, nooit naar een configuratiebestand. Laat het bij een volgende verbinding leeg en het bewaarde wordt gebruikt.

Elke URL waarmee u verbinding maakt, wordt onthouden — de laatste dertig, de nieuwste eerst — en de volgende keer in het uitklapmenu aangeboden. Die lijst staat in `~/Library/Application Support/PeachCommander/webdav/sites.json` en bevat **alleen URL’s**; er wordt daar nooit een wachtwoord in geschreven.

## Gebruik https

De authenticatie is HTTP Basic, wat betekent dat uw gebruikersnaam en wachtwoord base64-gecodeerd reizen — gecodeerd, niet versleuteld. Via `https://` beschermt de verbinding ze. Via `http://` gaan ze feitelijk onversleuteld, en alles tussen u en de server kan ze meelezen. Kaal `http://` wordt geaccepteerd, want een server op uw eigen machine of in een afgesloten labnetwerk is een legitiem geval — een goede standaard is het niet.

## Wat u kunt doen

Weergeven, lezen, schrijven, mappen aanmaken, verwijderen, hernoemen en verplaatsen werken allemaal — ze komen overeen met de WebDAV-werkwoorden `PROPFIND`, `GET`, `PUT`, `MKCOL`, `DELETE` en `MOVE`. Een paneel op een WebDAV-server gedraagt zich voor het dagelijks werk dus als een paneel op een schijf.

## Wat u kunt verwachten

**Overdrachten gaan per heel bestand.** Een bestand wordt in één stuk opgehaald of verstuurd; er is geen overdracht per bereik, dus een onderbroken overdracht van een groot bestand begint opnieuw in plaats van te hervatten.

**Kopiëren binnen de server gaat via uw Mac.** De plug-in gebruikt het werkwoord `COPY` niet, dus een bestand op de server dupliceren downloadt het en uploadt het weer. Op een trage lijn is verplaatsen — wat de server zelf doet — veel sneller dan kopiëren.

**Er wordt niets vergrendeld.** De `LOCK` van WebDAV wordt niet gebruikt, dus als twee mensen tegelijk hetzelfde bestand schrijven, beslist wie het laatst bewaart — precies als op een netwerkschijf zonder vergrendeling.

**Alleen Basic-authenticatie.** Servers die Digest, een bearer-token of een single-sign-on-stroom eisen, weigeren de verbinding. Veel daarvan bieden in plaats daarvan een app-specifiek wachtwoord, en dat werkt hier wel.
