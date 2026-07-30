---
title: Automatizace (AppleScript a Zkratky)
slug: automation
section: Pokročilé nástroje
order: 98
related: [start-menu, settings]
---

Peach Commander je skriptovatelný, takže jej můžete řídit z AppleScriptu a z aplikace Zkratky. Hrstka základních sloves umožňuje skriptu procházet panely, vybírat soubory podle masky, kopírovat nebo přesouvat aktuální výběr a spustit jakýkoli příkaz Peach Commanderu podle jeho id — přičemž znovu využívají přesně stejné akce, jaké používají nabídky, takže se skriptovaný krok chová jako ruční. Hodí se to na opakující se úkony: zakládání stažených souborů, přípravu výstupu sestavení nebo zapojení souborového kroku do většího průběhu Zkratek.

## Zobrazení slovníku

1. Otevřete **Editor skriptů** (v `/Applications/Utilities`).
2. Zvolte **Okno ▸ Knihovna** a poté dvakrát klikněte na **Peach Commander** (přidejte jej pomocí **+**, pokud není v seznamu).
3. Otevře se slovník, který níže vypisuje příkazy a vlastnosti.

Při prvním ovládání Peach Commanderu skriptem vás macOS požádá o povolení (**Nastavení systému ▸ Soukromí a zabezpečení ▸ Automatizace**). Jednou jej schvalte a pozdější skripty poběží bez dotazu.

## Co lze číst

| Vlastnost | Význam |
| --- | --- |
| `active folder` | Cesta POSIX ke složce aktivního panelu. |
| `inactive folder` | Cesta POSIX ke složce druhého panelu. |
| `selection paths` | Vybrané položky v aktivním panelu (nebo položka pod kurzorem). |

## Slovesa

| Příkaz | Co dělá |
| --- | --- |
| `go to "<path>" [in left\|right]` | Otevře složku v panelu (výchozí: aktivní panel). |
| `select "<mask>"` | Vybere položky v aktivním panelu podle zástupné masky, např. `*.pdf`. |
| `copy items to "<folder>"` | Zkopíruje výběr aktivního panelu do složky. |
| `move items to "<folder>"` | Přesune výběr aktivního panelu do složky. |
| `run command "<id>"` | Spustí jakýkoli příkaz podle jeho id, např. `cm_PackFiles`. |

Copy a move používají stejnou frontu přenosů na pozadí jako F5/F6, takže průběh a případné dotazy na přepsání se zobrazují přesně jako u ruční operace.

## Příklad

```applescript
tell application "Peach Commander"
    go to "~/Downloads" in left
    select "*.pdf"
    copy items to "~/Documents/PDFs"
    return selection paths
end tell
```

## Použití z aplikace Zkratky

V aplikaci **Zkratky** přidejte akci **Spustit AppleScript** a vložte skript jako ten výše. To vám umožní zapojit krok Peach Commanderu do větší Zkratky — například spouštěné změnou složky nebo klávesovou zkratkou.

## Poznámky

- Id příkazu, které předáváte do `run command`, je stejné `cm_*` id zobrazené v prohlížeči příkazů (viz [Nabídka Start a vlastní příkazy](start-menu.md)).
- Skriptování vždy působí na **aktivní** panel; pokud potřebujete konkrétní stranu, použijte nejprve `go to … in left` / `in right`.
- Peach Commander je aplikace s jedním oknem, takže skripty cílí na dva panely tohoto okna.
