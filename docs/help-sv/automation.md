---
title: Automation (AppleScript och Shortcuts)
slug: automation
section: Kraftverktyg
order: 98
related: [start-menu, settings]
---

Peach Commander är skriptbart, så du kan styra det från AppleScript och från appen Shortcuts. En handfull grundläggande verb låter ett skript navigera i panelerna, markera filer via en mask, kopiera eller flytta det aktuella urvalet, och köra vilket Peach Commander-kommando som helst via dess id – och återanvänder exakt samma åtgärder som menyerna använder, så ett skriptat steg beter sig som ett manuellt. Det är praktiskt för repetitiva sysslor: att sortera nedladdningar, förbereda en bygges utdata, eller koppla in ett filsteg i en större Shortcut.

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

## Anteckningar

- Kommando-id:t du skickar till `run command` är samma `cm_*`-id som visas i kommandowebbläsaren (se [Start-menyn och egna kommandon](start-menu.md)).
- Skriptning agerar alltid på den **aktiva** panelen; använd `go to … in left` / `in right` först om du behöver en specifik sida.
- Peach Commander är en app med ett enda fönster, så skript riktar sig mot det fönstrets två paneler.
