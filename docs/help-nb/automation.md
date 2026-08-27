---
title: Automatisering (AppleScript og Snarveier)
slug: automation
section: Kraftverktøy
order: 98
related: [start-menu, settings, macros]
---

Automatisering virker her i begge retninger.

**Utover:** Peach Commander kan styres med skript, så du kan drive den fra AppleScript og fra Snarveier-appen. En håndfull kjerneverb lar et skript navigere i panelene, merke filer med en maske, kopiere eller flytte gjeldende utvalg og kjøre hvilken som helst Peach Commander-kommando via id-en dens — med nøyaktig de samme handlingene som menyene bruker, slik at et skriptet trinn oppfører seg som et manuelt. Det handler resten av denne siden om.

**Innover:** Peach Commander kan også *kjøre* et skript fra deg — AppleScript eller JavaScript — og legge det i en meny, på en knapp eller på en tast. Det krever tillegget **Scripting**, som leveres avslått; se [Kjør dine egne skript](#kjor-dine-egne-skript) nedenfor.

Vil du gjenta en *rekke* filhandlinger i stedet for én, se [Makroer](macros.md).

## Se ordlisten

1. Åpne **Script Editor** (i `/Applications/Utilities` — «Verktøy» i Finder).
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

## Kjør dine egne skript

Den andre retningen: et skript fra deg, kjørt av Peach Commander.

Dette er et tillegg, og det leveres **avslått**, fordi det å kjøre et program du velger kan gjøre alt resten av programmet kan, og flere ting som ingenting av det dekker. To brytere, begge av til du setter dem:

1. **Konfigurasjon ▸ Tillegg…** — slå på **Scripting**.
2. **Innstillinger ▸ KI** — slå på **Tillat at skript kjører**. Det står på den siden fordi det er samme slags tillatelse som assistentens skall, og de to hører sammen.

Legg deretter et skript i `scripts/` inne i konfigurasjonsmappen din — **Kommandoer ▸ Åpne skriptmappen** tar deg dit og legger igjen et eksempel den første gangen. En fil `.applescript`, `.scpt` eller `.jxa` i den mappen *er* et skript; det er ingenting å registrere.

### Hva et skript får

Panelenes tilstand kommer i miljøet, så det vanlige tilfellet trenger ingen Apple-hendelser og ingen tillatelsesforespørsel:

| Variabel | Betyr |
| --- | --- |
| `PC_ACTIVE_DIR` | Mappen til det aktive panelet |
| `PC_TARGET_DIR` | Mappen til det andre panelet |
| `PC_CURSOR_NAME` | Filen under markøren |
| `PC_SELECTION_COUNT` | Hvor mange elementer som er valgt |
| `PC_SELECTION_FILE` | En tekstfil med én valgt sti per linje (mangler når ingenting er valgt) |

```applescript
set here to system attribute "PC_ACTIVE_DIR"
return "The active panel is showing " & here
```

Alt utover det går gjennom programmet selv, med verbene ovenfor — de to halvdelene utfyller altså hverandre.

### Legge et skript på en knapp eller en tast

Hvert skript blir en kommando med navnet `plugin.script.run.<navn>`, der `<navn>` er filnavnet uten filendelse (mellomrom og punktum blir bindestrek). Den id-en virker overalt der en `cm_*`-id virker: i knapperaden, i `usercmd.ini`, i en `.mnu`-fil og i **Konfigurasjon ▸ Rediger snarveier…**.

### Hvordan et skript kjøres, og tidsgrensen

Som standard kjøres et skript som en egen prosess, som betyr at det kan få en tidsgrense og stoppes hvis det overskrider den — tretti sekunder med mindre du sier noe annet. Et skript kan velge å kjøre *inne i* programmet, som lar det returnere en strukturert verdi og holder det kompilert mellom kjøringer, men da finnes ingen tidsgrense: et skript som går i løkke holder programmet. Angi valget i `scripts.json` ved siden av skriptene dine:

```json
[
  { "id": "Tidy", "fileName": "Tidy.applescript", "title": "Tidy Downloads",
    "language": "AppleScript", "mode": "subprocess", "timeoutSeconds": 60 }
]
```

Bare det som avviker fra standardverdiene krever en oppføring; en fil uten oppføring får sitt eget navn som tittel, kjøres som egen prosess og stoppes etter tretti sekunder.

### Til assistenten

Med tillegget på og innstillingen aktivert får assistenten `run_applescript`, `run_jxa` og `check_script`. Hver av dem viser deg det nøyaktige skriptet og venter på din godkjenning før noe kjøres, og ingen av dem tilbys noen gang til en ekstern agent over MCP.

## Merknader

- Kommando-id-en du sender til `run command` er den samme `cm_*`-id-en som vises i kommandoutforskeren (se [Startmenyen og egendefinerte kommandoer](start-menu.md)).
- Skripting handler alltid på det **aktive** panelet; bruk `go to … in left` / `in right` først hvis du trenger en bestemt side.
- Peach Commander er en app med ett enkelt vindu, så skript retter seg mot dette vinduets to paneler.
