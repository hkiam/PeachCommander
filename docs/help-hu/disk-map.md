---
title: Lemeztérkép
slug: disk-map
section: Bővítmények
order: 121
related: [plugins, deleting-files, settings]
---

A Lemeztérkép egy beépített bővítmény, amely egy pillantással megmutatja, mi foglal helyet egy mappában vagy egy egész köteten. Beolvassa a kiválasztott mappát, és minden elemet a lemezen ténylegesen elfoglalt helyével arányos méretben rajzol, így a legnagyobb helyfalók azonnal kiemelkednek. Belemélyedhet a mappákba, láthatja, hogyan egyeztethető a beolvasás a kötet szabad, kiüríthető és rejtett helyével, és takaríthat közvetlenül a térképről.

## Beolvasás indítása

1. Az aktív panelben menjen a mappához (vagy kötethez), amelyet mérni szeretne.
2. Válassza a **Parancsok ▸ Lemeztérkép: Aktuális mappa elemzése** lehetőséget.
3. A Lemeztérkép nézet a jobb oldalon nyílik meg, és a háttérben olvas be, folyamatosan mutatva az elemek és bájtok számát. A nagy mappák néhány másodperc alatt végeznek — a beolvasás tömegesen olvassa a könyvtármetaadatokat, és több processzormagon dolgozik.

![A Lemeztérkép egy mappa fatérképét, egy kötetsávot, egy legnagyobb fájlok listát és egy kategórialegendát mutat](screenshots/disk-map.png)
*(Ábra: a fatérkép nézet, fájlkategória szerint színezve, a kötetsávval felül és a legnagyobb fájlok listával jobbra.)*

## A térkép olvasása

- Minden blokk (fatérkép) vagy gyűrűszegmens (napkitörés) az elem **tényleges lemezen lévő mérete** szerint méretezett, így a kép megegyezik azzal, amit a Finder és a rendszer jelent.
- A blokkok **fájltípus szerint színezettek** — videó, képek, hang, dokumentumok, kód, archívumok, appok, lemezképek — legendával alul. A beállításokban méret szerinti **hőtérképre** válthat.
- **Kattintson egy mappára**, hogy belemélyedjen; a felül lévő morzsaút mutatja, hol van, a **◂** gomb pedig visszalép egy szintet.
- Vigye a mutatót bármely blokk fölé, hogy lássa a teljes útvonalát, méretét és elemszámát.

## Két nézet: fatérkép és napkitörés

A Lemeztérkép két vizualizációt kínál, amelyek között a fejlécben vagy a beállítások oldalon lévő **◎ / ▦** gombbal válthat:

- **Fatérkép** — beágyazott téglalapok, a legsűrűbb az egyetlen legnagyobb fájl felderítéséhez.
- **Napkitörés** — koncentrikus gyűrűk (egy mappamélységenként) az aktuális mappa körül, a legjobb annak megtekintésére, hogyan oszlik el a hely egy mély fában.

![A Lemeztérkép napkitörés nézete koncentrikus gyűrűket mutat a mappamélységhez](screenshots/disk-map-sunburst.png)
*(Ábra: a napkitörés nézet — a belső korong az aktuális mappa, és minden gyűrű egy szinttel mélyebb.)*

## A kötetsáv

A felül lévő sáv egyezteti a beolvasást az egész kötettel:

- **Beolvasott / Ez a mappa** — mennyit foglal el az elemzett mappa.
- **Rejtett** (a kötet gyökerénél) vagy **A kötet többi része** (almappához) — minden, ami nincs ebben a beolvasásban, beleértve a rendszer által védett mappákat, más felhasználókat és pillanatképeket.
- **Kiüríthető** — hely, amelyet a macOS automatikusan visszanyerhet, főleg helyi Time Machine pillanatképek és gyorsítótárak.
- **Szabad** — hely, amely most azonnal elérhető.

Amikor a kötetnek helyi pillanatképei vannak, a sáv egy **· N pillanatkép (ⓘ)** elemet mutat; kattintson rá egy csak olvasható listáért, egy tipppel a Lemezkezelőben vagy a Time Machine-ben való kezelésükhöz. A Lemeztérkép soha nem töröl pillanatképeket magától.

## Legnagyobb fájlok

Kapcsolja be a **Legnagyobb fájlok listájának megjelenítése** lehetőséget, hogy lássa a legnagyobb fájlokat az aktuális mappában méret szerint rangsorolva, mindegyiket a kategóriája színes jelzőjével. Kattintson egyre a térképen való kiemeléséhez.

## Takarítás a térképről

Kattintson jobb gombbal bármely blokkra műveletekért:

- **Megnyitás a bal panelben** / **Megnyitás a jobb panelben** — az elem megjelenítése egy fájlpanelben.
- **Megjelenítés a Finderben**.
- **Áthelyezés a Kukába** — csak azt az elemet törli; a térkép teljes újraolvasás nélkül frissül.

Több elem egyszerre eltávolításához használja a **gyűjtőt**: jobb kattintás ▸ **Megjelölés a gyűjtőnek** minden elemen, majd kattintson a fejlécben lévő **🗑 N** gombra, hogy egy megerősített lépésben a Kukába helyezze mindazt, amit megjelölt.

## Beállítások

A Lemeztérkép saját oldalt ad a Beállítások ablakhoz (**Konfiguráció ▸ Beállítások ▸ Lemeztérkép**):

- **Diagramstílus** — fatérkép vagy napkitörés.
- **Színkódolás** — fájltípus (kategória) vagy méret (hőtérkép) szerint.
- **Maradjon a kiinduló köteten** — ne lépjen át más csatolt lemezekre.
- **Kötetsáv megjelenítése** és **Legnagyobb fájlok listájának megjelenítése**.

A változtatások egy nyitott Lemeztérképre azonnal vonatkoznak.

## Megjegyzések

- A Lemeztérkép a **lefoglalt** (lemezen lévő) méretet méri, és a **kemény hivatkozású** fájlokat csak egyszer számolja, így összegei a kötet használt helyével esnek egybe, ahelyett hogy túlszámolnák.
- Alapértelmezetten a beolvasás a kiinduló köteten marad, így nem kóborol más csatolt lemezekre vagy hálózati megosztásokra.
