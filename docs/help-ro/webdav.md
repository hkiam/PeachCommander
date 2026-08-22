---
title: Servere WebDAV
slug: webdav
section: Pluginuri
order: 130
related: [plugins, ftp-and-sftp, network-shares]
---

Un server WebDAV — Nextcloud, ownCloud, un Synology, depozitul de fișiere al unei universități — poate fi răsfoit într-un panou ca orice dosar. Alegeți **Conectare WebDAV…** din meniul Rețea, dați un URL, iar serverul apare în panoul activ.

Este o extensie: o puteți dezactiva sau elimina din **Configurare ▸ Extensii…**.

## Conectarea

URL-ul este colecția în care vreți să ajungeți, cu numele dumneavoastră de utilizator în fața gazdei:

```
https://anna@files.example.com/remote.php/dav/files/anna/
```

Parola este cerută separat și ajunge în **inelul de chei** prin aplicație, niciodată într-un fișier de configurare. Lăsați-o goală la o conectare ulterioară și se va folosi cea salvată.

Fiecare URL la care vă conectați este reținut — ultimele treizeci, cel mai recent primul — și oferit data următoare în meniul derulant. Acea listă se află în `~/Library/Application Support/PeachCommander/webdav/sites.json` și conține **doar URL-uri**; nicio parolă nu este scrisă vreodată acolo.

## Folosiți https

Autentificarea este HTTP Basic, ceea ce înseamnă că numele de utilizator și parola călătoresc codificate base64 — codificate, nu criptate. Pe `https://` conexiunea le protejează. Pe `http://` sunt practic în clar, iar tot ce se află între dumneavoastră și server le poate citi. Simplul `http://` este acceptat, fiindcă un server pe propria mașină sau într-o rețea de laborator închisă este un caz legitim — o valoare implicită bună însă nu este.

## Ce puteți face

Listarea, citirea, scrierea, crearea de dosare, ștergerea, redenumirea și mutarea funcționează toate — corespund verbelor WebDAV `PROPFIND`, `GET`, `PUT`, `MKCOL`, `DELETE` și `MOVE`. Un panou pe un server WebDAV se comportă deci, pentru munca de zi cu zi, ca un panou pe un disc.

## La ce să vă așteptați

**Transferurile se fac pe fișier întreg.** Un fișier este adus sau trimis dintr-o bucată; nu există transfer pe intervale, așa că un transfer întrerupt al unui fișier mare o ia de la capăt în loc să fie reluat.

**Copierea în interiorul serverului trece prin Macul dumneavoastră.** Extensia nu folosește verbul `COPY`, așa că duplicarea unui fișier pe server îl descarcă și îl încarcă din nou. Pe o linie lentă, mutarea — pe care serverul o face singur — este mult mai rapidă decât copierea.

**Nimic nu este blocat.** `LOCK` din WebDAV nu este folosit, așa că, dacă două persoane scriu același fișier în același timp, decide cine salvează ultimul — exact ca pe o partajare de rețea fără blocare.

**Doar autentificare Basic.** Serverele care cer Digest, un token bearer sau un flux de autentificare unică vor refuza conexiunea. Multe dintre ele oferă în schimb o parolă specifică aplicației, iar aceea funcționează aici.
