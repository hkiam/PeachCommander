---
title: Markdown och HTML i visaren
slug: markdown-viewer
section: Insticksprogram
order: 136
related: [plugins, viewing-files, privacy-and-security]
---

Tryck F3 på en `.md`- eller `.html`-fil och den visas formaterad i stället för som källtext: rubriker, listor, tabeller, länkar, uppgiftslistor och kodblock färgade efter språk. Diagram skrivna som ` ```mermaid `-block ritas, och matematik skriven mellan dollartecken sätts.

Det här är ett plugin. Allt på den här sidan kommer från **Markdown and HTML**, som du kan stänga av i **Konfiguration ▸ Plugins…** — längre ned står vad som då ändras.

## Var den formaterade vyn visas

- **Visaren (F3).** Den formaterade sidan. Menyn **Vy** erbjuder fortfarande Text, Kod och Hex, så källtexten är ett klick bort, och pluginets namn står också i listan.
- **Quick View (Ctrl+Q) och infosidan** i sidopanelen visar samma återgivning, så en förhandsvisning och en full vy av samma fil är aldrig oense.
- **Galleriet** visar en liten bild av början på en Markdown-fil i stället för en allmän dokumentikon.
- **Quick Look (Cmd+Y)** är macOS egen förhandsvisning och påverkas *inte* — den panelen tillhör systemet, och inget plugin kan rita i den.

## Symbolöversikten

Tryck **Symboler** i visaren för att få dokumentets rubriker, nästlade som de är skrivna, och klicka på en för att hoppa dit på sidan. Det fungerar i den formaterade vyn och i källtexten, och de två är eniga om var en rubrik står.

## Diagram och matematik

Ett kodblock med språket `mermaid` blir ett diagram; `$…$` och `$$…$$` blir satt matematik. Båda ritas **på din Mac**, av motorer som följer med i pluginet — inget laddas ned, och ingen del av ditt dokument skickas någonstans. Ett dollartecken inuti ett kodblock eller inline-kod förblir ett dollartecken.

Ett dokument utan diagram och utan formel laddar ingen av motorerna, så en vanlig README kostar inget extra. Ett diagram som inte kan läsas visar felet där blocket stod, med blockets egen text under, i stället för att försvinna.

Båda kan stängas av separat i **Konfiguration ▸ Inställningar ▸ Markdown**, där man också ser vilken version som används och varifrån den kommer.

## Din egen version

Behöver du en nyare eller annan version av Mermaid eller KaTeX, lägg den i mappen som knappen **Engine Folder…** öppnar, och den används i stället för den medföljande. Filnamnen är `mermaid.min.js`, `katex.min.js`, `katex.min.css` och `auto-render.min.js`. Inget hämtas någonsin från internet för din räkning.

## Vad den formaterade sidan inte gör

Den formaterade sidan är avsiktligt avskild, för en Markdown-fil är innehåll som kommer någon annanstans ifrån:

- **Den laddar inget över nätet.** En bild vars adress börjar med `http` förblir tom med flit: att hämta den skulle berätta för den servern när du öppnade filen, och från vilken adress. En bild som ligger intill dokumentet på disken laddas som vanligt.
- **Dokumentets egna skript och HTML körs aldrig.** HTML som står i en Markdown-fil visas som text, och en `.html`-fil visas med skript avstängda.

## Stänga av det

Stäng av pluginet i **Konfiguration ▸ Plugins…**, och `.md`- och `.html`-filer öppnas som text. Översikten fungerar fortfarande, syntaxfärgningen fungerar fortfarande, och inget annat ändras — den formaterade vyn erbjuds bara inte. Detsamma gäller om du bara stänger av den formaterade vyn på pluginets inställningssida.

## Gränser

- Filer över en storleksgräns (8 MB som standard, på inställningssidan) öppnas som text i stället. Att göra ett mycket stort genererat dokument till en formaterad sida är långsamt, och textvisaren öppnar det direkt.
- Den formaterade sidan kan inte redigeras. Använd F4 för det, eller vyn Text för **Formatera**, **Kodning** och **Gå till**, som gäller källtext och inte en återgiven sida.
