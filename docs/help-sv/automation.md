---
title: Automation (AppleScript och Shortcuts)
slug: automation
section: Kraftverktyg
order: 98
related: [start-menu, settings, macros]
---

Automatisering fungerar här i båda riktningarna.

**Utåt:** Peach Commander är skriptbar, så du kan styra den från AppleScript och från appen Genvägar. En handfull kärnverb låter ett skript navigera i panelerna, markera filer med en mask, kopiera eller flytta den aktuella markeringen och köra vilket kommando i Peach Commander som helst via dess id — med exakt samma åtgärder som menyerna använder, så ett skriptat steg beter sig som ett manuellt. Om det handlar resten av den här sidan.

**Inåt:** Peach Commander kan också *köra* ett skript av dig — AppleScript eller JavaScript — och lägga det på en meny, en knapp eller en tangent. Det kräver tillägget **Scripting**, som levereras avstängt; se [Köra dina egna skript](#kora-dina-egna-skript) längre ned.

För att upprepa en *följd* av filåtgärder i stället för en enda, se [Makron](macros.md).

## Se ordlistan

1. Öppna **Script Editor** (i `/Applications/Utilities`).
2. Välj **Window ▸ Library**, och dubbelklicka sedan på **Peach Commander** (lägg till det med **+** om det inte finns med i listan).
3. Ordlistan öppnas och listar kommandona och egenskaperna nedan.

Första gången ett skript styr Peach Commander ber macOS dig att tillåta det (**System Settings ▸ Privacy & Security ▸ Automation**). Godkänn det en gång så körs senare skript utan att fråga.

## Vad du kan läsa

| Egenskap | Betydelse |
| --- | --- |
| `active folder` | POSIX-sökväg till den aktiva panelens mapp. |
| `inactive folder` | POSIX-sökväg till den andra panelens mapp. |
| `selection paths` | De markerade objekten i den aktiva panelen (eller objektet under markören). |

## Verben

| Kommando | Vad det gör |
| --- | --- |
| `go to "<path>" [in left\|right]` | Öppna en mapp i en panel (standard: den aktiva panelen). |
| `select "<mask>"` | Markera objekt i den aktiva panelen via en jokermask, t.ex. `*.pdf`. |
| `copy items to "<folder>"` | Kopiera den aktiva panelens urval till en mapp. |
| `move items to "<folder>"` | Flytta den aktiva panelens urval till en mapp. |
| `run command "<id>"` | Kör vilket kommando som helst via dess id, t.ex. `cm_PackFiles`. |

Kopiering och flytt använder samma bakgrundsöverföringskö som F5/F6, så förlopp och eventuella överskrivningsfrågor visas precis som vid en manuell operation.

## Exempel

```applescript
tell application "Peach Commander"
    go to "~/Downloads" in left
    select "*.pdf"
    copy items to "~/Documents/PDFs"
    return selection paths
end tell
```

## Använda det från Shortcuts

I appen **Shortcuts**, lägg till åtgärden **Run AppleScript** och klistra in ett skript som det ovan. Det låter dig vika in ett Peach Commander-steg i en större Shortcut – till exempel utlöst av en mappändring eller ett kortkommando.

## Köra dina egna skript

Den andra riktningen: ett skript av dig, kört av Peach Commander.

Detta är ett tillägg, och det levereras **avstängt**, eftersom att köra ett program du väljer kan göra allt som resten av programmet kan och flera saker som inget av det täcker. Två reglar, båda av tills du slår på dem:

1. **Konfiguration ▸ Tillägg…** — slå på **Scripting**.
2. **Inställningar ▸ AI** — slå på **Tillåt att skript körs**. Det ligger på den sidan därför att det är samma slags tillstånd som assistentens skal, och de två hör ihop.

Lägg sedan ett skript i `scripts/` inuti din konfigurationsmapp — **Kommandon ▸ Öppna skriptmappen** tar dig dit och lämnar ett exempel första gången. En fil `.applescript`, `.scpt` eller `.jxa` i den mappen *är* ett skript; det finns inget att registrera.

### Vad ett skript får

Panelernas tillstånd kommer i miljön, så det vanliga fallet behöver inga Apple events och ingen tillståndsfråga:

| Variabel | Betyder |
| --- | --- |
| `PC_ACTIVE_DIR` | Den aktiva panelens mapp |
| `PC_TARGET_DIR` | Den andra panelens mapp |
| `PC_CURSOR_NAME` | Filen under markören |
| `PC_SELECTION_COUNT` | Hur många objekt som är markerade |
| `PC_SELECTION_FILE` | En textfil med en markerad sökväg per rad (saknas när inget är markerat) |

```applescript
set here to system attribute "PC_ACTIVE_DIR"
return "The active panel is showing " & here
```

Allt utöver det går genom programmet självt, med verben ovan — de två halvorna kompletterar alltså varandra.

### Lägga ett skript på en knapp eller en tangent

Varje skript blir ett kommando som heter `plugin.script.run.<namn>`, där `<namn>` är filens namn utan filändelse (blanksteg och punkter blir bindestreck). Det id:t fungerar överallt där ett `cm_*`-id fungerar: i knappraden, i `usercmd.ini`, i en `.mnu`-fil och i **Konfiguration ▸ Redigera kortkommandon…**.

### Hur ett skript körs, och tidsgränsen

Som standard körs ett skript som en separat process, vilket gör att det kan få en tidsgräns och stoppas om det överskrider den — trettio sekunder om du inte säger annat. Ett skript kan välja att köra *inuti* programmet, vilket låter det returnera ett strukturerat värde och håller det kompilerat mellan körningar, men då finns ingen tidsgräns: ett skript som loopar håller programmet. Ange valet i `scripts.json` intill dina skript:

```json
[
  { "id": "Tidy", "fileName": "Tidy.applescript", "title": "Tidy Downloads",
    "language": "AppleScript", "mode": "subprocess", "timeoutSeconds": 60 }
]
```

Bara det som skiljer sig från standardvärdena behöver en post; en fil utan post får sitt eget namn som titel, körs som separat process och stoppas efter trettio sekunder.

### För assistenten

Med tillägget på och inställningen aktiv får assistenten `run_applescript`, `run_jxa` och `check_script`. Var och en visar dig det exakta skriptet och väntar på ditt godkännande innan något körs, och ingen av dem erbjuds någonsin till en extern agent via MCP.

## Anteckningar

- Kommando-id:t du skickar till `run command` är samma `cm_*`-id som visas i kommandowebbläsaren (se [Start-menyn och egna kommandon](start-menu.md)).
- Skriptning agerar alltid på den **aktiva** panelen; använd `go to … in left` / `in right` först om du behöver en specifik sida.
- Peach Commander är en app med ett enda fönster, så skript riktar sig mot det fönstrets två paneler.
