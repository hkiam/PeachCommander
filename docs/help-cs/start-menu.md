---
title: Nabídka Start a vlastní příkazy
slug: start-menu
section: Přizpůsobení
order: 111
related: [toolbar, keyboard-shortcuts, macros]
---

Nabídka **Start** je vaše vlastní osobní nabídka, sedící v panelu nabídek vedle Soubor, Úpravy a ostatních. Obsahuje příkazy, které si sami definujete, takže akce, po kterých saháte nejčastěji, jsou vždy jedno klepnutí daleko. V tradici klasických dvoupanelových správců souborů může každá položka spustit vestavěný příkaz, spustit externí program nebo aplikaci, nebo přeskočit rovnou do složky. Peach Commander se dodává s prázdnou nabídkou Start připravenou k tomu, abyste ji naplnili.

## Jak přidat vlastní příkazy

1. Zvolte **Start > Upravit nabídku Start…**. Peach Commander otevře váš soubor uživatelských příkazů (poprvé jej vytvoří s okomentovaným příkladem).
2. Přidejte jednu sekci na příkaz. Každá sekce začíná názvem v hranatých závorkách, poté několika jednoduchými klíči:
   - **cmd** — co spustit: cestu programu, aplikaci, vestavěný příkaz `cm_`, nebo jiný z vašich příkazů.
   - **param** — parametry předané programu. Zástupné symboly se vyplní při spuštění příkazu: `%P` (zdrojová složka), `%N` (aktuální soubor), `%T` (složka druhého panelu), `%M` (soubor druhého panelu), `%S` (vybrané soubory).
   - **path** — složka, ve které začít (výchozí je aktuální složka).
   - **menu** — titulek zobrazený v nabídce Start.
   - **key** — volitelná zkratka, například `C+S+B`.
3. Uložte soubor. Nabídka Start se sama aktualizuje, když se Peach Commander příště stane aktivním, takže vaše nové položky se objeví ihned.

## Tipy

- Chcete-li otevřít aktuální složku v Terminálu, nastavte **cmd** na `open`, **param** na `-a Terminal %P` a **menu** na `Otevřít Terminál zde`.
- Namiřte **cmd** na příkaz `cm_`, abyste vestavěné akci dali vlastní položku nabídky Start a zkratku.
- Pořadí v souboru je pořadím v nabídce, takže dejte nejpoužívanější příkazy nahoru.

## Poznámky

- Můžete také nahradit celý panel nabídek vlastním. Zvolte **Konfigurace > Upravit soubor nabídky…** pro otevření souboru nabídky vysetého z aktuální, plně lokalizované vestavěné nabídky; upravte jej volně a vaše změny se použijí, když se aplikace příště aktivuje. Smazáním souboru obnovíte standardní panel nabídek.
