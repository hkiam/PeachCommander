---
title: Gyorskeresés és szűrő
slug: quick-search-and-filter
section: A nézet rendezése
order: 44
related: [searching, view-modes-and-sorting]
---

Amikor egy mappa több száz elemet tartalmaz, ritkán kell görgetnie. A Peach Commander lehetővé teszi, hogy egyenesen egy fájlra ugorjon a nevét beírva (gyorskeresés), a listát csak az önt érdeklő elemekre szűkítse (gyorsszűrő), és megjelenítse vagy elrejtse a pontfájlokat, amelyeket a macOS általában szem elől rejt. Mindhárom az aktív panelen belül működik párbeszéd megnyitása nélkül.

## Ugrás egy fájlra gépeléssel (gyorskeresés)

1. Kattintson egy fájlpanelre, hogy aktív legyen.
2. Kezdje el gépelni egy név elejét. A kurzor az első megfelelő elemre ugrik.
3. Folytassa a gépelést az egyezés finomításához, vagy nyomja meg ugyanazt a betűt újra az azzal a betűvel kezdődő elemek közötti körbejáráshoz.
4. A beírt szöveg egy rövid szünet után törlődik, így bármikor új keresést kezdhet.

Alapértelmezetten a sima betűk a parancssorba mennek, a gyorskeresés pedig a Ctrl+Option+betűvel indul (a klasszikus viselkedés). Átválthatja a gyorskeresést, hogy sima gépelésre reagáljon, vagy kikapcsolhatja, a konfigurációs beállításokban.

## A lista szűrése (gyorsszűrő)

1. Az aktív panelben nyomja meg a Ctrl+S-t a gyorsszűrő bekapcsolásához.
2. Írjon be egy szűrőmaszkot. A panel élőben szűkül a megfelelő elemekre, ahogy gépel.
3. Nyomja meg az Esc-et a szűrő törléséhez és mindennek újbóli megjelenítéséhez.

A szűrő többféle maszkot fogad el:

- **Sima szöveg** minden névre illeszkedik, amely tartalmazza, amit beírt (például a `jelentés` minden elemet megjelenít, amelynek nevében bárhol szerepel a „jelentés").
- **Helyettesítő karakterek** a `*`-ot (bármely karakter) és a `?`-et (egy karakter) használják. Válasszon el több maszkot pontosvesszővel, és adjon hozzá kizárásokat egy függőleges vonal után, például `*.jpg;*.png|*thumb*` a képek megjelenítéséhez, de az indexképek elrejtéséhez.
- **Finder-címkék** címkeszín szerint szűrnek: írja be a `tag:red`-et (vagy `#red`) csak a piros címkés elemek megjelenítéséhez, vagy egy egyszerű `tag:`-et mindennek megjelenítéséhez, ami bármilyen címkét hordoz.

## Rejtett fájlok megjelenítése

Nyomja meg a Ctrl+H-t, vagy válassza a parancsot a Nézet menüből, a rejtett elemek (ponttal kezdődő nevek és rendszer által rejtett fájlok) átkapcsolásához. A beállítás az aktív panelre vonatkozik, és megjegyződik a munkamenetek között.

## Billentyűparancsok

| Művelet | Billentyűparancs |
| --- | --- |
| Gyorskeresés (klasszikus mód) | Ctrl+Option+betű |
| Gyorsszűrő be/ki | Ctrl+S |
| Szűrő törlése / mégse | Esc |
| Rejtett fájlok megjelenítése/elrejtése | Ctrl+H |

## Megjegyzések

- A gyorskeresés csak a kurzort mozgatja; a gyorsszűrő valóban megváltoztatja, mely elemek szerepelnek. Használja a szűrőt, ha egy részhalmazon szeretne dolgozni (például csak az egyezéseket kijelölni vagy másolni).
- A szűrő és rejtett fájlok beállítások panelenkéntiek, így a két oldal egyszerre különböző dolgokat mutathat.
- A gyorskeresés a nevek elejétől egyezik; a gyorsszűrő sima szöveg módja a név bárhol egyezik. Használjon egy helyettesítő karaktert, mint a `*szöveg*`, ha azt szeretné, hogy a szűrő ugyanúgy viselkedjen.
