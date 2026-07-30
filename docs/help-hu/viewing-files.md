---
title: Fájlok megtekintése
slug: viewing-files
section: Megtekintés és szerkesztés
order: 70
related: [editing-files, searching]
---

A Peach Commander beépített megjelenítővel rendelkezik, amely lehetővé teszi, hogy belenézzen egy fájlba anélkül, hogy másik appot nyitna meg vagy megváltoztatná a fájlt. Nyomja meg az F3-at a kurzor alatti elemen, és a megjelenítő azonnal megnyílik, még nagyon nagy fájloknál is. Automatikusan kiválasztja a tartalom megjelenítésének legjobb módját: olvasható szöveg, szintaxisszínezett kód, nyers hexadecimális kiíratás vagy teljes méretű kép. Egy fájlt előnézhet közvetlenül az ablakon belül is a Gyorsnézet segítségével, vagy átadhatja a macOS Quick Looknak.

## Fájl megtekintése

1. Vigye a kurzort egy fájlra az aktív panelben.
2. Nyomja meg az F3-at (vagy válassza a Megtekintés lehetőséget a Fájl menüben). A megjelenítő a saját ablakában nyílik meg.
3. Használja az eszköztárat a tartalom megjelenítési módjának váltásához: Szöveg, Kód, Hex, Kép vagy Renderelt. Hagyja az automatikus beállításon, hogy a Peach Commander döntsön.
4. Görgessen a nyílbillentyűkkel, a Page Up/Page Down-nal és a görgetősávval. Hosszú szövegnél kapcsolja be a minitérkép gombot, hogy egy pillantással lássa és bejárja az egész fájlt.
5. Nyomja meg az N-t a következő kijelölt fájlra ugráshoz, vagy zárja be az ablakot az Esc-cel.

![A beépített megjelenítő egy szövegfájlt mutat a minitérképpel jobbra](screenshots/lister-text.png)
*(Ábra: egy szövegfájl megtekintése, a megjelenítésválasztóval és a minitérképpel az eszköztárban.)*

## Szöveg keresése és a kódolás megváltoztatása

- Nyomja meg a Ctrl+F-et a fájlon belüli kereséshez. Nyomja meg az F3-at a következő találatra ugráshoz, a Shift+F3-at az előzőhöz.
- Ha a szöveg zavarosnak tűnik, kattintson a Kódolás gombra az eszköztárban (vagy nyomja meg az E-t) a szövegkódolások végigjárásához, amíg helyesen nem olvasható; az automatikus beállítás általában eltalálja.
- Nyomja meg a W-t a hosszú sorok sortörésének átkapcsolásához.

## Gyorsnézet és Quick Look

A Gyorsnézet élő előnézetet mutat abban a panelben, amelyet *nem* használ, így folytathatja a böngészést az egyik oldalon, miközben a másikon előnéz.

1. Nyomja meg a Ctrl+Q-t. Az inaktív panel előnézeti területté válik.
2. Vigye a kurzort különböző fájlok fölé az aktív panelben mindegyik előnézetéhez.
3. Nyomja meg a Ctrl+Q-t újra, vagy az Esc-et, hogy a panelt normál fájllistává állítsa vissza.

Egy gyors, magától a macOS által kezelt teljes képernyős előnézethez nyomja meg a Cmd+Y-t (Quick Look). Nyomja meg a Cmd+Y-t vagy a szóközt újra a bezárásához.

## Billentyűparancsok

| Művelet | Billentyűparancs |
| --- | --- |
| Kurzor alatti fájl megtekintése | F3 |
| Csak a kurzor alatti fájl megtekintése (megjelölt fájlok mellőzése) | Shift+F3 |
| Megnyitás külső megjelenítőben | Option+F3 |
| Keresés a megjelenítőben | Ctrl+F |
| Következő / előző találat | F3 / Shift+F3 |
| Gyorsnézet a másik panelben | Ctrl+Q |
| Quick Look (macOS előnézet) | Cmd+Y |
| A megjelenítő vagy a Gyorsnézet bezárása | Esc |

## Megjegyzések

- A megjelenítő csak olvasható. Egy fájl megváltoztatásához használja inkább a szerkesztőt (lásd Fájlok szerkesztése).
- A nagyon nagy fájlok késleltetés nélkül nyílnak meg: a szöveg egy gyors, görgethető nézetet nyit, a hex nézet pedig közvetlenül a lemezről streamel bármilyen méretben.
- Nyomja meg az F3-at egy mappán, hogy a tartalmának összefoglalóját és teljes méretét lássa a fájlbájtok helyett.
- A Renderelt mód formázott tartalmat jelenít meg, például weboldalakat; a hex mód a nyers bájtokat mutatja a karaktereik mellett, ami hasznos bináris fájlok vizsgálatához.
