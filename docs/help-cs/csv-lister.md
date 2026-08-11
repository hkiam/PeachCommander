---
title: Soubory CSV jako tabulka
slug: csv-lister
section: Plugins
order: 129
related: [plugins, viewing-files, log-viewer]
---

Stiskněte **F3** na souboru `.csv` nebo `.tsv` a otevře se jako skutečná tabulka — sloupce, záhlaví, řazení a filtr — místo jako textové řádky s čárkami.

Je to plugin: můžete jej vypnout nebo odstranit v **Konfigurace ▸ Pluginy…**. Bez něj zobrazí F3 soubor jako prostý text, což je u malého souboru stále dobře čitelné.

## Oddělovač se zjistí, nepředpokládá se

Čárka, středník, tabulátor, svislítko a dvojtečka přicházejí v úvahu všechny. Plugin každý z nich spočítá přes prvních dvacet řádků a vezme ten, který se na nejvíce řádcích vyskytuje stejněkrát — soubor, kde má každý řádek čtyři středníky, je souborem se středníky, ať přípona říká cokoli. V praxi na tom záleží: `.csv` vyexportované tabulkovým procesorem na českém systému bývá oddělené středníky a `.tsv` není vždy oddělené tabulátory.

První řádek se považuje za záhlaví a stane se z něj názvy sloupců.

## Řazení a filtrování

Klepnutím na záhlaví sloupce se podle něj seřadí, dalším klepnutím se pořadí obrátí. Řadí se **číselně, když jsou obě hodnoty čísla**, jinak abecedně, takže sloupec s velikostmi seřadí 9 před 10, a ne za.

Vyhledávací pole filtruje během psaní, bez ohledu na velikost písmen. Ve výchozím stavu hledá ve všech sloupcích; výběrem sloupce v nabídce vedle hledá jen v něm.

## Co nedokáže

Parser je záměrně malý a jedno omezení je dobré znát dřív, než vás překvapí: **oddělovač uvnitř pole v uvozovkách se stále považuje za oddělovač.** Řádek jako

```
"Smith, John",42
```

se stane třemi buňkami místo dvou. Obklopující uvozovky se odstraní, pokud obepínají celé pole, dál se ale uvozování nevyhodnocuje. U souboru, kde na tom záleží, je lepším nástrojem vestavěný prohlížeč nebo tabulkový procesor.

Prázdné řádky se přeskakují a pole přesahující několik řádků podporováno není.
