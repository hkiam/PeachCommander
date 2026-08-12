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

A szokásos Méret (memória) és Dátum (indítási idő) oszlopok mellett a Task Manager folyamatoszlopokat ad hozzá:

| Oszlop | Jelentés |
| --- | --- |
| **PID** | Folyamatazonosító |
| **CPU %** | Legutóbbi processzorhasználat (egy második frissítés kell a megjelenéséhez) |
| **Threads** | Szálak száma |
| **State** | R fut · S alszik · T leállítva · Z zombi · I tétlen |
| **User** | Tulajdonos |
| **PPID** | Szülőfolyamat azonosítója |
| **Command** | Teljes parancssor |

Rendezzen bármely oszlop szerint (például CPU % vagy Méret/memória), pontosan úgy, ahogy egy normál mappában tenné.

## Egy folyamat vizsgálata vagy bezárása

- A **Megtekintés (F3)** egy *Folyamatinformáció* jelentést mutat: név, PID, szülő, felhasználó, állapot, szálak, memória, CPU, indítási idő, a futtatható fájl útvonala és a teljes parancssor.
- A **Törlés (F8)** bezárja a folyamatot. Az első törlés egy kíméletes **kilépést** küld (SIGTERM); egy még futó folyamat második törlése egy **kényszerített kilépésre** (SIGKILL) fokozódik. A bővítmény soha nem célozza az 1-es PID-et.

## Megjegyzések

- Az alapvető adatok (PID, szülő, felhasználó, állapot) minden folyamatra olvashatók, mint a `ps` esetében. A memória, a szálak és a CPU csak a **saját** folyamataira olvasható; más folyamatok ezeket az oszlopokat üresen mutatják (emelt szintű jogosultságokat igényelnek, egy későbbi kiegészítés).
- A CPU % két mintavétel közötti változás, ezért üres marad, amíg a panel másodszor is nem frissül (a panel körülbelül kétmásodpercenként frissül).
- A lista a folyamatok bezárásán kívül csak olvasható — nem másolhat bele fájlokat.
