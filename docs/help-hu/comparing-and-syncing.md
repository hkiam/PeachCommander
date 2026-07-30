---
title: Összehasonlítás és szinkronizálás
slug: comparing-and-syncing
section: Haladó eszközök
order: 90
related: [multi-rename]
---

Amikor ugyanannak a mappának két másolatát tartja – egy munkamappát és egy biztonsági mentést, egy laptopot és egy hálózati megosztást, egy projektet és annak archívumát –, a Peach Commander segít pontosan látni, mi változott, és összehangolni a két oldalt. Szinkronizálhat két könyvtárat, soronként összehasonlíthat egyes fájlokat, és bájtról bájtra megvizsgálhatja a fájlokat, amikor az utolsó karakterig biztosra van szüksége.

## Két könyvtár szinkronizálása

1. Nyissa meg a szinkronizálni kívánt mappát a bal panelen, az összehasonlítandó mappát pedig a jobb panelen.
2. Válassza a **Parancsok ▸ Könyvtárak szinkronizálása…** menüpontot. A két mappa útvonala a paneljeiből töltődik ki.
3. Állítsa be, mennyire legyen alapos az összehasonlítás: vonja be az almappákat, hasonlítson össze **tartalom szerint** (ne csak dátum és méret alapján), vagy hagyja figyelmen kívül a módosítási dátumot.
4. Adjon hozzá egy szűrőmaszkot (például `*.jpg;*.png`), ha csak bizonyos fájlokat szeretne szinkronizálni.
5. Tekintse át az eredményrácsot. Minden sor egy fájlt mutat a bal oldalon, egy irányjelző nyilat középen, és a hozzá illő fájlt a jobb oldalon. A nyilak megmondják, mi fog történni: a **→** balról jobbra másol, a **←** jobbról balra másol, az **=** pedig azt jelenti, hogy a kettő azonos.
6. Módosítsa az egyes sorokat, ha nem ért egyet egy javasolt iránnyal, majd kattintson a szinkronizálás gombra a változtatások végrehajtásához.

![A könyvtárak szinkronizálása ablak két mappaútvonallal és egy eredményráccsal, amely bal, egyenlő és jobb nyilakkal jeleníti meg a fájlokat](screenshots/sync-dialog.png)
*(Ábra: A Könyvtárak szinkronizálása ablak összehasonlítja mindkét oldalt, és minden fájlhoz javasol egy másolási irányt.)*

## Két fájl összehasonlítása tartalom szerint

1. Jelöljön ki egy-egy fájlt mindegyik panelen (vagy két fájlt ugyanazon a panelen).
2. Válassza a **Fájl ▸ Összehasonlítás tartalom szerint…** menüpontot.
3. A két fájl egymás mellett nyílik meg, kiemelt eltérésekkel. A következő/előző vezérlőkkel ugorhat a megváltozott blokkok között.
4. Ha bekapcsolja a szerkesztési módot, közvetlenül módosíthatja bármelyik fájlt, és mentheti a változtatásait.

![Az összehasonlító ablak két szövegfájlt mutat egymás mellett, kiemelt eltérő sorokkal](screenshots/diff-window.png)
*(Ábra: Két szövegfájl összehasonlítása; a megváltozott sorok mindkét oldalon ki vannak emelve.)*

## Fájlok összehasonlítása bájtról bájtra

Amikor két fájl egyformának tűnik, de bizonyítania kell, hogy valóban azonosak (vagy meg kell találnia azt az egy bájtot, amely eltér), használja a bináris összehasonlítást. Mindkét fájlt egy hexadecimális nézetben mutatja, az egyező nem lévő bájtokat megjelölve, ami ideális letöltések ellenőrzéséhez, kódolt adatok vizsgálatához vagy egy pontos másolat megerősítéséhez.

## Könyvtárlisták összehasonlítása

Ahhoz, hogy egy pillantással észrevegye két megnyitott mappa közötti eltéréseket, válassza a **Kijelölés ▸ Könyvtárak összehasonlítása** menüpontot (Shift+F2). A Peach Commander megjelöli azokat a fájlokat, amelyek eltérnek, vagy amelyek hiányoznak a másik oldalon, így a szokásos másolási, áthelyezési és törlési parancsokkal cselekedhet velük.

## Billentyűparancsok

| Művelet | Billentyűparancs |
| --- | --- |
| Könyvtárlisták összehasonlítása (eltérő fájlok megjelölése) | Shift+F2 |
| Összehasonlítás tartalom szerint | Fájl ▸ Összehasonlítás tartalom szerint… |
| Könyvtárak szinkronizálása | Parancsok ▸ Könyvtárak szinkronizálása… |

## Megjegyzések

- **Tartalom szerint vs. dátum/méret szerint.** A gyors összehasonlítás méret és módosítási dátum alapján párosítja a fájlokat, ami gyors, de megtévesztő lehet, ha azonos fájlok időbélyegei eltérnek. Kapcsolja be a **tartalom szerint** lehetőséget a megbízható eredményért, azon az áron, hogy minden fájlt beolvas.
- **Almappák és szűrők.** A szinkronizálási ablak leereszkedhet az almappákba, és korlátozható egy szűrőmaszkkal, így csak azokat a fájltípusokat szinkronizálhatja, amelyek fontosak Önnek.
- **Ön marad az irányítás alatt.** A szinkronizálás soha nem fut le magától – Ön áttekinti a javasolt irányokat az eredményrácsban, és bármelyiket módosíthatja, mielőtt bármit is másolna.
- **Elődefiníciók.** A gyakran használt szinkronizálási beállítások menthetők és újra felhasználhatók, így nem kell minden alkalommal újra megadnia ugyanazokat a beállításokat.
