---
title: Makroer
slug: macros
section: Kraftværktøjer
order: 99
related: [automation, toolbar, start-menu, keyboard-shortcuts]
---

En makro er en navngiven række filhandlinger — opret en mappe, flyt markeringen derind, giv resten et mærke — som du kan køre igen med et klik. Det er ikke et scriptsprog: der er ingen betingelser og ingen løkker, og det er med vilje. En makro er en liste, du kan læse, og at kunne læse den er det, der skal til, før du godkender den.

Alt, hvad en makro gør, går gennem samme maskineri som assistenten bruger, så en makro kan ikke gøre noget, du ikke har tilladt, hvert af dens trin kommer i handlingsloggen, og et trin, der kan fortrydes, kan det stadig.

## Den hurtigste vej: ud fra det, du lige gjorde

Du behøver ikke skrive en makro fra bunden.

1. Gør tingen én gang — via assistenten, eller ved at køre en eksisterende makro.
2. Vælg **Konfiguration ▸ Makro ud fra seneste handlinger…**.
3. Sæt hak ved de trin, makroen skal gentage, giv den et navn, og lad **Tilføj også en knap til den** være slået til.

**Gem makro**, og knappen er i linjen. Det er hele forløbet.

> **Hvad der ikke registreres.** Listen bygges af handlinger, der er gået gennem assistenten eller en anden makro. At kopiere, flytte eller omdøbe *manuelt* i panelerne — F5, F6, F7 — registreres ikke og kan derfor ikke blive en makro ad denne vej. Brug editoren nedenfor til dem.

## Redigér makroer manuelt

**Konfiguration ▸ Redigér makroer…** åbner `macros.json` i din konfigurationsmappe og lægger et kommenteret eksempel deri den første gang. En makro er en liste af trin, og hvert trin nævner et værktøj og dets argumenter:

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

At gemme genindlæser makroerne med det samme. Hvilke værktøjer der findes, og hvad de tager, fortæller assistenten via `list_macros` — eller eksemplet, filen blev oprettet med.

### Pladsholdere

De enkelte bogstaver er de samme, som knaplinjen og Start-menuen bruger, så har du lavet en knap, er der intet nyt at lære her.

| Pladsholder | Betyder |
| --- | --- |
| `%P` | Det aktive panels mappe |
| `%T` | Det andet panels mappe |
| `%N` | Filen under markøren |
| `%S` | De markerede filer — en **liste**, hvilket er præcis det, `copy`, `move` og `move_to_trash` tager |
| `%{date:yyyy-MM}` | Datoen, hvor makroen startede, i det format |
| `%{1}` | Resultatet af trin 1, når det trin gav en sti eller en liste af stier |

Tuborgklammerne er til tilføjelserne, fordi bogstaverne allerede er taget: `%M` betyder „navnet under markøren i det andet panel“ i hele resten af programmet, så en måned kunne ikke skrives sådan.

`%S` er det ene sted, hvor en makro afviger fra en knap: på en knap bliver markeringen en liste af ord til en kommandolinje, her bliver den listen af fulde stier, som filværktøjerne tager.

Et trin, hvis `%S` eller `%{1}` kommer ud **tomt, stopper makroen** i stedet for at køre uden noget. Et `move` uden filer er ikke et mindre `move` — det er en anmodning, der ikke længere siger noget, og at melde succes ville være en løgn.

## Kør en makro

Hver makro bliver en kommando med navnet `mc_<id>` og optræder derfor af sig selv i:

- **Konfiguration ▸ Kommandooversigt…**
- **Konfiguration ▸ Redigér tastaturgenveje… — læg den på en tast**
- Kommandovælgeren i knaplinjens editor
- Din `.mnu`-menufil og `usercmd.ini`, hvis du bruger dem
- Assistenten, som kan køre den på navn

Før en makro, der ændrer noget, kører, viser den sine trin som en liste og venter. Du kan strege et trin ud, du ikke vil have; det, der bliver tilbage, er det, der kører. En makro, der kun læser, kører uden at spørge.

Hvis et trin fejler, **stopper makroen der** i stedet for at fortsætte — trin to går som regel ud fra, at trin ét skete, og at flytte filer til en mappe, der ikke blev oprettet, er ikke en delvis succes. Rapporten nævner trinnet og siger, hvad der gik galt, og de trin, der kørte, står i handlingsloggen.

## Hvad en makro må

En makro måles på det mest krævende i den. En makro, hvis trin kun læser, behandles som en læsning; en, der ender med en permanent sletning, håndteres som en permanent sletning — før noget af den kører, ikke fire trin inde.

Ikke at give noget ekstra er standarden. Hvis en makro indeholder et trin, dine tilladelser ikke tillader — en shell-kommando, et script — afvises hele makroen med sin årsag, og der sker intet.

## Fortryd

Hvert trin logges for sig, så **fortryd** efter en makro tager dens *sidste* trin tilbage, ikke hele makroen. Der er ingen fortryd for hele makroen, fordi flere værktøjer slet ikke har nogen omvending, og en knap, der tilbød den, ville lyve om dem.

## Hvor det hele gemmes

- Dine makroer står i `macros.json` i konfigurationsmappen — en almindelig fil, du kan diffe og holde sammen med dine dotfiles.
- Knapper, en makro har tilføjet, er almindelige knaplinjeposter i `default.bar`, så at fjerne en er det samme som ved enhver anden knap.

## Næste skridt

- [Automatisering (AppleScript og Genveje)](automation.md) — At styre Peach Commander fra et script, og køre dine egne scripts som makrotrin.
- [Knaplinjen](toolbar.md) — Hvor knappen, en makro tilføjede, ender.
- [Tastatur og genveje](keyboard-shortcuts.md) — At lægge en makro på en tast.
