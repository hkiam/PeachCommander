---
title: Háttérben futó átvitelek
slug: background-transfers
section: Fájlok és mappák
order: 32
related: [copying-files, downloading-from-url]
---

A nagy másolásoknak, áthelyezéseknek, törléseknek és letöltéseknek nem kell feltartaniuk a munkáját. A Peach Commander a háttérben futtathatja őket, és mind egy helyen gyűjti össze: a háttérben futó átvitelek kezelőjében. Innen figyelheti minden feladat folyamatát és átviteli sebességét, szüneteltetheti vagy folytathatja, megszakíthatja, vagy sorba állíthatja a feladatokat, hogy később induljanak. Mivel egy háttérfeladat önállóan fut, soha nem akadályozza meg a böngészésben, fájlok megnyitásában vagy a következő átvitel elindításában.

## Hogyan

1. Indítson el egy másolást, áthelyezést, törlést vagy letöltést, és válassza, hogy a háttérben fusson. A feladat megjelenik a háttérben futó átvitelek kezelőjében.
2. A kezelőt bármikor megnyithatja a **Parancsok ▸ Háttérben futó átvitelek kezelője…** menüpontból (vagy nyomja meg a Cmd+Shift+B billentyűt).
3. Minden feladat egy címet, egy folyamatjelző sávot és egy élő sort mutat a kész fájlokkal, az átvitt bájtokkal és az aktuális sebességgel.
4. A feladatonkénti gombokkal **Szüneteltesse**, **Folytassa** vagy **Szakítsa meg** a feladatot, miközben fut.
5. Az olyan feladatoknál, amelyeket hozzáadott, de még nem indított el (visszatartott feladatok), kattintson a feladat **Indítás** gombjára, vagy az **Összes indítása** gombra, hogy a teljes várakozási listát egyszerre elindítsa.
6. Amikor minden befejeződött, ami fontos volt, kattintson a **Befejezettek törlése** gombra a lista rendbetételéhez.

![A háttérben futó átvitelek kezelője az aktív és a várakozó feladatokat sorolja fel folyamatjelző sávokkal, valamint Szüneteltetés, Folytatás és Megszakítás gombokkal.](screenshots/transfer-manager.png)

*Minden átvitel egy sor, amelyet egymástól függetlenül szüneteltethet, folytathat vagy megszakíthat.*

## Billentyűparancsok

| Művelet | Billentyűparancs |
| --- | --- |
| A háttérben futó átvitelek kezelőjének megnyitása | Cmd+Shift+B |

## Tippek

- **Korlátozza a sebességet.** Hogy egy nagy átvitel ne terhelje túl a kapcsolatot vagy a lemezt, állítson be sebességkorlátot a másolási párbeszédpanelen a feladat indítása előtt. A kezelő ezután élőben mutatja a korlátozott sebességet.
- **Állítsa sorba későbbre.** A visszatartott feladatok a listában várnak futás nélkül, amíg meg nem nyomja az Indítás (vagy az Összes indítása) gombot, így több átvitelt is előkészíthet, és együtt indíthatja el őket.
- **Futtasson egyszerre többet.** A feladatok egymástól függetlenül futnak, így az egyiket szüneteltetheti, míg egy másik tovább fut.

## Megjegyzések

Mivel egy háttérfeladat anélkül fut, hogy Ön figyelné, nem tud megállni, hogy kérdéseket tegyen fel. Ha egy fájl már létezik a célhelyen, a háttérfeladat felülírja; ha egy adott elemet nem lehet átvinni, azt az elemet kihagyja, és a feladat tovább folytatódik. Amikor a feladat befejeződik, a kihagyott elemek egy hibanaplóba gyűlnek, így pontosan áttekintheti, mi ment félre.
