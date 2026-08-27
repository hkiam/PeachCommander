---
title: Makron
slug: macros
section: Kraftverktyg
order: 99
related: [automation, toolbar, start-menu, keyboard-shortcuts]
---

Ett makro är en namngiven följd av filåtgärder — skapa en mapp, flytta markeringen dit, tagga det som blir kvar — som du kan köra igen med ett klick. Det är inte ett skriptspråk: det finns inga villkor och inga loopar, och det är avsiktligt. Ett makro är en lista du kan läsa, och läsa är vad du måste kunna göra innan du godkänner den.

Allt ett makro gör går genom samma maskineri som assistenten använder, så ett makro kan inte göra något du inte har tillåtit, varje steg syns i åtgärdsloggen, och ett steg som kan ångras kan det fortfarande.

## Snabbaste vägen: från det du just gjorde

Du behöver inte skriva ett makro från början.

1. Gör saken en gång — via assistenten, eller genom att köra ett befintligt makro.
2. Välj **Konfiguration ▸ Makro från senaste åtgärder…**.
3. Markera de steg makrot ska upprepa, ge det ett namn och låt **Lägg även till en knapp för det** vara på.

**Spara makro**, och knappen finns i raden. Det är hela varvet.

> **Vad som inte registreras.** Listan byggs av åtgärder som gått genom assistenten eller ett annat makro. Att kopiera, flytta eller byta namn *för hand* i panelerna — F5, F6, F7 — registreras inte och kan därför inte bli ett makro den här vägen. Använd redigeraren nedan för dem.

## Redigera makron för hand

**Konfiguration ▸ Redigera makron…** öppnar `macros.json` i din konfigurationsmapp och lämnar ett kommenterat exempel där första gången. Ett makro är en lista med steg, och varje steg namnger ett verktyg och dess argument:

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

Att spara läser in makrona på nytt direkt. Vilka verktyg som finns och vad de tar emot berättar assistenten via `list_macros` — eller exemplet som filen skapades med.

### Platshållare

De enskilda bokstäverna är samma som knappraden och Start-menyn använder, så har du gjort en knapp finns inget nytt att lära här.

| Platshållare | Betyder |
| --- | --- |
| `%P` | Den aktiva panelens mapp |
| `%T` | Den andra panelens mapp |
| `%N` | Filen under markören |
| `%S` | De markerade filerna — en **lista**, vilket är precis vad `copy`, `move` och `move_to_trash` tar emot |
| `%{date:yyyy-MM}` | Datumet då makrot startade, i det formatet |
| `%{1}` | Resultatet av steg 1, när det steget gav en sökväg eller en lista sökvägar |

Klammerparenteserna är till för tilläggen eftersom bokstäverna redan är tagna: `%M` betyder ”namnet under markören i den andra panelen” i hela resten av programmet, så en månad kunde inte skrivas så.

`%S` är det enda stället där ett makro skiljer sig från en knapp: på en knapp blir markeringen en lista ord för en kommandorad, här blir den listan av fullständiga sökvägar som filverktygen tar emot.

Ett steg vars `%S` eller `%{1}` blir **tomt stoppar makrot** i stället för att köra utan något. Ett `move` utan filer är inte ett mindre `move` — det är en begäran som inte längre säger något, och att rapportera lyckat vore en lögn.

## Köra ett makro

Varje makro blir ett kommando som heter `mc_<id>` och dyker därför upp av sig själv i:

- **Konfiguration ▸ Kommandoläsare…**
- **Konfiguration ▸ Redigera kortkommandon… — lägg det på en tangent**
- Kommandoväljaren i knappradens redigerare
- Din `.mnu`-menyfil och `usercmd.ini`, om du använder dem
- Assistenten, som kan köra det på namn

Innan ett makro som ändrar något körs visar det sina steg som en lista och väntar. Du kan stryka ett steg du inte vill ha; det som blir kvar är det som körs. Ett makro som bara läser körs utan att fråga.

Om ett steg misslyckas **stannar makrot där** i stället för att fortsätta — steg två utgår oftast från att steg ett hände, och att flytta filer till en mapp som inte skapades är inte en delvis framgång. Rapporten namnger steget och säger vad som gick fel, och de steg som kördes finns i åtgärdsloggen.

## Vad ett makro får göra

Ett makro bedöms efter det mest krävande i det. Ett makro vars steg bara läser behandlas som en läsning; ett som slutar med en permanent radering hanteras som en permanent radering — innan något av det körs, inte fyra steg in.

Att inte ge något extra är standard. Innehåller ett makro ett steg som dina behörigheter inte tillåter — ett skalkommando, ett skript — nekas hela makrot med sin orsak, och inget händer.

## Ångra

Varje steg loggas för sig, så **ångra** efter ett makro tar tillbaka dess *sista* steg, inte hela makrot. Det finns ingen ångra för hela makrot, eftersom flera verktyg inte har någon invers alls och en knapp som erbjöd den skulle ljuga om dem.

## Var allt sparas

- Dina makron ligger i `macros.json` i konfigurationsmappen — en vanlig fil du kan diffa och hålla med dina dotfiles.
- Knappar ett makro lade till är vanliga knappradsposter i `default.bar`, så att ta bort en är detsamma som för vilken knapp som helst.

## Nästa steg

- [Automatisering (AppleScript och Genvägar)](automation.md) — Styra Peach Commander från ett skript, och köra dina egna skript som makrosteg.
- [Knappraden](toolbar.md) — Var knappen ett makro lade till hamnar.
- [Tangentbord och kortkommandon](keyboard-shortcuts.md) — Lägga ett makro på en tangent.
