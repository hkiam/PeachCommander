---
title: Automatizace (AppleScript a Zkratky)
slug: automation
section: Pokročilé nástroje
order: 98
related: [start-menu, settings, macros]
---

Automatizace tu funguje v obou směrech.

**Ven:** Peach Commander lze skriptovat, takže jej můžete řídit z AppleScriptu i z aplikace Zkratky. Několik základních slovesných příkazů umožňuje skriptu procházet panely, vybírat soubory maskou, kopírovat nebo přesouvat aktuální výběr a spouštět jakýkoli příkaz Peach Commanderu podle jeho id — a to přes tytéž akce, jaké používají nabídky, takže se skriptovaný krok chová jako ruční. O tom je zbytek této stránky.

**Dovnitř:** Peach Commander umí také *spustit* váš skript — AppleScript nebo JavaScript — a umístit jej do nabídky, na tlačítko nebo na klávesu. K tomu je potřeba plugin **Scripting**, který se dodává vypnutý; viz [Spouštění vlastních skriptů](#spousteni-vlastnich-skriptu) níže.

Pro opakování *posloupnosti* akcí se soubory místo jedné viz [Makra](macros.md).

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

## Spouštění vlastních skriptů

Druhý směr: váš skript, spuštěný Peach Commanderem.

Je to plugin a dodává se **vypnutý**, protože spuštění programu podle vaší volby umí vše, co umí zbytek aplikace, a několik věcí, které nepokrývá nic z ní. Dva přepínače, oba vypnuté, dokud je nenastavíte:

1. **Konfigurace ▸ Pluginy…** — zapněte **Scripting**.
2. **Nastavení ▸ AI** — zapněte **Povolit spouštění skriptů**. Je na této stránce, protože jde o stejný druh oprávnění jako shell asistenta a obojí patří k sobě.

Poté umístěte skript do `scripts/` ve vašem konfiguračním adresáři — **Příkazy ▸ Otevřít adresář skriptů** vás tam zavede a poprvé tam nechá příklad. Soubor `.applescript`, `.scpt` nebo `.jxa` v tomto adresáři *je* skript; není co registrovat.

### Co skript dostane

Stav panelů přichází v prostředí, takže běžný případ nepotřebuje Apple events ani žádný dotaz na oprávnění:

| Proměnná | Znamená |
| --- | --- |
| `PC_ACTIVE_DIR` | Adresář aktivního panelu |
| `PC_TARGET_DIR` | Adresář druhého panelu |
| `PC_CURSOR_NAME` | Soubor pod kurzorem |
| `PC_SELECTION_COUNT` | Kolik položek je vybráno |
| `PC_SELECTION_FILE` | Textový soubor s jednou vybranou cestou na řádek (chybí, když není vybráno nic) |

```applescript
set here to system attribute "PC_ACTIVE_DIR"
return "The active panel is showing " & here
```

Vše nad to jde přes aplikaci samotnou, se slovesnými příkazy výše — obě poloviny se tedy doplňují.

### Umístění skriptu na tlačítko nebo klávesu

Každý skript se stane příkazem s názvem `plugin.script.run.<název>`, kde `<název>` je jméno souboru bez přípony (mezery a tečky se mění na spojovníky). Toto id funguje všude, kde funguje id `cm_*`: v liště tlačítek, v `usercmd.ini`, v souboru `.mnu` a v **Konfigurace ▸ Upravit zkratky…**.

### Jak skript běží a časový limit

Standardně skript běží jako samostatný proces, což znamená, že mu lze dát časový limit a zastavit jej, pokud jej překročí — třicet sekund, pokud neřeknete jinak. Skript se může rozhodnout běžet *uvnitř* aplikace, což mu dovolí vrátit strukturovanou hodnotu a nechá jej mezi spuštěními zkompilovaný, ale pak není žádný časový limit: skript, který se zacyklí, drží aplikaci. Volbu uveďte v `scripts.json` vedle svých skriptů:

```json
[
  { "id": "Tidy", "fileName": "Tidy.applescript", "title": "Tidy Downloads",
    "language": "AppleScript", "mode": "subprocess", "timeoutSeconds": 60 }
]
```

Záznam potřebuje jen to, co se odchyluje od výchozích hodnot; soubor bez záznamu dostane jako název své vlastní jméno, běží jako samostatný proces a po třiceti sekundách se zastaví.

### Pro asistenta

Se zapnutým pluginem a povoleným nastavením získá asistent `run_applescript`, `run_jxa` a `check_script`. Každý z nich vám ukáže přesný skript a čeká na vaše schválení, než se cokoli spustí, a žádný z nich není nikdy nabízen externímu agentovi přes MCP.

## Poznámky

- Id příkazu, které předáváte do `run command`, je stejné `cm_*` id zobrazené v prohlížeči příkazů (viz [Nabídka Start a vlastní příkazy](start-menu.md)).
- Skriptování vždy působí na **aktivní** panel; pokud potřebujete konkrétní stranu, použijte nejprve `go to … in left` / `in right`.
- Peach Commander je aplikace s jedním oknem, takže skripty cílí na dva panely tohoto okna.
