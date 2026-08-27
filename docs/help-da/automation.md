---
title: Automatisering (AppleScript og Genveje)
slug: automation
section: Avancerede værktøjer
order: 98
related: [start-menu, settings, macros]
---

Automatisering virker her i begge retninger.

**Udad:** Peach Commander kan styres med script, så du kan drive den fra AppleScript og fra appen Genveje. En håndfuld kerneverber lader et script navigere i panelerne, markere filer med en maske, kopiere eller flytte den aktuelle markering og køre enhver Peach Commander-kommando via dens id — med præcis de samme handlinger som menuerne bruger, så et scriptet trin opfører sig som et manuelt. Det handler resten af denne side om.

**Indad:** Peach Commander kan også *køre* et script fra dig — AppleScript eller JavaScript — og lægge det i en menu, på en knap eller på en tast. Det kræver pluginet **Scripting**, som leveres slået fra; se [Kør dine egne scripts](#kor-dine-egne-scripts) nedenfor.

Vil du gentage en *række* filhandlinger i stedet for én, se [Makroer](macros.md).

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

## Kør dine egne scripts

Den anden retning: et script fra dig, kørt af Peach Commander.

Dette er et plugin, og det leveres **slået fra**, fordi det at køre et program efter dit valg kan gøre alt, hvad resten af programmet kan, og flere ting, som intet af det dækker. To kontakter, begge slået fra, indtil du sætter dem:

1. **Konfiguration ▸ Plugins…** — slå **Scripting** til.
2. **Indstillinger ▸ AI** — slå **Tillad, at scripts kører** til. Det står på den side, fordi det er samme slags tilladelse som assistentens skal, og de to hører sammen.

Læg derefter et script i `scripts/` inde i din konfigurationsmappe — **Kommandoer ▸ Åbn scriptmappen** fører dig dertil og efterlader et eksempel den første gang. En fil `.applescript`, `.scpt` eller `.jxa` i den mappe *er* et script; der er intet at registrere.

### Hvad et script får

Panelernes tilstand ankommer i miljøet, så det almindelige tilfælde kræver ingen Apple events og ingen tilladelsesforespørgsel:

| Variabel | Betyder |
| --- | --- |
| `PC_ACTIVE_DIR` | Det aktive panels mappe |
| `PC_TARGET_DIR` | Det andet panels mappe |
| `PC_CURSOR_NAME` | Filen under markøren |
| `PC_SELECTION_COUNT` | Hvor mange emner der er markeret |
| `PC_SELECTION_FILE` | En tekstfil med én markeret sti pr. linje (mangler, når intet er markeret) |

```applescript
set here to system attribute "PC_ACTIVE_DIR"
return "The active panel is showing " & here
```

Alt ud over det går gennem programmet selv, med verberne ovenfor — de to halvdele supplerer altså hinanden.

### Læg et script på en knap eller en tast

Hvert script bliver en kommando med navnet `plugin.script.run.<navn>`, hvor `<navn>` er filens navn uden endelse (mellemrum og punktummer bliver bindestreger). Det id virker overalt, hvor et `cm_*`-id virker: i knaplinjen, i `usercmd.ini`, i en `.mnu`-fil og i **Konfiguration ▸ Redigér tastaturgenveje…**.

### Hvordan et script kører, og tidsgrænsen

Som standard kører et script som en separat proces, hvilket betyder, at det kan få en tidsgrænse og stoppes, hvis det overskrider den — tredive sekunder, medmindre du siger andet. Et script kan vælge at køre *inde i* programmet, hvilket lader det returnere en struktureret værdi og holder det oversat mellem kørsler, men så er der ingen tidsgrænse: et script, der looper, holder programmet. Angiv valget i `scripts.json` ved siden af dine scripts:

```json
[
  { "id": "Tidy", "fileName": "Tidy.applescript", "title": "Tidy Downloads",
    "language": "AppleScript", "mode": "subprocess", "timeoutSeconds": 60 }
]
```

Kun det, der afviger fra standardværdierne, kræver en post; en fil uden post får sit eget navn som titel, kører som separat proces og stoppes efter tredive sekunder.

### Til assistenten

Med pluginet slået til og indstillingen aktiveret får assistenten `run_applescript`, `run_jxa` og `check_script`. Hver af dem viser dig det præcise script og venter på din godkendelse, før noget kører, og ingen af dem tilbydes nogensinde til en ekstern agent via MCP.

## Bemærkninger

- Det kommando-id, du sender til `run command`, er det samme `cm_*`-id, der vises i kommandobrowseren (se [Start-menuen og brugerdefinerede kommandoer](start-menu.md)).
- Scripting handler altid på det **aktive** panel; brug `go to … in left` / `in right` først, hvis du har brug for en bestemt side.
- Peach Commander er en app med ét vindue, så scripts retter sig mod dette vindues to paneler.
