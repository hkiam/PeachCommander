---
title: Fájlok és mappák megnyitása
slug: opening-files
section: Fájlok és mappák
order: 20
related: [viewing-files, selecting-files]
---

A Peach Commander bármelyik panelből közvetlenül megnyitja a fájlokat és mappákat, ugyanazokat az appokat és rendszerfunkciókat használva, amelyekre a Finderben már támaszkodik. Nyomjon meg egy billentyűt a kurzor alatti elem alapértelmezett appjában való megnyitásához, vagy kattintson jobb gombbal a műveletek teljes menüjének eléréséhez — megnyitás másik appal, az elem megjelenítése a Finderben, megosztás vagy Terminál-ablak megnyitása pontosan ott, ahol áll.

## Elem megnyitása

1. Kattintson egy fájlra vagy mappára egy panelben, hogy ráhelyezze a kurzort (a kiemelt sor).
2. Nyomja meg az Entert (vagy kattintson duplán).
   - Egy mappa ugyanabban a panelben nyílik meg.
   - Egy fájl az alapértelmezett macOS-appjában nyílik meg — ugyanabban az appban, amit a Finder használna.
   - Egy archívum (például egy .zip) mappaként nyílik meg, hogy böngészhessen benne.

![A Peach Commander főablaka mindkét panellel, amelyek fájlokat és mappákat mutatnak](screenshots/main-window.png)
*(Ábra: helyezze a kurzort bármely elemre, majd nyomja meg az Entert a megnyitásához.)*

## Megnyitás másik appal, megjelenítés vagy megosztás

Kattintson jobb gombbal egy fájlra (vagy nyomja meg a Shift+F10-et) az elem menüjének megnyitásához, majd válasszon:

- **Megnyitás** vagy **Megnyitás az alapértelmezett appban** — nyissa meg a fájlt, ahogy az Enter tenné.
- **Megnyitás ezzel** — válasszon bármely telepített appot, amely meg tudja nyitni ezt a fájlt, vagy válassza a **Más…** lehetőséget egy megkereséséhez.
- **Quick Look** — a fájl előnézete app megnyitása nélkül.
- **Megjelenítés a Finderben** — a fájl megjelenítése kijelölve egy Finder-ablakban.
- **Megosztás…** — a fájl elküldése a macOS Megosztás lapján keresztül.

A menü egyesíti a standard macOS **Szolgáltatások**-at is a kijelölt fájlhoz, és hozzáadja a **Címkék** lehetőséget, hogy alkalmazhassa a szokásos Finder színcímkéket.

## Terminál megnyitása az aktuális mappában

Válassza a **Terminál megnyitása itt** lehetőséget a Fájl vagy Parancsok menüből (Cmd+Option+T) egy olyan Terminál-ablak megnyitásához, amely már az aktív panel mappájára mutat.

## Billentyűparancsok

| Művelet | Billentyű |
|---|---|
| Kurzor alatti elem megnyitása | Enter |
| Fájl megtekintése (megjelenítő) | F3 |
| Fájl szerkesztése | F4 |
| Quick Look előnézet | Cmd+Y |
| Info / tulajdonságok | Option+Enter |
| Elem menüjének megnyitása | Shift+F10 vagy jobb kattintás |
| Terminál megnyitása itt | Cmd+Option+T |

## Megjegyzések

- Az „alapértelmezett app" azt az appot jelenti, amelyet a macOS az adott fájltípushoz használni van beállítva; módosítsa a fájl Info paneljében, pontosan úgy, mint a Finderben.
- A **Megjelenítés a Finderben**, **Megosztás…** és **Megnyitás ezzel ▸ Más…** a Mac lemezén lévő elemekre vonatkozik. Nem elérhetők archívumon belüli vagy távoli (FTP/SFTP) kapcsolaton lévő elemekhez.
- Egy futó folyamatra való jobb kattintás (egy folyamatnézetben) egy rövidebb, folyamatspecifikus menüt mutat a fájlműveletek helyett.
