---
title: WebDAV-kiszolgálók
slug: webdav
section: Plugins
order: 130
related: [plugins, ftp-and-sftp, network-shares]
---

Egy WebDAV-kiszolgáló — Nextcloud, ownCloud, egy Synology, egy egyetemi fájltár — ugyanúgy böngészhető egy panelben, mint bármelyik mappa. Válassza a **WebDAV-csatlakozás…** lehetőséget a Hálózat menüből, adjon meg egy URL-t, és a kiszolgáló megjelenik az aktív panelben.

Bővítmény: kikapcsolhatja vagy eltávolíthatja a **Konfiguráció ▸ Bővítmények…** alatt.

## Csatlakozás

Az URL az a gyűjtemény, ahová érkezni szeretne, a felhasználónevével a gazdagép előtt:

```
https://anna@files.example.com/remote.php/dav/files/anna/
```

A jelszót külön kéri a program, és az alkalmazáson keresztül a **kulcskarikára** kerül, soha nem konfigurációs fájlba. Hagyja üresen egy későbbi csatlakozáskor, és a mentett jelszó lesz használatban.

Minden URL, amelyhez csatlakozik, megjegyzésre kerül — az utolsó harminc, a legfrissebb elöl —, és legközelebb a lenyíló menüben felkínálja. Ez a lista a `~/Library/Application Support/PeachCommander/webdav/sites.json` fájlban van, és **kizárólag URL-eket** tartalmaz; jelszó soha nem kerül oda.

## Használjon https-t

A hitelesítés HTTP Basic, ami azt jelenti, hogy a felhasználóneve és a jelszava base64-kódolva utazik — kódolva, nem titkosítva. `https://` felett a kapcsolat megvédi őket. `http://` felett gyakorlatilag nyíltan mennek, és bármi, ami ön és a kiszolgáló között van, elolvashatja őket. A puszta `http://` elfogadott, mert egy saját gépen vagy zárt laborhálózaton futó kiszolgáló jogos eset — jó alapértelmezés viszont nem.

## Mit tehet

A listázás, olvasás, írás, mappalétrehozás, törlés, átnevezés és áthelyezés mind működik — a WebDAV `PROPFIND`, `GET`, `PUT`, `MKCOL`, `DELETE` és `MOVE` igéinek felelnek meg. Egy WebDAV-kiszolgálón lévő panel tehát a mindennapi munkában úgy viselkedik, mint egy lemezen lévő panel.

## Mire számítson

**Az átvitel teljes fájlra vonatkozik.** A fájl egy darabban jön le vagy megy fel; tartományos átvitel nincs, így egy nagy fájl megszakadt átvitele elölről kezdődik, nem folytatódik.

**A kiszolgálón belüli másolás az ön Macén keresztül megy.** A bővítmény nem használja a `COPY` igét, így egy fájl kiszolgálón való megkettőzése letölti és újra feltölti azt. Lassú vonalon az áthelyezés — amit a kiszolgáló maga végez el — sokkal gyorsabb a másolásnál.

**Semmi sincs zárolva.** A WebDAV `LOCK` nincs használatban, így ha ketten egyszerre írják ugyanazt a fájlt, az dönt, aki utoljára ment — pontosan úgy, mint egy zárolás nélküli hálózati megosztáson.

**Csak Basic hitelesítés.** Azok a kiszolgálók, amelyek Digestet, bearer tokent vagy egyszeri bejelentkezési folyamatot kívánnak, elutasítják a kapcsolatot. Sokuk ehelyett alkalmazásspecifikus jelszót kínál, és az itt működik.
