---
title: Automatisering (AppleScript og Genveje)
slug: automation
section: Avancerede værktøjer
order: 98
related: [start-menu, settings]
---

Peach Commander kan scriptes, så du kan styre den fra AppleScript og fra Genveje-appen. En håndfuld kerneverber lader et script navigere i panelerne, markere filer efter en maske, kopiere eller flytte den aktuelle markering og køre enhver Peach Commander-kommando via dens id — og genbruger præcis de samme handlinger, som menuerne bruger, så et scriptet trin opfører sig som et manuelt. Det er praktisk til gentagne opgaver: at arkivere overførsler, klargøre outputtet fra et build eller koble et filtrin ind i en større Genvej.

## Se ordbogen

1. Åbn **Script Editor** (i `/Applications/Utilities`).
2. Vælg **Window ▸ Library**, og dobbeltklik derefter på **Peach Commander** (tilføj den med **+**, hvis den ikke er på listen).
3. Ordbogen åbner og viser kommandoerne og egenskaberne nedenfor.

Første gang et script styrer Peach Commander, beder macOS dig om at tillade det (**System Settings ▸ Privacy & Security ▸ Automation**). Godkend det én gang, og senere scripts kører uden at spørge.

## Hvad du kan læse

| Egenskab | Betydning |
| --- | --- |
| `active folder` | POSIX-sti til det aktive panels mappe. |
| `inactive folder` | POSIX-sti til det andet panels mappe. |
| `selection paths` | De markerede emner i det aktive panel (eller emnet under markøren). |

## Verberne

| Kommando | Hvad den gør |
| --- | --- |
| `go to "<path>" [in left\|right]` | Åbn en mappe i et panel (standard: det aktive panel). |
| `select "<mask>"` | Markér emner i det aktive panel efter en jokertegnmaske, f.eks. `*.pdf`. |
| `copy items to "<folder>"` | Kopiér det aktive panels markering til en mappe. |
| `move items to "<folder>"` | Flyt det aktive panels markering til en mappe. |
| `run command "<id>"` | Kør enhver kommando via dens id, f.eks. `cm_PackFiles`. |

Kopiér og flyt bruger den samme baggrundsoverførselskø som F5/F6, så fremdrift og eventuelle overskrivningsprompter vises præcis, som de gør for en manuel handling.

## Eksempel

```applescript
tell application "Peach Commander"
    go to "~/Downloads" in left
    select "*.pdf"
    copy items to "~/Documents/PDFs"
    return selection paths
end tell
```

## Brug af det fra Genveje

I **Genveje**-appen skal du tilføje handlingen **Kør AppleScript** og indsætte et script som det ovenfor. Det lader dig folde et Peach Commander-trin ind i en større Genvej — for eksempel udløst af en mappeændring eller en genvejstast.

## Bemærkninger

- Det kommando-id, du sender til `run command`, er det samme `cm_*`-id, der vises i kommandobrowseren (se [Start-menuen og brugerdefinerede kommandoer](start-menu.md)).
- Scripting handler altid på det **aktive** panel; brug `go to … in left` / `in right` først, hvis du har brug for en bestemt side.
- Peach Commander er en app med ét vindue, så scripts retter sig mod dette vindues to paneler.
