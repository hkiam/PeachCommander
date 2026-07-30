---
title: Automatizácia (AppleScript a Skratky)
slug: automation
section: Pokročilé nástroje
order: 98
related: [start-menu, settings]
---

Peach Commander možno skriptovať, takže ho môžete ovládať z AppleScript a z aplikácie Skratky. Hŕstka základných slovies umožňuje skriptu navigovať v paneloch, vybrať súbory podľa masky, kopírovať alebo presúvať aktuálny výber a spustiť ľubovoľný príkaz Peach Commander podľa jeho identifikátora — opätovným použitím presne tých istých akcií, ktoré používajú ponuky, takže skriptovaný krok sa správa ako manuálny. Je to praktické pri opakujúcich sa úlohách: triedenie stiahnutých súborov, príprava výstupu zostavenia alebo zapojenie kroku so súborom do väčšej Skratky.

## Zobrazenie slovníka

1. Otvorte **Editor skriptov** (v `/Aplikácie/Nástroje`).
2. Vyberte **Okno ▸ Knižnica**, potom dvakrát kliknite na **Peach Commander** (pridajte ho pomocou **+**, ak nie je v zozname).
3. Slovník sa otvorí a uvedie príkazy a vlastnosti nižšie.

Prvýkrát, keď skript ovláda Peach Commander, macOS vás požiada o povolenie (**Systémové nastavenia ▸ Súkromie a bezpečnosť ▸ Automatizácia**). Schváľte to raz a neskoršie skripty bežia bez opýtania.

## Čo môžete prečítať

| Vlastnosť | Význam |
| --- | --- |
| `active folder` | Cesta POSIX priečinka aktívneho panela. |
| `inactive folder` | Cesta POSIX priečinka druhého panela. |
| `selection paths` | Vybrané položky v aktívnom paneli (alebo položka pod kurzorom). |

## Slovesá

| Príkaz | Čo robí |
| --- | --- |
| `go to "<cesta>" [in left\|right]` | Otvoriť priečinok v paneli (predvolene: aktívny panel). |
| `select "<maska>"` | Vybrať položky v aktívnom paneli podľa masky so zástupnými znakmi, napr. `*.pdf`. |
| `copy items to "<priečinok>"` | Skopírovať výber aktívneho panela do priečinka. |
| `move items to "<priečinok>"` | Presunúť výber aktívneho panela do priečinka. |
| `run command "<id>"` | Spustiť ľubovoľný príkaz podľa jeho identifikátora, napr. `cm_PackFiles`. |

Kopírovanie a presúvanie používajú tú istú frontu prenosu na pozadí ako F5/F6, takže priebeh a prípadné výzvy na prepísanie sa zobrazujú presne ako pri manuálnej operácii.

## Príklad

```applescript
tell application "Peach Commander"
    go to "~/Downloads" in left
    select "*.pdf"
    copy items to "~/Documents/PDFs"
    return selection paths
end tell
```

## Použitie zo Skratiek

V aplikácii **Skratky** pridajte akciu **Spustiť AppleScript** a vložte skript ako ten vyššie. To vám umožní zapojiť krok Peach Commander do väčšej Skratky — napríklad spustenej zmenou priečinka alebo klávesovou skratkou.

## Poznámky

- Identifikátor príkazu, ktorý odovzdáte do `run command`, je ten istý identifikátor `cm_*` zobrazený v prehliadači príkazov (pozri [Ponuka Štart a vlastné príkazy](start-menu.md)).
- Skriptovanie vždy pôsobí na **aktívny** panel; najprv použite `go to … in left` / `in right`, ak potrebujete konkrétnu stranu.
- Peach Commander je aplikácia s jedným oknom, takže skripty cielia na dva panely toho okna.
