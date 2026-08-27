---
title: Automatizácia (AppleScript a Skratky)
slug: automation
section: Pokročilé nástroje
order: 98
related: [start-menu, settings, macros]
---

Automatizácia tu funguje v oboch smeroch.

**Von:** Peach Commander sa dá skriptovať, takže ho môžete riadiť z AppleScriptu aj z aplikácie Skratky. Niekoľko základných slovesných príkazov umožňuje skriptu prechádzať panely, vyberať súbory maskou, kopírovať alebo presúvať aktuálny výber a spúšťať akýkoľvek príkaz Peach Commanderu podľa jeho id — a to cez tie isté akcie, aké používajú ponuky, takže sa skriptovaný krok chová ako ručný. O tom je zvyšok tejto stránky.

**Dovnútra:** Peach Commander vie aj *spustiť* váš skript — AppleScript alebo JavaScript — a umiestniť ho do ponuky, na tlačidlo alebo na klávesu. Potrebný je na to plugin **Scripting**, ktorý sa dodáva vypnutý; pozri [Spúšťanie vlastných skriptov](#spustanie-vlastnych-skriptov) nižšie.

Na opakovanie *sekvencie* akcií so súbormi namiesto jednej pozri [Makrá](macros.md).

## Zobrazenie slovníka

1. Otvorte **Editor skriptov** (v `/Applications/Utilities` — „Nástroje“ vo Finderi).
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

## Spúšťanie vlastných skriptov

Druhý smer: váš skript, spustený Peach Commanderom.

Je to plugin a dodáva sa **vypnutý**, pretože spustenie programu podľa vašej voľby zvládne všetko, čo zvládne zvyšok aplikácie, a niekoľko vecí, ktoré nepokrýva nič z nej. Dva prepínače, oba vypnuté, kým ich nenastavíte:

1. **Konfigurácia ▸ Pluginy…** — zapnite **Scripting**.
2. **Nastavenia ▸ AI** — zapnite **Povoliť spúšťanie skriptov**. Je na tejto stránke, pretože ide o rovnaký druh oprávnenia ako shell asistenta a obidve patria k sebe.

Potom umiestnite skript do `scripts/` vo vašom konfiguračnom adresári — **Príkazy ▸ Otvoriť adresár skriptov** vás tam zavedie a prvýkrát tam nechá príklad. Súbor `.applescript`, `.scpt` alebo `.jxa` v tomto adresári *je* skript; nie je čo registrovať.

### Čo skript dostane

Stav panelov prichádza v prostredí, takže bežný prípad nepotrebuje Apple events ani žiadnu otázku na oprávnenie:

| Premenná | Znamená |
| --- | --- |
| `PC_ACTIVE_DIR` | Adresár aktívneho panela |
| `PC_TARGET_DIR` | Adresár druhého panela |
| `PC_CURSOR_NAME` | Súbor pod kurzorom |
| `PC_SELECTION_COUNT` | Koľko položiek je vybraných |
| `PC_SELECTION_FILE` | Textový súbor s jednou vybranou cestou na riadok (chýba, keď nie je vybrané nič) |

```applescript
set here to system attribute "PC_ACTIVE_DIR"
return "The active panel is showing " & here
```

Všetko nad to ide cez aplikáciu samotnú, so slovesnými príkazmi vyššie — obidve polovice sa teda dopĺňajú.

### Umiestnenie skriptu na tlačidlo alebo klávesu

Každý skript sa stane príkazom s názvom `plugin.script.run.<názov>`, kde `<názov>` je meno súboru bez prípony (medzery a bodky sa menia na spojovníky). Toto id funguje všade, kde funguje id `cm_*`: v lište tlačidiel, v `usercmd.ini`, v súbore `.mnu` a v **Konfigurácia ▸ Upraviť skratky…**.

### Ako skript beží a časový limit

Štandardne skript beží ako samostatný proces, čo znamená, že mu možno dať časový limit a zastaviť ho, ak ho prekročí — tridsať sekúnd, ak nepoviete inak. Skript sa môže rozhodnúť bežať *vnútri* aplikácie, čo mu dovolí vrátiť štruktúrovanú hodnotu a ponechá ho medzi spusteniami skompilovaný, ale potom nie je žiadny časový limit: skript, ktorý sa zacyklí, drží aplikáciu. Voľbu uveďte v `scripts.json` vedľa svojich skriptov:

```json
[
  { "id": "Tidy", "fileName": "Tidy.applescript", "title": "Tidy Downloads",
    "language": "AppleScript", "mode": "subprocess", "timeoutSeconds": 60 }
]
```

Záznam potrebuje len to, čo sa odchyľuje od predvolených hodnôt; súbor bez záznamu dostane ako názov svoje vlastné meno, beží ako samostatný proces a po tridsiatich sekundách sa zastaví.

### Pre asistenta

So zapnutým pluginom a povoleným nastavením získa asistent `run_applescript`, `run_jxa` a `check_script`. Každý z nich vám ukáže presný skript a čaká na vaše schválenie, než sa čokoľvek spustí, a žiadny z nich nie je nikdy ponúkaný externému agentovi cez MCP.

## Poznámky

- Identifikátor príkazu, ktorý odovzdáte do `run command`, je ten istý identifikátor `cm_*` zobrazený v prehliadači príkazov (pozri [Ponuka Štart a vlastné príkazy](start-menu.md)).
- Skriptovanie vždy pôsobí na **aktívny** panel; najprv použite `go to … in left` / `in right`, ak potrebujete konkrétnu stranu.
- Peach Commander je aplikácia s jedným oknom, takže skripty cielia na dva panely toho okna.
