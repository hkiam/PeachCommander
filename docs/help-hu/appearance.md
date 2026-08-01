---
title: Megjelenés
slug: appearance
section: Testreszabás
order: 114
related: [settings]
---

A Peach Commander illeszkedhet a Mac többi részének megjelenéséhez, vagy saját stílust ölthet. Követheti a rendszer világos vagy sötét beállítását (vagy kényszeríthet egyet), átszínezheti a fájlpaneleket, típus szerint kiemelheti a fájlokat, valamint úgy állíthatja be a listabetűméretet és a dátumformátumot, hogy a panelek pontosan úgy jelenjenek meg, ahogy Ön szereti.

## Színtéma választása

Egy téma egyetlen lépésben lecseréli a panelek teljes színpalettáját.

1. Nyissa meg a beállítások ablakát a Beállítások > Beállítások… menüponttal, vagy nyomja meg a Cmd+, billentyűt.
2. Válassza a **Színek** oldalt.
3. Válasszon a **Téma** menüből:
   - **Rendszer (alapértelmezett)** — nincs téma. A panelek az alábbi Megjelenés beállítást követik, pontosan úgy, mint eddig. Ez az alapértelmezés.
   - **Világos** / **Sötét** — rögzíti a beépített világos vagy sötét palettát, függetlenül attól, mit tesz a macOS.
   - **Norton Commander** — az eredeti DOS-os fájlkezelő klasszikus kék-ciánkék kinézete, valódi CGA-színekben: kék panelek, ciánkék szöveg, világos ciánkék kurzorsor és sárga a megjelölt fájlokhoz.

A téma saját világos/sötét alapot hoz magával, hogy a lapok, a görgetősávok és a szokásos vezérlők illeszkedjenek hozzá — ezért halvány a **Megjelenés** menü, amíg téma van kiválasztva. Az alábbi egyéni panelszínek továbbra is elsőbbséget élveznek a témával szemben.

![A Peach Commander a Norton Commander palettában](screenshots/theme-norton.png)
*(Ábra: a Norton Commander paletta — az eredeti CGA kék, ciánkék és sárga.)*

A Norton Commander téma az 1986-os eredeti valódi CGA-értékeit használja: `#0000AA` kék, `#00AAAA` ciánkék, `#55FFFF` a kurzorsorhoz, `#FFFF55` a megjelölt fájlokhoz. A kurzorsáv sötét szövegre vált ciánkék alapon, ahogy az eredeti rajzolta, a megjelölt fájlok pedig megtartják a sárgájukat.

![A kurzorsor közelről a Norton palettában](screenshots/theme-norton-cursor-crop.png)
*(Ábra: a kurzorsáv invertál; a megjelölt fájlok sárgák maradnak.)*

![A Színek beállítási oldal a Norton Commander palettában](screenshots/theme-norton-settings.png)
*(Ábra: a program saját ablakai is követik a témát.)*

A témák csak színek. A panelek elrendezése, a keretek és a betűtípusok változatlanok — a Norton Commander nem hozza vissza a kettős vonalú kereteket, sem a DOS raszteres betűtípusát.

## Saját téma írása

A témák egyszerű szövegfájlok, témánként egy, a beállítási mappán belüli `themes` mappában.

1. A **Színek** oldalon kattintson a **Témák mappája…** gombra. A mappa létrejön, ha nem létezik, és amikor először üres, a Peach Commander elhelyez benne egy megjegyzésekkel ellátott `example-norton.ini` fájlt, amely felsorolja az összes beállítható színt.
2. Másolja le a fájlt, adjon neki új nevet, és szerkessze. A fájlnév (a `.ini` nélkül) a téma azonosítója; a `Name` sor jelenik meg a Téma menüben.
3. Mentse el. Nyissa meg újra a **Téma** menüt — a témája ott van a listában. Újraindítás nem szükséges.

Egy minimális téma három sor:

```ini
[Theme]
Name = Midnight
Base = dark

[Colors]
ListBackground = #101020
ListText       = #C0C0D0
```

![A Peach Commander egy felhasználó által írt témában](screenshots/theme-custom.png)
*(Ábra: a témák mappájában lévő fájlból betöltött téma.)*

A `Base` választja ki azt a beépített palettát (`light` vagy `dark`), amely minden fel nem sorolt színt szolgáltat, így csak azt írja le, amit meg akar változtatni. A színek `#RRGGBB` alakúak. A `;` vagy `#` jellel kezdődő sorok megjegyzések.

Ha valami hibás a fájlban, a Peach Commander kihagyja azt az egy sort, és megtartja a téma többi részét — nem utasítja el a fájlt. Az okot a rendszernaplóba írja, amely a Konzolban látható, ha a `[theme]` kifejezésre szűr.

A `light`, `dark`, `norton` és `system` nevek a beépített témákhoz tartoznak; az ilyen nevű fájl kimarad, hogy ne takarhasson el egy mellékelt témát. Ha törli a kiválasztott téma fájlját, a Peach Commander visszatér a **Rendszer (alapértelmezett)** beállításra.
## Világos, sötét vagy rendszer szerinti megjelenés beállítása

1. Nyissa meg a beállítások ablakát a Beállítások > Beállítások… menüponttal, vagy nyomja meg a Cmd+, billentyűt.
2. Válassza a **Színek** oldalt.
3. A **Megjelenés** menüből válasszon egyet az alábbiak közül:
   - **Rendszer (macOS követése)** – automatikusan igazodik a Mac aktuális világos/sötét beállításához.
   - **Világos** – mindig a világos palettát használja.
   - **Sötét** – mindig a sötét palettát használja.

![A Színek beállítási oldal a Megjelenés menüvel és az egyéni panelszín-mezőkkel](screenshots/settings-colors.png)
*(Ábra: A Színek oldal: válasszon megjelenést, és bírálja felül az egyes panelszíneket.)*

## Panelszínek testreszabása

Ugyanezen a **Színek** oldalon, az **Egyéni panelszínek** alatt kapcsolja be a jelölőnégyzetet bármelyik elem mellett, és válasszon színt a mellette lévő mezőből:

- **Szöveg** – a fájl- és mappanevek.
- **Háttér** – a panel háttere.
- **Kijelölt szöveg** – a megjelölt fájlokhoz használt szín.
- **Kurzorkeret** – az aktuális elem körüli körvonal.

Hagyja kikapcsolva a jelölőnégyzetet, hogy megtartsa az adott elem beépített színét. Kattintson az **Alapértékek visszaállítása** gombra, hogy egyszerre törölje az összes felülbírálást.

## Fájlok színezése típus szerint

1. Nyissa meg a Beállítások > Beállítások… menüpontot, és válassza a **Megjelenítés** oldalt.
2. Kattintson a **Fájltípus-színek…** gombra.
3. Adjon hozzá egy szabályt egy névmaszkkal, például `*.zip` vagy `*.txt`, majd válasszon színt a hozzá illő fájlokhoz.
4. Használja a **Szabály hozzáadása** gombot további maszkokhoz; kattintson a **Kész** gombra a mentéshez, vagy a **Mégse** gombra az elvetéshez.

Az illeszkedő fájlok ezután mindkét panelen az Ön által választott színben jelennek meg.

## Betűméret és dátumformátum módosítása

A **Megjelenítés** oldalon a következőket is beállíthatja:

- Válassza ki a panellista **betűméretét** pontban.
- Adjon meg egy **dátumformátum** mintát annak szabályozásához, hogyan jelenjenek meg a módosítási dátumok; hagyja üresen, hogy a Mac területi formátumát használja. A mező alatt élő előnézet jelenik meg, ahogy gépel.
- Kapcsolja be a **Váltakozó sorháttér** lehetőséget a zebracsíkozáshoz, amely megkönnyíti a hosszú listák átfutását.

## Billentyűparancsok

| Művelet | Billentyűparancs |
| --- | --- |
| Beállítások megnyitása | Cmd+, |

## Megjegyzések

- A Megjelenés menü csak addig hat, amíg a téma **Rendszer (alapértelmezett)**; a téma maga határozza meg az alapját.
- A téma a program saját ablakait is színezi. A rendszerablakok — Megnyitás, Mentés, a szín- és betűválasztó, valamint a figyelmeztetések — megtartják szokásos kinézetüket, ahogy a bővítmények által megnyitott ablakok is.
- A Megjelenés beállítás a fájlpaneleket stílusozza. A rendszer párbeszédpaneljei, riasztásai és a szabványos vezérlők mindig a macOS-t követik.
- A beépített fájlmegjelenítő egymáshoz illő világos és sötét szintaxiskiemelő palettákat használ, így a kiemelt kód mindkét megjelenésben olvasható marad.
- Az egyéni színek és fájltípus-szabályok a beállításaival együtt mentődnek, és minden alkalommal újra érvénybe lépnek, amikor megnyitja az alkalmazást.
