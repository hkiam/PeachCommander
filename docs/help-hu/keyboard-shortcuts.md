---
title: Billentyűzet és billentyűparancsok
slug: keyboard-shortcuts
section: Testreszabás
order: 112
related: [keyboard-shortcuts-reference, settings]
---

A Peach Commandert billentyűzetről való vezérlésre építették. Két kész billentyűparancs-sémával érkezik, és lehetővé teszi bármely parancs újrahozzárendelését az ön által preferált billentyűkhöz. Ha egy klasszikus kétpaneles fájlkezelőtől jön, megtarthatja a már ismert billentyűket; ha inkább ismerős Mac-kombinációkat használna, váltson a macOS-sémára egy kattintással. Egy kereshető parancsböngésző lehetővé teszi, hogy felfedezze mindent, amit az app tud, és bármely parancsot név szerint futtasson.

## Billentyűzetséma váltása

1. Nyissa meg a **Konfiguráció** menüt.
2. Válassza a **Billentyűzetséma** lehetőséget, majd válasszon egyet:
   - **TC Classic** (alapértelmezett) megtartja a hagyományos billentyűket, Ctrl-alapú kombinációkkal, mint a Ctrl+R egy panel frissítéséhez.
   - **macOS Native** ugyanazokat a műveleteket ismerős Mac-billentyűkre képezi le, ahol értelme van, például a Cmd+C fájlok másolásához és a Cmd+F kereséshez.
3. Egy pipa mutatja az aktív sémát. A változás azonnal életbe lép a menükben és a billentyűparancs-sávban.

## Billentyűparancsok testreszabása

1. Válassza a **Konfiguráció > Billentyűparancsok…** lehetőséget.
2. Keressen meg egy parancsot a keresőmező segítségével, majd jelölje ki a sorát.
3. Kattintson a **Rögzítés…** gombra és nyomja meg a kívánt billentyűkombinációt. Azonnal hozzárendelődik.
4. Ha azt a kombinációt már egy másik parancs használta, egy értesítés megmondja, melyik parancstól vették el.
5. Használja a **Törlés**-t egy parancs billentyűparancsának eltávolításához, vagy az **Alapértelmezések visszaállítása**-t az összes változtatása elvetéséhez és a séma eredeti billentyűihez való visszatéréshez.

![A billentyűparancs-szerkesztő felsorolja a parancsokat a hozzárendelt billentyűikkel](screenshots/keys-editor.png)
*(Ábra: keressen egy parancsot, majd használja a Rögzítés, Törlés vagy Alapértelmezések visszaállítása lehetőséget a billentyűparancsa megváltoztatásához.)*

## Az összes parancs böngészése

1. Válassza a **Konfiguráció > Parancsböngésző…** lehetőséget.
2. Gépeljen a keresőmezőbe a név, kategória vagy leírás szerinti szűréshez.
3. Kattintson duplán egy parancsra, vagy jelölje ki és kattintson a **Futtatás**-ra, hogy végrehajtsa az aktív panelen.

![A parancsböngésző a parancsok kereshető listáját mutatja](screenshots/command-browser.png)
*(Ábra: minden parancs egyetlen kereshető listában, mindegyik rövid leírásával.)*

## Billentyűparancsok

| Művelet | Menüútvonal |
|---|---|
| A klasszikus séma választása | Konfiguráció > Billentyűzetséma > TC Classic |
| A Mac-séma választása | Konfiguráció > Billentyűzetséma > macOS Native |
| Billentyűparancsok szerkesztése | Konfiguráció > Billentyűparancsok… |
| Az összes parancs böngészése | Konfiguráció > Parancsböngésző… |
| Az aktív panel frissítése | F2 (szintén Ctrl+R) |

## Megjegyzések

- Az egyéni billentyűparancsai automatikusan mentődnek, és az aktív séma tetejére rétegződnek. A sémák váltása megtartja a személyes felülírásait.
- Az aktuális kontextusban nem elérhető parancsok halványan jelennek meg mind a billentyűparancs-szerkesztőben, mind a parancsböngészőben.
- A funkcióbillentyűk (F1–F12) közvetlen használatához kapcsolja be a **Használja az F1, F2 stb. billentyűket standard funkcióbillentyűként** lehetőséget a Rendszerbeállítások > Billentyűzet alatt. Egyébként tartsa lenyomva az **Fn** billentyűt a funkcióbillentyűvel együtt.
