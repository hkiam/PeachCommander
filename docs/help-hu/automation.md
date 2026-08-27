---
title: Automatizálás (AppleScript és Parancsok)
slug: automation
section: Haladó eszközök
order: 98
related: [start-menu, settings, macros]
---

Az automatizálás itt mindkét irányba működik.

**Kifelé:** A Peach Commander szkriptelhető, így vezérelheti AppleScriptből és a Parancsok appból is. Néhány alapvető ige lehetővé teszi, hogy egy szkript a panelek között navigáljon, maszk alapján fájlokat jelöljön ki, a jelenlegi kijelölést másolja vagy áthelyezze, és a Peach Commander bármely parancsát lefuttassa az azonosítója alapján — ugyanazokat a műveleteket használva, mint a menük, így a szkriptelt lépés úgy viselkedik, mint egy kézi. Erről szól a lap többi része.

**Befelé:** A Peach Commander egy *saját* szkriptjét is le tudja futtatni — AppleScriptet vagy JavaScriptet — és menüre, gombra vagy billentyűre teheti. Ehhez kell a **Scripting** bővítmény, amely kikapcsolva érkezik; lásd [Saját szkriptek futtatása](#sajat-szkriptek-futtatasa) lentebb.

Ha fájlműveletek *sorozatát* szeretné megismételni, nem csak egyet, lásd [Makrók](macros.md).

## A szótár megtekintése

1. Nyissa meg a **Script Editort** (a `/Applications/Utilities` mappában).
2. Válassza a **Window ▸ Library** menüpontot, majd kattintson duplán a **Peach Commander** elemre (adja hozzá a **+** gombbal, ha nincs a listán).
3. Megnyílik a szótár, amely felsorolja az alábbi parancsokat és tulajdonságokat.

Amikor egy szkript először vezérli a Peach Commandert, a macOS engedélyt kér erre (**System Settings ▸ Privacy & Security ▸ Automation**). Hagyja jóvá egyszer, és a későbbi szkriptek rákérdezés nélkül futnak.

## Amit kiolvashat

| Tulajdonság | Jelentés |
| --- | --- |
| `active folder` | Az aktív panel mappájának POSIX-útvonala. |
| `inactive folder` | A másik panel mappájának POSIX-útvonala. |
| `selection paths` | Az aktív panelen kijelölt elemek (vagy a kurzor alatti elem). |

## Az igék

| Parancs | Mit csinál |
| --- | --- |
| `go to "<path>" [in left\|right]` | Megnyit egy mappát egy panelen (alapértelmezés: az aktív panel). |
| `select "<mask>"` | Az aktív panelen helyettesítő karakteres maszk alapján jelöl ki elemeket, pl. `*.pdf`. |
| `copy items to "<folder>"` | Az aktív panel kijelölését egy mappába másolja. |
| `move items to "<folder>"` | Az aktív panel kijelölését egy mappába helyezi át. |
| `run command "<id>"` | Bármely parancsot lefuttat az azonosítója alapján, pl. `cm_PackFiles`. |

A másolás és az áthelyezés ugyanazt a háttérben futó átviteli sort használja, mint az F5/F6, így a folyamat és bármely felülírási rákérdezés pontosan úgy jelenik meg, mint egy kézi művelet esetén.

## Példa

```applescript
tell application "Peach Commander"
    go to "~/Downloads" in left
    select "*.pdf"
    copy items to "~/Documents/PDFs"
    return selection paths
end tell
```

## Használat a Parancsok alkalmazásból

A **Parancsok** alkalmazásban adja hozzá a **Run AppleScript** műveletet, és illessze be egy fenti szkripthez hasonlót. Ezzel egy Peach Commander-lépést egy nagyobb Parancsba hajthat – amelyet például egy mappaváltozás vagy egy gyorsbillentyű indít el.

## Saját szkriptek futtatása

A másik irány: egy saját szkript, amelyet a Peach Commander futtat.

Ez egy bővítmény, és **kikapcsolva** érkezik, mert egy Ön által választott program futtatása mindent tud, amit a program többi része, és több olyat is, amit abból semmi. Két kapcsoló, mindkettő kikapcsolva, míg Ön be nem állítja:

1. **Beállítás ▸ Bővítmények…** — kapcsolja be a **Scripting** bővítményt.
2. **Beállítások ▸ MI** — kapcsolja be a **Szkriptek futtatásának engedélyezése** lehetőséget. Azon a lapon van, mert ugyanolyan típusú engedély, mint az asszisztens shellje, és a kettő együvé tartozik.

Ezután helyezzen egy szkriptet a konfigurációs mappán belüli `scripts/` mappába — a **Parancsok ▸ Szkriptmappa megnyitása** odavezet, és első alkalommal egy példát hagy ott. Egy `.applescript`, `.scpt` vagy `.jxa` fájl abban a mappában *már* szkript; nincs mit regisztrálni.

### Mit kap egy szkript

A panelek állapota a környezeten keresztül érkezik, így a szokásos esethez nincs szükség Apple-eseményekre és engedélykérésre sem:

| Változó | Jelentése |
| --- | --- |
| `PC_ACTIVE_DIR` | Az aktív panel mappája |
| `PC_TARGET_DIR` | A másik panel mappája |
| `PC_CURSOR_NAME` | A kurzor alatti fájl |
| `PC_SELECTION_COUNT` | Hány elem van kijelölve |
| `PC_SELECTION_FILE` | Szövegfájl, soronként egy kijelölt útvonallal (nincs, ha semmi sincs kijelölve) |

```applescript
set here to system attribute "PC_ACTIVE_DIR"
return "The active panel is showing " & here
```

Minden ezen túli magán a programon keresztül megy, a fenti igékkel — a két fél tehát összeáll.

### Szkript gombra vagy billentyűre helyezése

Minden szkript `plugin.script.run.<név>` nevű paranccsá válik, ahol a `<név>` a fájl kiterjesztés nélküli neve (a szóközök és pontok kötőjelre változnak). Ez az azonosító mindenhol működik, ahol egy `cm_*` azonosító működik: a gombsávon, a `usercmd.ini` fájlban, egy `.mnu` fájlban és a **Beállítás ▸ Gyorsbillentyűk szerkesztése…** részben.

### Hogyan fut egy szkript, és az időkorlát

Alapértelmezés szerint a szkript külön folyamatként fut, ami azt jelenti, hogy időkorlátot lehet adni neki, és megállítható, ha túllépi — harminc másodperc, ha nem mond mást. A szkript választhatja azt is, hogy a programon *belül* fusson, így strukturált értéket adhat vissza és a futások között lefordítva marad, de akkor nincs időkorlát: egy ciklusba került szkript megfogja a programot. A választást a szkriptjei mellett, a `scripts.json` fájlban adja meg:

```json
[
  { "id": "Tidy", "fileName": "Tidy.applescript", "title": "Tidy Downloads",
    "language": "AppleScript", "mode": "subprocess", "timeoutSeconds": 60 }
]
```

Csak az igényel bejegyzést, ami eltér az alapértékektől; a bejegyzés nélküli fájl a saját nevét kapja címnek, külön folyamatként fut, és harminc másodperc után megáll.

### Az asszisztens számára

Bekapcsolt bővítménnyel és engedélyezett beállítással az asszisztens megkapja a `run_applescript`, `run_jxa` és `check_script` eszközöket. Mindegyik megmutatja Önnek a pontos szkriptet, és megvárja a jóváhagyását, mielőtt bármi lefutna, és egyiket sem ajánlja fel soha külső ügynöknek MCP-n keresztül.

## Megjegyzések

- A `run command` parancsnak átadott parancsazonosító ugyanaz a `cm_*` azonosító, amely a parancsböngészőben látható (lásd [A Start menü és az egyéni parancsok](start-menu.md)).
- A szkriptelés mindig az **aktív** panelen hat; használja először a `go to … in left` / `in right` parancsot, ha egy adott oldalra van szüksége.
- A Peach Commander egyablakos alkalmazás, így a szkriptek ennek az ablaknak a két paneljét célozzák.
