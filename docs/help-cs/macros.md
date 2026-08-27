---
title: Makra
slug: macros
section: Pokročilé nástroje
order: 99
related: [automation, toolbar, start-menu, keyboard-shortcuts]
---

Makro je pojmenovaná posloupnost akcí se soubory — vytvořit adresář, přesunout do něj výběr, označit zbytek — kterou lze jedním kliknutím spustit znovu. Není to skriptovací jazyk: nejsou v něm podmínky ani cykly, a to záměrně. Makro je seznam, který si můžete přečíst, a přečíst si ho musíte umět, než ho schválíte.

Vše, co makro dělá, prochází stejným strojem jako asistent. Makro tedy nemůže udělat nic, co jste nepovolili, každý jeho krok se objeví v protokolu akcí a krok, který lze vzít zpět, se vzít zpět dá i nadále.

## Nejrychlejší cesta: z toho, co jste právě udělali

Makro nemusíte psát od začátku.

1. Udělejte to jednou — přes asistenta nebo spuštěním existujícího makra.
2. Zvolte **Konfigurace ▸ Makro z nedávných akcí…**.
3. Zaškrtněte kroky, které má makro opakovat, pojmenujte ho a nechte zapnuté **Přidat pro něj také tlačítko**.

**Uložit makro** — a tlačítko je v liště. To je celý postup.

> **Co se nezaznamenává.** Seznam se skládá z akcí, které prošly asistentem nebo jiným makrem. Ruční kopírování, přesouvání a přejmenování v panelech — F5, F6, F7 — se nezaznamenává, takže se z nich touto cestou makro udělat nedá. Na to použijte editor níže.

## Ruční úpravy maker

**Konfigurace ▸ Upravit makra…** otevře `macros.json` ve vašem konfiguračním adresáři a poprvé do něj vloží komentovaný příklad. Makro je seznam kroků a každý krok uvádí nástroj a jeho argumenty:

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

Uložení makra okamžitě znovu načte. Které nástroje existují a co přijímají, řekne asistent přes `list_macros` — nebo příklad, se kterým byl soubor vytvořen.

### Zástupné symboly

Samotná písmena jsou stejná, jaká používá lišta tlačítek a nabídka Start: kdo už jedno tlačítko vytvořil, se tu nemusí učit nic nového.

| Symbol | Znamená |
| --- | --- |
| `%P` | Adresář aktivního panelu |
| `%T` | Adresář druhého panelu |
| `%N` | Soubor pod kurzorem |
| `%S` | Vybrané soubory — **seznam**, což je přesně to, co přijímají `copy`, `move` a `move_to_trash` |
| `%{date:yyyy-MM}` | Datum spuštění makra v tomto formátu |
| `%{1}` | Výsledek kroku 1, pokud tento krok vrátil cestu nebo seznam cest |

Složené závorky jsou pro doplňky, protože písmena jsou už obsazená: `%M` znamená ve zbytku programu „jméno pod kurzorem v druhém panelu“, měsíc se tedy takto zapsat nedal.

`%S` je jediné místo, kde se makro liší od tlačítka: na tlačítku se výběr stane seznamem slov pro příkazovou řádku, tady se stane seznamem plných cest, které přijímají nástroje pro soubory.

Krok, jehož `%S` nebo `%{1}` vyjde **prázdný, makro zastaví**, místo aby běžel s ničím. `move` bez souborů není menší `move` — je to požadavek, který už nic neříká, a hlásit u něj úspěch by byla lež.

## Spuštění makra

Každé makro se stane příkazem s názvem `mc_<id>`, a proto se samo objeví v:

- **Konfigurace ▸ Prohlížeč příkazů…**
- **Konfigurace ▸ Upravit zkratky… — přiřaďte ho klávese**
- Výběru příkazů v editoru lišty tlačítek
- Vašem souboru nabídky `.mnu` a `usercmd.ini`, pokud je používáte
- Asistentovi, který ho může spustit podle názvu

Než se spustí makro, které něco mění, ukáže vám své kroky jako seznam a počká. Krok, který nechcete, můžete vyškrtnout; co zůstane, se provede. Makro, které jen čte, běží bez dotazu.

Pokud krok selže, makro se **v tom místě zastaví**, místo aby pokračovalo — krok dvě obvykle předpokládá, že krok jedna proběhl, a přesouvat soubory do nevytvořeného adresáře není částečný úspěch. Zpráva uvede krok a řekne, co se pokazilo; kroky, které proběhly, jsou v protokolu akcí.

## Co makro smí

Makro se posuzuje podle toho nejnáročnějšího, co obsahuje. Makro, jehož kroky jen čtou, se považuje za čtení; to, které končí trvalým smazáním, je hlídáno jako trvalé smazání — dřív než se cokoli spustí, ne o čtyři kroky později.

Nepovolit nic navíc je výchozí stav. Obsahuje-li makro krok, který vaše oprávnění nedovolují — příkaz shellu, skript —, je celé makro odmítnuto s uvedením důvodu a nic se nestane.

## Vzít zpět

Každý krok je zaznamenán samostatně, takže **vzít zpět** po makru vrátí jeho *poslední* krok, ne celé makro. Vzít zpět celé makro nelze, protože několik nástrojů nemá žádnou inverzi a tlačítko, které by to nabízelo, by o nich lhalo.

## Kde se to ukládá

- Vaše makra jsou v `macros.json` v konfiguračním adresáři — obyčejný soubor, který lze porovnávat a držet spolu s dotfiles.
- Tlačítka přidaná makrem jsou běžné položky lišty tlačítek v `default.bar`, takže odebrat jedno je stejné jako u kteréhokoli jiného tlačítka.

## Další kroky

- [Automatizace (AppleScript a Zkratky)](automation.md) — Řízení Peach Commanderu ze skriptu a spouštění vlastních skriptů jako kroku makra.
- [Lišta tlačítek](toolbar.md) — Kde skončí tlačítko, které makro přidalo.
- [Klávesnice a zkratky](keyboard-shortcuts.md) — Přiřazení makra klávese.
