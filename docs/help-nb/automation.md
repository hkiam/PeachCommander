---
title: Automatisering (AppleScript og Snarveier)
slug: automation
section: Kraftverktøy
order: 98
related: [start-menu, settings]
---

Peach Commander kan skriptes, så du kan styre den fra AppleScript og fra Snarveier-appen. En håndfull kjerneverb lar et skript navigere i panelene, velge filer etter en maske, kopiere eller flytte det gjeldende utvalget og kjøre hvilken som helst Peach Commander-kommando etter id-en dens – ved å gjenbruke nøyaktig de samme handlingene som menyene bruker, slik at et skriptet trinn oppfører seg som et manuelt. Det er praktisk for repetitive gjøremål: å arkivere nedlastinger, klargjøre utdataene fra en bygging, eller å koble et fil-trinn inn i en større Snarvei.

## Se ordlisten

1. Åpne **Script Editor** (i `/Programmer/Verktøy`).
2. Velg **Vindu ▸ Bibliotek**, og dobbeltklikk deretter **Peach Commander** (legg den til med **+** hvis den ikke er oppført).
3. Ordlisten åpnes og lister kommandoene og egenskapene nedenfor.

Første gang et skript styrer Peach Commander, ber macOS deg tillate det (**Systeminnstillinger ▸ Personvern og sikkerhet ▸ Automatisering**). Godkjenn det én gang, og senere skript kjører uten spørsmål.

## Hva du kan lese

| Egenskap | Betydning |
| --- | --- |
| `active folder` | POSIX-banen til det aktive panelets mappe. |
| `inactive folder` | POSIX-banen til det andre panelets mappe. |
| `selection paths` | De valgte elementene i det aktive panelet (eller elementet under markøren). |

## Verbene

| Kommando | Hva den gjør |
| --- | --- |
| `go to "<bane>" [in left\|right]` | Åpne en mappe i et panel (standard: det aktive panelet). |
| `select "<maske>"` | Velg elementer i det aktive panelet etter en jokertegnmaske, f.eks. `*.pdf`. |
| `copy items to "<mappe>"` | Kopier det aktive panelets utvalg til en mappe. |
| `move items to "<mappe>"` | Flytt det aktive panelets utvalg til en mappe. |
| `run command "<id>"` | Kjør hvilken som helst kommando etter id-en dens, f.eks. `cm_PackFiles`. |

Kopier og flytt bruker den samme bakgrunnsoverføringskøen som F5/F6, så fremdrift og eventuelle overskrivingsspørsmål vises nøyaktig som ved en manuell operasjon.

## Eksempel

```applescript
tell application "Peach Commander"
    go to "~/Downloads" in left
    select "*.pdf"
    copy items to "~/Documents/PDFs"
    return selection paths
end tell
```

## Bruke det fra Snarveier

I **Snarveier**-appen, legg til handlingen **Kjør AppleScript** og lim inn et skript som det over. Det lar deg folde et Peach Commander-trinn inn i en større Snarvei – for eksempel utløst av en mappeendring eller en hurtigtast.

## Merknader

- Kommando-id-en du sender til `run command` er den samme `cm_*`-id-en som vises i kommandoutforskeren (se [Startmenyen og egendefinerte kommandoer](start-menu.md)).
- Skripting handler alltid på det **aktive** panelet; bruk `go to … in left` / `in right` først hvis du trenger en bestemt side.
- Peach Commander er en app med ett enkelt vindu, så skript retter seg mot dette vinduets to paneler.
