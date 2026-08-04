---
title: Nézetmódok és rendezés
slug: view-modes-and-sorting
section: A nézet rendezése
order: 42
related: [panels-and-tabs, quick-search-and-filter]
---

Minden panel megjelenítheti a mappáját a feladathoz illő elrendezésben: részletes lista oszlopokkal, tömör többoszlopos névlista, ikonrács, galéria nagy indexképekkel, vagy mappafa. Rendezheti a listát név, fájltípus, méret vagy dátum szerint, kiválaszthatja pontosan, mely oszlopok jelenjenek meg, és bekapcsolhatja a természetes (numerikus) rendezést, hogy a számokat tartalmazó nevek úgy sorakozzanak, ahogy várja. A nézetmód, a rendezési sorrend és az oszlopok panelenként állíthatók be, így a két oldal teljesen másképp nézhet ki.

## Nézetmód váltása

1. Kattintson arra a panelre, amelyet módosítani szeretne, hogy aktívvá váljon.
2. Nyissa meg a Nézet menüt és válasszon egy módot: **Teljes (Részletek)** az oszlopos listához, **Rövid (Oszlopok)** egy sűrű többoszlopos névlistához, **Ikonok** egy ikonrácshoz, **Indexképek (Galéria)** nagy előnézetekhez, vagy **Fa** egy mappafához.
3. A módok gyors végigböngészéséhez a menü megnyitása nélkül nyomja meg a Cmd+Shift+M-et. Minden lenyomás a következő módra lép.

![Egy panel a különböző nézetmódokat mutatja: részletek, rövid, ikonok és galéria](screenshots/view-modes.png)
*(Ábra: ugyanaz a mappa részletes listaként, rövid oszloplistaként, ikonrácsként és indexkép-galériaként megjelenítve.)*

## A fájllista rendezése

1. A Részletek nézetben kattintson egy oszlopfejlécre (Név, Típus, Méret vagy Dátum) az aszerinti rendezéshez. Egy kis nyíl a fejlécben mutatja az aktuális rendezőoszlopot és irányt.
2. Kattintson ugyanarra a fejlécre újra a sorrend megfordításához.
3. Választhatja a Nézet > Rendezés szerint lehetőséget is, és választhat Név, Fájltípus, Méret, Dátum vagy Rendezetlen közül.

A mappák mindig együtt rendeződnek felül, a fájlok előtt, és a `..` bejegyzés, amely egy szinttel feljebb viszi, elsőként rögzül. A név vagy fájltípus szerinti rendezés alapértelmezetten növekvő (A-tól Z-ig); a méret vagy dátum szerinti rendezés alapértelmezetten a legújabb vagy legnagyobb elöl.

## A megjelenített oszlopok kiválasztása

1. Válassza a Konfiguráció > Oszlopok… lehetőséget.
2. Kapcsolja be vagy ki az oszlopokat, és állítsa be a sorrendjüket. Az elérhető oszlopok közé tartozik a Név, Típus, Méret, Dátum, Attr (attribútumok), Címkék és Megjegyzés.
3. Alkalmazza a változtatásokat. Az oszlopok az aktív panel Részletek nézetét érintik.

![Az oszlopkonfigurációs ablak az elérhető oszlopok listájával](screenshots/columns-config.png)
*(Ábra: válassza ki, mely oszlopok jelenjenek meg a Részletek nézetben, és állítsa be a sorrendjüket.)*

## Billentyűparancsok

| Művelet | Billentyűparancs |
|---|---|
| Nézetmódok végigböngészése | Cmd+Shift+M |
| Rövid (oszlopok) nézet | Ctrl+F1 |
| Teljes (részletek) nézet | Ctrl+F2 |
| Indexkép (galéria) nézet | Ctrl+Shift+F1 |
| Fa nézet | Ctrl+F8 |
| Rendezés név szerint | Ctrl+F3 |
| Rendezés fájltípus szerint | Ctrl+F4 |
| Rendezés méret szerint | Ctrl+F5 |
| Rendezés dátum szerint | Ctrl+F6 |

## Tippek

- A természetes (numerikus) rendezés alapértelmezetten be van kapcsolva, így a `file2` a `file10` előtt van, nem utána. Kikapcsolhatja a Konfiguráció > Beállítások alatt a nézetbeállításokban.
- Egy oszlopot szélesebbé vagy keskenyebbé tehet a Részletek nézetben az oszlopfejlécek közötti elválasztó vonal húzásával.
- Ha a macOS billentyűzet-navigációját használja (Rendszerbeállítások ▸ Billentyűzet), a Ctrl+F1–Ctrl+F8 sor a rendszeré — menüsor, Dock, eszköztár —, és soha nem ér el a Peach Commanderig. Állítsa a billentyűsémát **macOS**-re a beállításokban: a megjelenítési módok ekkor a Cmd+1, Cmd+2 és Cmd+3, a rendezés pedig az Alt+Cmd+1–Alt+Cmd+4 kombinációkon van.
- A nézetmód, a rendezési sorrend és az oszlopválasztás panelenként megjegyződik, így egyik oldalt részletes listaként, a másikat fotógalériaként tarthatja.
