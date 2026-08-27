---
title: Beállítások
slug: settings
section: Testreszabás
order: 116
related: [appearance, keyboard-shortcuts]
---

A Beállítások ablak az a hely, ahol a Peach Commandert a munkamódjához igazítja: mely sávok jelennek meg, hogyan jelennek meg a fájlok, hogyan viselkednek a másolási és törlési műveletek, a tömörítéskor használt archívumformátum, a lapok viselkedése, az FTP-alapértékek, a megjelenítési nyelv és több. A beállítások oldalakba vannak csoportosítva, így gyorsan megtalálhat egy lehetőséget, és minden változtatás automatikusan mentődik a személyes konfigurációs mappájába.

## A Beállítások megnyitása

1. Válassza a **Peach Commander > Beállítások…** lehetőséget, vagy nyomja meg a Cmd+, (vessző) billentyűt.
2. Ugyanezt az ablakot a **Konfiguráció > Lehetőségek…** alól is megnyithatja.
3. Válasszon egy oldalt a bal oldali listából; az adott oldal lehetőségei a jobb oldalon jelennek meg.
4. Állítsa be a vezérlőket. A változtatások azonnal életbe lépnek, hacsak egy megjegyzés az oldalon mást nem mond.
5. Ha közvetlenül egy beállításhoz szeretne jutni, írjon az ablak felső részén lévő keresőmezőbe. Az *összes* lap találatai megjelennek azzal a lappal együtt, amelyen vannak, és a kiválasztás megnyitja azt a lapot a kijelölt beállítással. ↑/↓ lépteti az eredményeket, a Return megnyitja a kijelöltet, az Esc pedig kilép a keresésből és visszaadja azt a lapot, ahonnan jött.

![A Beállítások ablak az Elrendezés oldalt mutatja jelölőnégyzetekkel a felület sávjaihoz](screenshots/settings-layout.png)
*(Ábra: az Elrendezés oldal vezérli, mely sávok jelennek meg a panelek körül.)*

## Az oldalak

Az ablaknak ezek az oldalai vannak, sorrendben:

- **Elrendezés** — a meghajtósáv, lapsáv, útvonalsáv és állapotsáv megjelenítése vagy elrejtése, valamint annak megválasztása, milyen oldalakat kínál az oldalsó panel.
- **Megjelenítés** — hogyan listázódnak a fájlok és mappák, beleértve a dátumformátumot.
- **Ikonok** — az ikonok megjelenése a fájllistákban.
- **Működés** — általános viselkedés, például mi történik, amikor gépel egy panelben (gyorskeresés vs. parancssor).
- **Színek** — egyéni panelszínek, vagy hagyja őket az aktuális témát követni.
- **Megerősítés** — mely műveletek kérnek először megerősítést, mint a törlés.
- **Szerkesztés/Megtekintés** — hogy a szerkesztőben való mentés megtart-e `.bak` biztonsági másolatot, a fájlok szerkesztéséhez és megtekintéséhez használt programok és a típusonkénti társítások.
- **Másolás/Törlés** — fájlmetaadatok megőrzése, gyors klónozás használata, csak újabb fájlok másolása, ellenőrzés másolás után, törlések küldése a Kukába, és egy opcionális sebességkorlát beállítása.
- **Zip/Tömörítő** — az alapértelmezett archívumformátum és tömörítési szint, amelyet tömörítéskor használ.
- **Bővítmények** — a telepített bővítmények be- vagy kikapcsolása.
- **Lapok** — hogyan nyílnak meg és viselkednek a mappalapok.
- **FTP** — hálózati alapértékek, mint a keep-alive időköz.
- **Billentyűzet** — a billentyűparancsok áttekintése és módosítása.
- **Nyelv** — válasszon Rendszer alapértelmezett, English vagy Deutsch közül.
- **MI** — az MI-asszisztens beállítása: preferált modell, felhő végpont és kulcs, autonómia, és az opcionális MCP-kiszolgáló (lásd [Asszisztens MI](ai-assistant.md)).
- **Egyéb** — a konfigurációs mappa megnyitása a Finderben.

Az engedélyezett bővítmények saját oldalakat adhatnak a beépítettek után — például **Lemeztérkép** és **System Monitor** — így a lehetőségeik ugyanabban az ablakban élnek (lásd [Bővítmények](plugins.md)).

![A Beállítások ablak a Megjelenítés oldal lehetőségeit mutatja a fájlok listázásához](screenshots/settings-display.png)
*(Ábra: a Megjelenítés oldal vezérli, hogyan listázódnak a fájlok és mappák.)*

![A Beállítások ablak a Működés oldalt mutatja](screenshots/settings-operation.png)
*(Ábra: a Működés oldal irányítja a gyorskeresést és az egér viselkedését.)*

## Hol tárolódnak a beállításai

A konfigurációja egyszerű szövegfájlokban tárolódik a személyes Application Support mappáján belül, a `~/Library/Application Support/PeachCommander` alatt. A megnyitásához menjen az **Egyéb** oldalra és kattintson a **Konfigurációs mappa megnyitása** gombra. A mentett FTP-jelszavak nem ezekben a fájlokban tárolódnak; biztonságosan a macOS kulcskarikában vannak.

A beállítások írásra kerülnek, ahogy megváltoztatja őket. Bármikor kikényszeríthet egy mentést is a **Konfiguráció > Beállítások mentése** lehetőséggel, és tárolhatja az aktuális ablakhelyzetet és panelelrendezést a **Konfiguráció > Pozíció mentése** lehetőséggel.

## Beállítások áthozatala a Total Commanderből

Ha a Windows-os Total Commanderről vált, importálhatja a mentett FTP-oldalait. Válassza a **Konfiguráció > wincmd.ini importálása…** lehetőséget és válassza ki a Total Commander FTP-konfigurációs fájlját. A kapcsolatai ugyanabban a sorrendben adódnak hozzá a Peach Commanderhez, ahogy ott megjelentek.

## Billentyűparancsok

| Művelet | Billentyűparancs |
| --- | --- |
| A Beállítások megnyitása | Cmd+, |

## Megjegyzések

- A **Nyelv** oldal Rendszer alapértelmezett, English és Deutsch közül kínál. A nyelv megváltoztatása csak a Peach Commander újraindítása után lép életbe.
- A **Színek** oldalon beállított színek felülírják a témát; ott használja az **Alapértelmezések visszaállítása**-t a téma színeihez való visszatéréshez.
- A Peach Commander a beállításait csak a saját konfigurációs mappájában tárolja, így a változtatásai soha nem érintenek más appokat, és könnyen biztonsági mentés készíthető róluk a mappa másolásával.
