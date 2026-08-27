---
title: Makrók
slug: macros
section: Haladó eszközök
order: 99
related: [automation, toolbar, start-menu, keyboard-shortcuts]
---

A makró fájlműveletek elnevezett sorozata — mappát létrehozni, a kijelölést belé mozgatni, a maradékot címkézni —, amelyet egy kattintással újra lefuttathat. Nem szkriptnyelv: nincsenek benne feltételek és ciklusok, és ez szándékos. A makró egy lista, amelyet el lehet olvasni, és olvasni tudni kell, mielőtt jóváhagyja.

Mindaz, amit egy makró tesz, ugyanazon a gépezeten megy át, mint az asszisztens. A makró tehát semmi olyat nem tehet, amit nem engedélyezett, minden lépése megjelenik a műveletnaplóban, és ami visszavonható volt, az továbbra is az.

## A legrövidebb út: abból, amit épp most tett

A makrót nem kell nulláról megírni.

1. Végezze el egyszer — az asszisztensen keresztül, vagy egy meglévő makró lefuttatásával.
2. Válassza a **Beállítás ▸ Makró a legutóbbi műveletekből…** menüpontot.
3. Jelölje be azokat a lépéseket, amelyeket a makrónak meg kell ismételnie, adjon neki nevet, és hagyja bekapcsolva a **Gomb hozzáadása is hozzá** jelölőt.

**Makró mentése** — és a gomb ott van a sávban. Ez az egész folyamat.

> **Amit nem rögzít.** A lista azokból a műveletekből épül fel, amelyek az asszisztenson vagy egy másik makrón mentek át. A panelekben *kézzel* végzett másolás, áthelyezés és átnevezés — F5, F6, F7 — nem kerül rögzítésre, így ezen az úton nem alakítható makróvá. Azokhoz használja az alábbi szerkesztőt.

## Makrók szerkesztése kézzel

A **Beállítás ▸ Makrók szerkesztése…** megnyitja a `macros.json` fájlt a konfigurációs mappában, és első alkalommal egy megjegyzésekkel ellátott példát hagy benne. A makró lépések listája, és minden lépés megnevez egy eszközt és annak argumentumait:

```json
[
  {
    "id": "stage-by-month",
    "title": "File the selection into a dated folder",
    "icon": "calendar",
    "steps": [
      { "tool": "set_selection", "arguments": { "mask": "*.pdf" } },
      { "tool": "make_directory", "arguments": { "path": "%T/%{date:yyyy-MM}" } },
      { "tool": "move", "arguments": { "sources": "%S", "destination": "%T/%{date:yyyy-MM}" } }
    ]
  }
]
```

A mentés azonnal újratölti a makrókat. Hogy milyen eszközök vannak és mit fogadnak el, az asszisztens mondja meg a `list_macros` segítségével — vagy a példa, amellyel a fájl létrejött.

### Helyettesítők

Az egyes betűk ugyanazok, amelyeket a gombsáv és a Start menü használ: aki már készített gombot, annak itt nincs mit újat tanulnia.

| Helyettesítő | Jelentése |
| --- | --- |
| `%P` | Az aktív panel mappája |
| `%T` | A másik panel mappája |
| `%N` | A kurzor alatti fájl |
| `%S` | A kijelölt fájlok — **lista**, és pontosan ezt fogadja el a `copy`, a `move` és a `move_to_trash` |
| `%{date:yyyy-MM}` | A makró indulásának dátuma, ebben a formában |
| `%{1}` | Az 1. lépés eredménye, ha az a lépés útvonalat vagy útvonalak listáját adta |

A kapcsos zárójelek a kiegészítéseknek szólnak, mert a betűk már foglaltak: a `%M` a program egészében „a másik panel kurzora alatti nevet” jelenti, így a hónapot nem lehetett így írni.

A `%S` az egyetlen pont, ahol a makró eltér a gombtól: gombon a kijelölés szavak listája lesz egy parancssorhoz, itt pedig a teljes útvonalak listája, amelyet a fájleszközök elfogadnak.

Az a lépés, amelynek `%S` vagy `%{1}` értéke **üresen jön ki, megállítja a makrót**, ahelyett hogy semmivel futna. A fájl nélküli `move` nem kisebb `move` — olyan kérés, amely már nem mond semmit, és sikert jelenteni rá hazugság lenne.

## Makró futtatása

Minden makró `mc_<id>` nevű paranccsá válik, és ezáltal magától megjelenik itt:

- **Beállítás ▸ Parancsböngésző…**
- **Beállítás ▸ Gyorsbillentyűk szerkesztése… — tegye egy billentyűre**
- A gombsáv szerkesztőjének parancsválasztójában
- A `.mnu` menüfájljában és a `usercmd.ini` fájlban, ha használja őket
- Az asszisztensben, amely név alapján futtatni tudja

Mielőtt egy változtató makró lefut, listaként megmutatja a lépéseit és vár. Kihúzhatja azt a lépést, amelyet nem szeretne; ami marad, az fut le. A csak olvasó makró kérdés nélkül fut.

Ha egy lépés meghiúsul, a makró **ott megáll**, nem megy tovább — a második lépés általában feltételezi, hogy az első megtörtént, és nem létrehozott mappába fájlokat áthelyezni nem részleges siker. A jelentés megnevezi a lépést és megmondja, mi hibázott; a lefutott lépések a műveletnaplóban vannak.

## Mit tehet egy makró

A makrót a benne lévő legigényesebb dolog szerint mérik. Az a makró, amelynek lépései csak olvasnak, olvasásnak számít; az, amely végleges törléssel végződik, végleges törlésként van védve — még azelőtt, hogy bármi elindulna, nem négy lépéssel később.

Alapértelmezés szerint semmi többet nem ad meg. Ha a makró olyan lépést tartalmaz, amelyet az engedélyei nem tesznek lehetővé — shell-parancsot, szkriptet —, az egész makró elutasításra kerül az indoklással, és nem történik semmi.

## Visszavonás

Minden lépés önállóan naplózódik, ezért a makró utáni **visszavonás** annak *utolsó* lépését veszi vissza, nem az egész makrót. Makró egészére vonatkozó visszavonás nincs, mert több eszköznek egyáltalán nincs inverze, és egy gomb, amely ezt felajánlaná, róluk hazudna.

## Hol tárolódik mindez

- A makrói a konfigurációs mappa `macros.json` fájljában vannak — egyszerű fájl, amelyet diffelhet és a dotfiles közt tarthat.
- A makró által hozzáadott gombok a `default.bar` szokásos gombsáv-bejegyzései, így egyet eltávolítani ugyanaz, mint bármely más gombnál.

## Következő lépések

- [Automatizálás (AppleScript és Parancsok)](automation.md) — A Peach Commander vezérlése szkriptből, és saját szkriptek futtatása makrólépésként.
- [A gombsáv](toolbar.md) — Ahová a makró által hozzáadott gomb kerül.
- [Billentyűzet és gyorsbillentyűk](keyboard-shortcuts.md) — Makró billentyűhöz rendelése.
