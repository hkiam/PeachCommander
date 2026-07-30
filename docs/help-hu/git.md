---
title: Git
slug: git
section: Bővítmények
order: 123
related: [plugins, view-modes-and-sorting]
---

A Git bővítmény egy Git-tároló állapotát közvetlenül a fájlpanelbe hozza — nincs külön app, nincs terminál. Két oszlopot ad hozzá, amelyek minden fájl munkafa-állapotát és az aktuális branchet mutatják, egy **Git** almenüt a hétköznapi parancsokhoz (státusz, előkészítés, commit, pull, push), és a Macre már telepített `git`-et használja. Mivel bővítményről van szó, a **Konfiguráció ▸ Bővítmények…** menüpontból kikapcsolhatja vagy eltávolíthatja.

## Mit ad hozzá

- **Két fájllista-oszlop** — *Git Status* és *Branch*. Egy tárolóban minden fájl egy rövid állapotszót mutat (Módosítva, Hozzáadva, Törölve, Nem követett, Átnevezve, Másolva, Ütközés, Figyelmen kívül hagyva vagy Megváltozva), a panel pedig az aktuális branchet mutatja. Kapcsolja be az oszlopokat a **Konfiguráció ▸ Oszlopok…** menüpontban (lásd [Nézetmódok és rendezés](view-modes-and-sorting.md)).
- **Egy Git menü** — a **Parancsok ▸ Git** alatt, valamint egy fájl jobb gombos menüjében, a következőkkel: **Git Status…**, **Git Add (előkészítés)**, **Git Commit…**, **Git Pull** és **Git Push**.

![A Git Status párbeszéd az aktuális branchet és a tárolóban módosított fájlokat mutatja](screenshots/git-status.png)
*(Ábra: a Git Status jelenti a branchet és a munkafa minden változását.)*

## Az állapot ellenőrzése

1. Vigye a kurzort egy Git-tárolón belüli fájlra vagy mappára.
2. Válassza a **Parancsok ▸ Git ▸ Git Status…** lehetőséget (vagy jobb kattintás ▸ **Git ▸ Git Status…**).
3. Megjelenik egy összefoglaló: az aktuális branch (vagy *(leválasztott)*), majd vagy *A munkafa tiszta.*, vagy a változások listája, ahol minden sor az állapotot és a fájl útvonalát mutatja.

Ha a kurzor nincs egy tárolón belül, a bővítmény egyszerűen azt írja: *Nem Git-tároló.*

## Előkészítés, commit, pull, push

- A **Git Add (előkészítés)** előkészíti a kurzor alatti fájlt (`git add`).
- A **Git Commit…** egy commit-üzenetet kér, majd az összes változást committolja (`git commit -a`). Az összesített kimenet megjelenik, így pontosan látja, mi történt.
- A **Git Pull** egy csak fast-forward pullt hajt végre (`git pull --ff-only`).
- A **Git Push** az aktuális branchet pusholja (`git push`).

Egy olyan parancs után, amely megváltoztatja a tárolót, az aktív panel frissül, hogy az állapotoszlopok naprakészek maradjanak.

## Megjegyzések

- A bővítmény a rendszer Gitjét használja a `/usr/bin/git` alatt. Ha a Git nincs telepítve, a parancsok jelzik, hogy a Git nem érhető el. (Az Xcode Command Line Tools telepítése biztosítja.)
- A tároló állapota mappánként egyszer olvasódik be és gyorsítótárazódik, így egy nagy tároló görgetése gyors marad; a gyorsítótár minden olyan parancs után frissül, amely megváltoztatja a fát.
- A commit a `git commit -a`-t használja, amely a követett változásokat committolja; a vadonatúj fájlokhoz továbbra is előbb a **Git Add (előkészítés)** szükséges.
- A *Git Status* és *Branch* oszlopfejlécek jelenleg más felületnyelveken is angolul jelennek meg; az értékek és a párbeszédek honosítottak.
