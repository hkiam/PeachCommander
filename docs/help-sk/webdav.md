---
title: Servery WebDAV
slug: webdav
section: Zásuvné moduly
order: 130
related: [plugins, ftp-and-sftp, network-shares]
---

Server WebDAV — Nextcloud, ownCloud, Synology, univerzitné úložisko — sa dá prechádzať v paneli ako každý priečinok. Zvoľte **Pripojiť WebDAV…** v ponuke Sieť, zadajte URL a server sa objaví v aktívnom paneli.

Je to plugin: môžete ho vypnúť alebo odstrániť v **Konfigurácia ▸ Pluginy…**.

## Pripojenie

URL je kolekcia, v ktorej chcete pristáť, s vaším používateľským menom pred hostiteľom:

```
https://anna@files.example.com/remote.php/dav/files/anna/
```

Na heslo sa pýta zvlášť a putuje cez aplikáciu do **zväzku kľúčov**, nikdy do konfiguračného súboru. Nechajte ho pri ďalšom pripojení prázdne a použije sa uložené.

Každá URL, ku ktorej sa pripojíte, sa zapamätá — posledných tridsať, najnovšia prvá — a nabudúce sa ponúkne v rozbaľovacej ponuke. Tento zoznam leží v `~/Library/Application Support/PeachCommander/webdav/sites.json` a obsahuje **iba URL**; heslo sa tam nikdy nezapisuje.

## Používajte https

Overovanie prebieha cez HTTP Basic, čo znamená, že vaše používateľské meno a heslo cestujú zakódované v base64 — zakódované, nie zašifrované. Cez `https://` ich spojenie chráni. Cez `http://` sú prakticky nechránené a všetko medzi vami a serverom si ich môže prečítať. Obyčajné `http://` sa prijíma, pretože server na vlastnom počítači alebo v uzavretej laboratórnej sieti je legitímny prípad — dobré predvolené nastavenie to však nie je.

## Čo môžete robiť

Výpis, čítanie, zápis, vytváranie priečinkov, mazanie, premenovanie aj presun fungujú — mapujú sa na WebDAV slovesá `PROPFIND`, `GET`, `PUT`, `MKCOL`, `DELETE` a `MOVE`. Panel na serveri WebDAV sa teda pri bežnej práci správa ako panel na disku.

## S čím počítať

**Prenosy prebiehajú po celých súboroch.** Súbor sa stiahne alebo odošle v jednom kuse; prenos po rozsahoch neexistuje, takže prerušený prenos veľkého súboru začne znova, namiesto toho aby nadviazal.

**Kopírovanie vnútri servera ide cez váš Mac.** Plugin nepoužíva sloveso `COPY`, takže duplikovanie súboru na serveri ho stiahne a znova nahrá. Na pomalej linke je presun — ktorý server zvládne sám — oveľa rýchlejší než kopírovanie.

**Nič sa nezamyká.** WebDAV `LOCK` sa nepoužíva, takže ak dvaja ľudia píšu ten istý súbor súčasne, rozhodne ten, kto uloží posledný — presne ako na sieťovom zdieľaní bez zamykania.

**Iba overovanie Basic.** Servery vyžadujúce Digest, bearer token alebo jednotné prihlásenie spojenie odmietnu. Mnohé z nich namiesto toho ponúkajú heslo pre konkrétnu aplikáciu, a to tu funguje.
