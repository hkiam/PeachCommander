---
title: Fájlok kijelölése
slug: selecting-files
section: Fájlok és mappák
order: 22
related: [copying-files, searching]
---

Mielőtt bármit másolna, áthelyezne, törölne vagy tömörítene, először megmondja a Peach Commandernek, mely elemeken hasson. Az elem, amelyen a kurzor áll, mindig az aktuális elem, de *megjelölhet* egy vagy több fájlt és mappát is, hogy egy parancs egyszerre fusson mindegyiken. A megjelölt elemek eltérő névszínnel emelkednek ki a panelben.

## Fájlok és mappák megjelölése

1. Kattintson egy sorra a kurzor ráhelyezéséhez. Egyetlen kattintás csak azt az egy elemet jelöli ki.
2. Több elem egyszerre megjelöléséhez tartsa lenyomva a Cmd-t és kattintson mindegyikre, vagy tartsa lenyomva a Shiftet és kattintson egy tartomány megjelöléséhez.
3. A kurzor alatti elem megjelöléséhez és egyszerre lefelé lépéshez nyomja meg az Insertet. Ismételten megnyomva gyorsan megjelölhet egymást követő elemek sorozatát. A szóköz szintén átkapcsolja az aktuális elem megjelölését (és megmutatja egy mappa méretét).
4. A panelen minden megjelöléséhez válassza a Kijelölés > Mindet kijelöl (Ctrl+Num+) lehetőséget, vagy nyomja meg a Cmd+A-t. Válassza a Kijelölés > Kijelölés megszüntetése (Ctrl+Num-) lehetőséget az összes megjelölés törléséhez.

## Kijelölés vagy megszüntetés minta szerint

1. Válassza a Kijelölés > Csoport kijelölése… (Num+) lehetőséget olyan elemek hozzáadásához, amelyek nevei megfelelnek egy mintának, vagy a Kijelölés > Csoport kijelölésének megszüntetése… (Num-) lehetőséget a megfelelő elemek eltávolításához az aktuális megjelölésekből.
2. Írjon be egy helyettesítő karakteres maszkot. Használja a `*`-ot bármely karakterhez és a `?`-et egyetlen karakterhez. Több maszkot pontosvesszővel válasszon el, a kivételeket pedig függőleges vonal után sorolja fel — például a `*.jpg;*.png` megjelöli az összes képet, a `*.*|*.bak` pedig mindent a biztonsági mentés fájlok kivételével.

![A Csoport kijelölése párbeszéd egy helyettesítő karakteres maszkkal a mintamezőben](screenshots/select-by-mask.png)
*(Ábra: fájlok megjelölése helyettesítő karakteres maszkkal.)*

## Invertálás, azonos kiterjesztés és visszaállítás

- **Kijelölés invertálása** (Num*, Kijelölés menü) minden megjelölést megfordít: a megjelölt elemek kijelöletlenné válnak és fordítva — hasznos az „minden, kivéve ezek"-hez.
- **Mindet kijelöl azonos kiterjesztéssel** (Alt+Num+, Kijelölés menü) megjelöli minden fájlt, amely osztozik a kurzor alatti elem kiterjesztésén, így egyetlen billentyűlenyomás megragadja például az összes `.pdf` fájlt.
- **Kijelölés visszaállítása** (Num/, Kijelölés menü) visszahozza a megjelölések előző készletét — hasznos, ha egy parancs törölte őket, vagy rossz csoportot jelölt meg.

## Billentyűparancsok

| Művelet | Billentyű |
|---|---|
| Megjelölés átkapcsolása, lefelé lépés | Insert |
| Megjelölés átkapcsolása (aktuális elem) | Szóköz |
| Mindet kijelöl / Kijelölés megszüntetése | Ctrl+Num+ / Ctrl+Num- |
| Mindet kijelöl (alternatíva) | Cmd+A |
| Csoport kijelölése maszk szerint | Num+ |
| Csoport kijelölésének megszüntetése maszk szerint | Num- |
| Kijelölés invertálása | Num* |
| Mindet kijelöl azonos kiterjesztéssel | Alt+Num+ |
| Előző kijelölés visszaállítása | Num/ |

## Megjegyzések

- A megjelölések és a kurzor függetlenek: a kurzor nyílbillentyűkkel való mozgatása nem változtatja meg, mi van megjelölve.
- A szülőmappa-bejegyzés (`..`) soha nem jelölhető meg.
- A Csoport kijelölése, Csoport kijelölésének megszüntetése és Kijelölés invertálása a fájlnév alapján egyezik, így a párbeszéd beállításaitól függően bevonhat vagy kihagyhat mappákat.
- Egy másolás, áthelyezés vagy törlés befejezése után a sikeresen kezelt elemek automatikusan kijelöletlenné válnak, míg a sikertelenek megjelöltek maradnak, hogy újrapróbálhassa őket.
