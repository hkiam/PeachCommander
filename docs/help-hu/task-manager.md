---
title: Task Manager
slug: task-manager
section: Bővítmények
order: 125
related: [plugins, viewing-files, deleting-files]
---

A Task Manager bővítmény a Macen futó folyamatokat egy böngészhető mappává alakítja. Egy **TaskManager** meghajtóként jelenik meg a meghajtósávban; nyissa meg, és minden folyamat egy sor, amelyet rendezhet, fájlként vizsgálhat vagy bezárhat — ugyanazokkal a billentyűkkel, amelyeket már a fájlokhoz is használ. Mivel bővítményről van szó, a **Konfiguráció ▸ Bővítmények…** menüpontból kikapcsolhatja vagy eltávolíthatja.

## Megnyitás

1. Kattintson a **📊 TaskManager** bejegyzésre a meghajtósávban (közvetlenül az indítómeghajtó után ül).
2. A panel megtelik, soronként egy futó folyamattal. Minden sor neve a folyamat neve, majd a PID-je, például `Finder (462)`.
3. A **TaskManager** gomb kijelölve marad, amíg benne van, a lap pedig a meghajtó nevét viseli. Váltson egy másik lapra, majd vissza — vagy lépjen ki és nyissa meg újra az alkalmazást —, és a lap ismét a folyamatlistát mutatja. Kilépni egy szinttel feljebb lépve vagy a meghajtósávon egy másik kötetre kattintva lehet.

![A Task Manager felsorolja a futó folyamatokat a PID, CPU, memória és parancs oszlopokkal](screenshots/task-manager.png)
*(Ábra: a futó folyamatok fájllistaként megjelenítve, amelyet rendezhet és amelyen műveleteket végezhet.)*

## Mit jelent az egyes oszlopok

A Dátum (indítási idő) oszlop mellé a Task Manager folyamatoszlopokat is tesz. Egy folyamatsor Mérete `DIR`, mert a folyamat egy mappa, amelyet megnyithat (lásd lentebb) — a memóriának saját oszlopai vannak:

| Oszlop | Jelentés |
| --- | --- |
| **PID** | Folyamatazonosító |
| **CPU %** | Legutóbbi processzorhasználat (egy második frissítés kell a megjelenéséhez) |
| **Memory** | Memórialábnyom — amiért ez a folyamat felelős (az a szám, amelyet az Activity Monitor mutat) |
| **Resident** | Rezidens méret, a megosztott lapokkal együtt; minden folyamatnál kitöltve |
| **Threads** | Szálak száma |
| **State** | R fut · S alszik · T leállítva · Z zombi · I tétlen, valamint a `ps` által hozzáadott utótagok (s = munkamenet-vezető, + = előtér, N = alacsony prioritás) |
| **User** | Tulajdonos |
| **PPID** | Szülőfolyamat azonosítója |
| **Read** | A folyamat indulása óta a lemezről olvasott bájtok |
| **Written** | A folyamat indulása óta a lemezre írt bájtok |
| **Wakeups** | Megszakításos ébresztések a folyamat indulása óta |
| **Signed** | Ki írta alá a programot: az Apple, egy Developer ID-csapat, ad-hoc, vagy aláíratlan |
| **Command** | Teljes parancssor |

Rendezzen bármely oszlop szerint (például CPU % vagy Méret/memória), pontosan úgy, ahogy egy normál mappában tenné.

## Egy folyamat vizsgálata vagy bezárása

- A **Megtekintés (F3)** egy *Folyamatinformáció* jelentést mutat: név, PID, szülő, felhasználó, állapot, szálak, memória, CPU, indítási idő, a futtatható fájl útvonala és a teljes parancssor.
- A **Törlés (F8)** bezárja a folyamatot. Az első törlés egy kíméletes **kilépést** küld (SIGTERM); egy még futó folyamat második törlése egy **kényszerített kilépésre** (SIGKILL) fokozódik. A bővítmény soha nem célozza az 1-es PID-et.

## A fájlt használó folyamatok megkeresése

Kattintson a jobb gombbal bármelyik sorra, válassza a **Folyamatok keresése fájl alapján…** parancsot, majd adja meg egy fájl útvonalát. Minden folyamat kiemelve jelenik meg, amely az adott fájlt éppen nyitva tartja, a kurzor pedig az elsőre ugrik, amely módosítani tudja:

- **Kék** — a folyamat csak olvassa a fájlt.
- **Narancssárga** — a folyamat csak ír bele.
- **Lila** — a folyamat mindkettőt teszi.

Az útvonal a másik panel kurzorából van előre kitöltve, így ott rámutathat egy fájlra, és gépelés nélkül kérdezhet. Ugyanebben a menüben a **Folyamat keresése port alapján…** a testvérkérdésre válaszol: melyik folyamat figyel egy TCP/UDP-porton. A **Fájlkiemelés törlése** eltávolítja a színeket; a folyamatlista elhagyása szintén eltávolítja őket.

## Nyisson meg egy folyamatot, és lássa a fájljait

Nyomjon Entert egy folyamaton — vagy kattintson rá duplán — és a panel felsorolja azokat a fájlokat, amelyeket a folyamat éppen nyitva tart, közönséges fájlsorokként, valódi mérettel és dátummal. Innen:

- A **Megtekintés (F3)** magát a fájlt nyitja meg.
- Az **Ugrás a fájlhoz** a másik panelen mutatja meg, ahol dolgozhat vele.
- A **Megjelenítés a Finderben** átadja a Findernek.

Csak a nyitott fájlok számítanak: egy könyvtár, amelyet a folyamat csupán a memóriába képezett le, és a munkakönyvtára nem nyitott fájlok. Más felhasználó folyamata üres mappát mutat.

## Megjegyzések

- Az alapadatok (PID, szülő, felhasználó, állapot, aláírás) minden folyamatnál olvashatók. A memórialábnyom, a szálak, a lemez-I/O és a nyitott fájlok listája a **saját** folyamatainál olvasható, ami egy szokásos Mac-en a lista nagy része. Más felhasználók folyamatainál a CPU és a Resident helyette a `ps` alapján töltődik ki — élettartam-átlag a két mérés különbsége helyett, amelyet a többi sor hordoz — a szálak és a lábnyom pedig üresen maradnak.
- A CPU % két mintavétel közötti változás, ezért üres marad, amíg a panel másodszor is nem frissül (a panel körülbelül kétmásodpercenként frissül).
- A lista a folyamatok bezárásán kívül csak olvasható — nem másolhat bele fájlokat.
- A kiemelés színei a színtémát követik: a Norton paletta helyettük zöldet, pirosat és bíbort használ.
- Csak azok a leírók találhatók meg, amelyekbe a fiókja belenézhet, ami a gyakorlatban a saját folyamatait jelenti. Egy könyvtár, amelyet a folyamat csupán a memóriába képezett le, vagy a munkakönyvtára nem nyitott leíró, és nem jelenik meg.
- A **Signed** oszlop az első másodpercekben töltődik fel: egy aláírás elolvasása körülbelül egy ezredmásodperc, és több száz különböző program van, ezért frissítésenként néhányat olvas be, majd megjegyzi őket. Az üres cella azt jelenti, hogy „még nincs beolvasva”, nem azt, hogy „aláíratlan”.
- A **Signed** azt mondja meg, ki írta alá a programot, nem azt, hogy hitelesítve van-e: a hitelesítés ellenőrzése az egész program hash-elését jelenti, ami programonként másodpercekbe telne.
- A gyorsszűrő (Ctrl+S) itt az oszlopokra is illeszkedik, nem csak a névre, és egy kifejezés megnevezheti azt az oszlopot, amelyre vonatkozik: a `user:root state:R` azt kérdezi, mit futtat éppen a root. A kifejezéseket szóköz választja el, és mindnek illeszkednie kell; az oszlopot meg nem nevező szöveg egyetlen egyszerű részszöveg marad, a szóközökkel együtt.
