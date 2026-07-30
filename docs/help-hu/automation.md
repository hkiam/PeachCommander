---
title: Automatizálás (AppleScript és Parancsok)
slug: automation
section: Haladó eszközök
order: 98
related: [start-menu, settings]
---

A Peach Commander szkriptelhető, így vezérelheti az AppleScriptből és a Parancsok alkalmazásból. Néhány alapvető ige lehetővé teszi, hogy egy szkript navigáljon a panelek között, maszk alapján jelöljön ki fájlokat, másolja vagy áthelyezze az aktuális kijelölést, és lefuttasson bármely Peach Commander-parancsot az azonosítója alapján – pontosan ugyanazokat a műveleteket használva újra, amelyeket a menük is, így egy szkriptelt lépés úgy viselkedik, mint egy kézi. Hasznos az ismétlődő teendőkhöz: letöltések rendszerezéséhez, egy build kimenetének előkészítéséhez vagy egy fájllépés beépítéséhez egy nagyobb Parancsba.

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

## Megjegyzések

- A `run command` parancsnak átadott parancsazonosító ugyanaz a `cm_*` azonosító, amely a parancsböngészőben látható (lásd [A Start menü és az egyéni parancsok](start-menu.md)).
- A szkriptelés mindig az **aktív** panelen hat; használja először a `go to … in left` / `in right` parancsot, ha egy adott oldalra van szüksége.
- A Peach Commander egyablakos alkalmazás, így a szkriptek ennek az ablaknak a két paneljét célozzák.
