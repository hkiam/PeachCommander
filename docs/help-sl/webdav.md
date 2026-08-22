---
title: Strežniki WebDAV
slug: webdav
section: Vtičniki
order: 130
related: [plugins, ftp-and-sftp, network-shares]
---

Strežnik WebDAV — Nextcloud, ownCloud, Synology, univerzitetna shramba — lahko prebrskate v plošči kot vsako mapo. Izberite **Povezava WebDAV…** v meniju Omrežje, navedite naslov URL in strežnik se pojavi v dejavni plošči.

To je vtičnik: izklopite ali odstranite ga lahko v **Konfiguracija ▸ Vtičniki…**.

## Povezovanje

URL je zbirka, v kateri želite pristati, z vašim uporabniškim imenom pred gostiteljem:

```
https://anna@files.example.com/remote.php/dav/files/anna/
```

Za geslo vpraša posebej in gre prek aplikacije v **verigo ključev**, nikoli v nastavitveno datoteko. Pustite ga prazno ob poznejši povezavi in uporabljeno bo shranjeno.

Vsak URL, s katerim se povežete, si zapomni — zadnjih trideset, najnovejši prvi — in ga naslednjič ponudi v spustnem meniju. Ta seznam je v `~/Library/Application Support/PeachCommander/webdav/sites.json` in vsebuje **samo naslove URL**; geslo se tja nikoli ne zapiše.

## Uporabljajte https

Overjanje poteka s HTTP Basic, kar pomeni, da vaše uporabniško ime in geslo potujeta kodirana z base64 — kodirana, ne šifrirana. Prek `https://` ju povezava zaščiti. Prek `http://` sta praktično nezaščitena in vse med vami in strežnikom ju lahko prebere. Golo `http://` je sprejeto, ker je strežnik na lastnem računalniku ali v zaprtem laboratorijskem omrežju upravičen primer — dobra privzeta izbira pa ni.

## Kaj lahko počnete

Izpis, branje, pisanje, ustvarjanje map, brisanje, preimenovanje in premikanje delujejo vsi — preslikajo se na glagole WebDAV `PROPFIND`, `GET`, `PUT`, `MKCOL`, `DELETE` in `MOVE`. Plošča na strežniku WebDAV se torej pri vsakdanjem delu vede kot plošča na disku.

## Kaj pričakovati

**Prenosi zajamejo celotno datoteko.** Datoteka se pridobi ali pošlje v enem kosu; prenosa po obsegih ni, zato se prekinjen prenos velike datoteke začne znova, namesto da bi se nadaljeval.

**Kopiranje znotraj strežnika gre prek vašega Maca.** Vtičnik ne uporablja glagola `COPY`, zato podvajanje datoteke na strežniku to datoteko prenese k vam in znova nazaj. Na počasni povezavi je premikanje — ki ga strežnik opravi sam — precej hitrejše od kopiranja.

**Nič ni zaklenjeno.** WebDAV-jev `LOCK` ni v uporabi, zato če dva hkrati pišeta isto datoteko, odloči tisti, ki shrani zadnji — natanko kot na omrežni mapi brez zaklepanja.

**Samo overjanje Basic.** Strežniki, ki zahtevajo Digest, žeton bearer ali enotno prijavo, povezavo zavrnejo. Mnogi od njih namesto tega ponujajo geslo za posamezno aplikacijo, in to tu deluje.
