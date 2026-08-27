---
title: Makroer
slug: macros
section: Kraftverktøy
order: 99
related: [automation, toolbar, start-menu, keyboard-shortcuts]
---

En makro er en navngitt rekke filhandlinger — opprett en mappe, flytt utvalget dit, merk det som blir igjen — som du kan kjøre på nytt med ett klikk. Det er ikke et skriptspråk: det finnes ingen betingelser og ingen løkker, og det er tilsiktet. En makro er en liste du kan lese, og å kunne lese den er det som kreves før du godkjenner den.

Alt en makro gjør går gjennom samme maskineri som assistenten bruker, så en makro kan ikke gjøre noe du ikke har tillatt, hvert av trinnene havner i handlingsloggen, og et trinn som kan angres kan det fortsatt.

## Raskeste vei: ut fra det du nettopp gjorde

Du trenger ikke skrive en makro fra bunnen av.

1. Gjør tingen én gang — via assistenten, eller ved å kjøre en eksisterende makro.
2. Velg **Konfigurasjon ▸ Makro fra nylige handlinger…**.
3. Kryss av trinnene makroen skal gjenta, gi den et navn, og la **Legg også til en knapp for den** stå på.

**Lagre makro**, og knappen er i raden. Det er hele runden.

> **Hva som ikke registreres.** Listen bygges av handlinger som har gått gjennom assistenten eller en annen makro. Å kopiere, flytte eller gi nytt navn *manuelt* i panelene — F5, F6, F7 — registreres ikke og kan derfor ikke bli en makro på denne måten. Bruk redigereren nedenfor til de.

## Redigere makroer manuelt

**Konfigurasjon ▸ Rediger makroer…** åpner `macros.json` i konfigurasjonsmappen din og legger et kommentert eksempel der den første gangen. En makro er en liste med trinn, og hvert trinn navngir et verktøy og argumentene dets:

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

Lagring laster makroene på nytt umiddelbart. Hvilke verktøy som finnes og hva de tar, forteller assistenten via `list_macros` — eller eksempelet filen ble opprettet med.

### Plassholdere

De enkelte bokstavene er de samme som knapperaden og Start-menyen bruker, så har du laget en knapp, er det ingenting nytt å lære her.

| Plassholder | Betyr |
| --- | --- |
| `%P` | Mappen til det aktive panelet |
| `%T` | Mappen til det andre panelet |
| `%N` | Filen under markøren |
| `%S` | De valgte filene — en **liste**, som er nøyaktig det `copy`, `move` og `move_to_trash` tar |
| `%{date:yyyy-MM}` | Datoen makroen startet, i det formatet |
| `%{1}` | Resultatet av trinn 1, når det trinnet ga en sti eller en liste med stier |

Krøllparentesene er for tilleggene, fordi bokstavene allerede er tatt: `%M` betyr «navnet under markøren i det andre panelet» i hele resten av programmet, så en måned kunne ikke skrives slik.

`%S` er det ene stedet der en makro skiller seg fra en knapp: på en knapp blir utvalget en liste med ord for en kommandolinje, her blir det listen med fulle stier som filverktøyene tar.

Et trinn hvis `%S` eller `%{1}` kommer ut **tomt, stopper makroen** i stedet for å kjøre uten noe. Et `move` uten filer er ikke et mindre `move` — det er en forespørsel som ikke lenger sier noe, og å melde suksess ville vært en løgn.

## Kjøre en makro

Hver makro blir en kommando med navnet `mc_<id>` og dukker derfor opp av seg selv i:

- **Konfigurasjon ▸ Kommandooversikt…**
- **Konfigurasjon ▸ Rediger snarveier… — legg den på en tast**
- Kommandovelgeren i knapperadens redigerer
- `.mnu`-menyfilen din og `usercmd.ini`, hvis du bruker dem
- Assistenten, som kan kjøre den på navn

Før en makro som endrer noe kjører, viser den trinnene sine som en liste og venter. Du kan stryke et trinn du ikke vil ha; det som blir igjen er det som kjøres. En makro som bare leser, kjøres uten å spørre.

Hvis et trinn feiler, **stopper makroen der** i stedet for å fortsette — trinn to forutsetter vanligvis at trinn én skjedde, og å flytte filer til en mappe som ikke ble opprettet er ikke en delvis suksess. Rapporten navngir trinnet og sier hva som gikk galt, og trinnene som kjørte står i handlingsloggen.

## Hva en makro har lov til

En makro måles etter det mest krevende i den. En makro der trinnene bare leser, behandles som en lesing; en som ender med en permanent sletting, håndteres som en permanent sletting — før noe av den kjører, ikke fire trinn inn.

Å ikke gi noe ekstra er standarden. Inneholder en makro et trinn tillatelsene dine ikke godtar — en skallkommando, et skript — avvises hele makroen med årsaken, og ingenting skjer.

## Angre

Hvert trinn logges for seg, så **angre** etter en makro tar tilbake dens *siste* trinn, ikke hele makroen. Det finnes ingen angre for hele makroen, fordi flere verktøy ikke har noen invers i det hele tatt, og en knapp som tilbød den, ville løyet om dem.

## Hvor alt lagres

- Makroene dine ligger i `macros.json` i konfigurasjonsmappen — en vanlig fil du kan diffe og holde sammen med dotfilene dine.
- Knapper en makro la til, er vanlige knapperadsposter i `default.bar`, så å fjerne en er det samme som for enhver annen knapp.

## Neste steg

- [Automatisering (AppleScript og Snarveier)](automation.md) — Å styre Peach Commander fra et skript, og kjøre egne skript som makrotrinn.
- [Knapperaden](toolbar.md) — Hvor knappen en makro la til havner.
- [Tastatur og snarveier](keyboard-shortcuts.md) — Å legge en makro på en tast.
