---
title: A Start menü és egyéni parancsok
slug: start-menu
section: Testreszabás
order: 111
related: [toolbar, keyboard-shortcuts, macros]
---

A **Start** menü az ön saját személyes menüje, amely a menüsávban ül a Fájl, Szerkesztés és a többi mellett. Olyan parancsokat tartalmaz, amelyeket ön határoz meg, így a leggyakrabban használt műveletek mindig egyetlen kattintásnyira vannak. A klasszikus kétpaneles fájlkezelők hagyományában minden bejegyzés futtathat egy beépített parancsot, elindíthat egy külső programot vagy appot, vagy egyenesen egy mappára ugorhat. A Peach Commander üres Start menüvel érkezik, készen arra, hogy megtöltse.

## Hogyan adja hozzá saját parancsait

1. Válassza a **Start > Start menü módosítása…** lehetőséget. A Peach Commander megnyitja a felhasználói parancsfájlját (első alkalommal egy megjegyzésben lévő példával létrehozva).
2. Adjon hozzá egy szakaszt parancsonként. Minden szakasz egy szögletes zárójelben lévő névvel kezdődik, majd néhány egyszerű kulccsal:
   - **cmd** — mit futtasson: egy programútvonalat, egy appot, egy beépített `cm_` parancsot, vagy egy másik saját parancsát.
   - **param** — egy programnak átadott paraméterek. A helyőrzők a parancs futásakor töltődnek ki: `%P` (forrásmappa), `%N` (aktuális fájl), `%T` (a másik panel mappája), `%M` (a másik panel fájlja), `%S` (kijelölt fájlok).
   - **path** — a mappa, ahol kezdje (alapértelmezetten az aktuális mappa).
   - **menu** — a Start menüben megjelenő cím.
   - **key** — egy opcionális billentyűparancs, például `C+S+B`.
3. Mentse a fájlt. A Start menü magától frissül, amikor a Peach Commander legközelebb aktívvá válik, így az új bejegyzései azonnal megjelennek.

## Tippek

- Az aktuális mappa Terminálban való megnyitásához állítsa a **cmd**-t `open`-re, a **param**-ot `-a Terminal %P`-re, és a **menu**-t `Terminál megnyitása itt`-re.
- Irányítsa a **cmd**-t egy `cm_` parancsra, hogy egy beépített műveletnek saját Start-menü bejegyzést és billentyűparancsot adjon.
- A fájlban lévő sorrend a menüben lévő sorrend, ezért tegye a leggyakrabban használt parancsokat felülre.

## Megjegyzések

- A teljes menüsávot is lecserélheti a sajátjára. Válassza a **Konfiguráció > Menüfájl szerkesztése…** lehetőséget egy olyan menüfájl megnyitásához, amely az aktuális, teljesen lokalizált beépített menüből van kiindítva; szerkessze szabadon, és a változtatásai a következő alkalommal alkalmazódnak, amikor az app aktiválódik. Törölje a fájlt a standard menüsáv visszaállításához.
