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

1. Udělejte tu věc jednou — zkopírujte, přesuňte, přejmenujte nebo smažte v panelech, nebo to nechte udělat asistenta.
2. Zvolte **Konfigurace ▸ Makro z nedávných akcí…**.
3. Zaškrtněte kroky, které má makro opakovat, pojmenujte ho a nechte zapnuté **Přidat pro něj také tlačítko**.
4. Zaškrtněte **Sledovat panely místo právě těchto souborů**, má-li makro příště pracovat s tím, co bude zrovna vybráno. Řádky se při zaškrtnutí změní, takže vidíte, co ukládáte.

**Uložit makro** — a tlačítko je v liště. To je celý postup.

Seznam obsahuje obojí: co jste udělali v panelech (F5, F6, F7, F8 a přejmenování) a co udělal asistent nebo jiné makro. Každý řádek říká, které z toho — po sezení s obojím se totiž tytéž dva soubory mohou objevit v obou.

> **Co se nenabízí.** Zabalení archivu a všechno ostatní, co si aplikace pamatuje jen podle jména, se nedá proměnit v krok — není pro to tvar. Takové řádky jsou vidět zašedlé i s důvodem, místo aby chyběly, aby seznam pěti, který nabízí tři, nevypadal, že dva přehlédl. A pokud nepožádáte jinak, jsou cesty ty, které skutečně proběhly: zaznamenané makro zopakuje *tu* kopii, ne „kopii toho druhu“. Otevřete je v editoru a dejte `%S` nebo `%T` tam, kde má sledovat panely.

**Sledovat panely** je způsob, jak požádat jinak. Ze souborů, které pocházely všechny z jedné složky, se stane výběr; ze složky, která je jedním ze dvou panelů, se stane ten panel, a složka uvnitř si podrží svůj zbytek — ze zaznamenaného „přesuň tyto čtyři faktury do Dokumenty/2026-08“ se stane „přesuň vybrané do *2026-08* na druhé straně“, a zítra to funguje ve dvou jiných složkách. Co neleží pod žádným z obou panelů, zůstává cestou, kterou je — není do čeho to složit. Volba se nabízí jen tehdy, když by něco změnila.

## Přiložené příklady

Když poprvé otevřete **Konfigurace ▸ Upravit makra…**, soubor se založí se sedmi hotovými příklady. Jsou to běžná makra — upravte je, nebo smažte ta, která nechcete — a každé nese komentář, který říká, co dělá a co se v něm dá změnit:

| Makro | Co dělá |
| --- | --- |
| **Open today's folder** | Založí v aktivním panelu dnešní datovou složku a vejde do ní. Zítra poslouží znovu. |
| **File the selection into a dated folder** | Vybere všechna PDF, na druhé straně založí složku rok-měsíc a přesune je do ní. |
| **Copy the selection to a dated backup folder** | Zkopíruje to, co jste vybrali *vy*, do datované složky na druhé straně. |
| **Move the pictures into an Images subfolder** | Jedna maska, jedna podsložka, ve složce, ve které už jste. |
| **Merge the CSV files into one and open it** | Ukazuje, jak krok použije to, co vytvořil krok předchozí. |
| **File the selection into a folder you name** | Při spuštění se vás zeptá na složku. |
| **Mark the file under the cursor as reviewed** | Označí ji štítkem a opatří komentář datem — jeden soubor, ne výběr. |
| **Put the temporary files in the Trash** | Mazací makro, a to pravé, na kterém si jednou prohlédnout dotaz na oprávnění. |

Každé z nich se stane příkazem, takže kterékoli můžete umístit na tlačítko nebo na klávesu, aniž byste cokoli psali.

## Spravovat je

**Konfigurace ▸ Spravovat makra…** je ten seznam: jak se každé makro jmenuje, jak se jmenuje jeho příkaz, kolik má kroků a co bude chtít kontrola oprávnění — „tohle maže“ je tedy vidět dřív, než je dáte na klávesu. Odtud můžete přejmenovat, duplikovat, přeskupit a smazat. Když najedete na řádek, uvidíte jeho kroky.

Pořadí není ozdoba: pořadí v souboru je to, ve kterém je vypisuje Prohlížeč příkazů a výběr pro lištu tlačítek.

**Při mazání se nabídne vzít s sebou i tlačítka**, a to stojí za vědění, i kdybyste toto okno nikdy neotevřeli: makro odstraněné ručně nechá za sebou své tlačítko i klávesu, a ani jedno pak nic nedělá — aplikace teď říká, že makro není, místo aby mlčela, ale tlačítko zůstává na vás. Klávesu nebo položku nabídky je nutné vyjmout tam, kde byla nastavena.

*Kroky* se zde neupravují. **Upravit soubor…** to předá editoru, ze stejného důvodu, z jakého tu není formulář: krok je název nástroje s jeho argumenty, a to je přesně to, čím JSON je.

## Ruční úpravy maker

**Konfigurace ▸ Upravit makra…** otevře `macros.json` ve vaší konfigurační složce, poprvé založený s příklady výše. Makro je seznam kroků a každý krok jmenuje nástroj a jeho argumenty:

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

Uložení makra ihned znovu načte — a řekne, když něco nesedí: překlep v názvu nástroje, chybějící povinný argument, dvě makra se stejným id. Makro s chybou se nespustí a na žádné tlačítko se nedostane; dozvíte se, o které jde a co je na něm špatně, dokud je editor ještě otevřený.

Které nástroje existují a co berou, ukáže **Konfigurace ▸ Prohlížeč příkazů…**, nebo se asistenta zeptejte na `list_macros`.

### Zástupné symboly

Samotná písmena jsou stejná, jaká používá lišta tlačítek a nabídka Start: kdo už jedno tlačítko vytvořil, se tu nemusí učit nic nového.

| Symbol | Znamená |
| --- | --- |
| `%P` | Adresář aktivního panelu |
| `%T` | Adresář druhého panelu |
| `%N` | Soubor pod kurzorem |
| `%S` | Vybrané soubory — **seznam**, což je přesně to, co přijímají `copy`, `move` a `move_to_trash` |
| `%{date:yyyy-MM}` | Datum spuštění makra v tomto formátu |
| `%{1.destination}` | Jedna pojmenovaná hodnota z výsledku kroku 1 — zde soubor, který `merge_files` zapsal |
| `%{1}` | Celý výsledek kroku 1, pokud tento krok přímo vytvořil cestu nebo seznam cest |
| `%{ask:Folder name}` | Zeptá se vás, když makro běží. `%{ask:Folder name=Archive}` předvyplní pole hodnotou *Archive* |

Složené závorky jsou pro doplňky, protože písmena jsou už obsazená: `%M` znamená ve zbytku programu „jméno pod kurzorem v druhém panelu“, měsíc se tedy takto zapsat nedal.

Pro výsledky kroků použijte **pojmenovanou** podobu. Většina nástrojů hlásí několik hodnot místo jediné — `merge_files` hlásí, kam zapsal, kolik souborů sloučil a kolik řádků z toho vzešlo —, proto je `%{2.destination}` obvyklý zápis a holé `%{2}` funguje jen u nástroje, který vrací jedinou cestu. Jméno, které tam není nebo které není cestou, makro zastaví, místo aby se hádalo.

`%` v názvu souboru je `%`. Nic z toho, co krok vytvoří, ani žádné jméno z panelu se znovu nečte jako zástupný znak — soubor s názvem `50%Netto.pdf` tedy projde makry beze změny. Doslovné `%` v šabloně, kterou píšete *vy*, zdvojte: `%%`.

### Zeptat se na hodnotu

`%{ask:…}` je způsob, jak makro převezme něco, co dopředu vědět nemůže — vůbec nejběžnější makro je „přesuň výběr do složky, kterou pojmenuji“, a bez toho by složka musela být napevno v souboru.

Zeptáme se vás **dřív**, než se objeví plán, a odpovědi už v něm jsou: řádky říkají „Přesunout výběr do „Faktury““, ne „do toho, co za chvíli napíšete“. Zrušení otázky zruší makro; nic nebylo navrženo, natož provedeno.

Tatáž otázka napsaná dvakrát se položí jednou a použije se na obou místech, takže dva kroky jmenující tutéž složku se nemohou rozejít. Co následuje po prvním `=`, je to, čím pole začíná. Znění je vaše: zobrazí se přesně tak, jak jste je napsali, v jazyce, ve kterém jste je napsali.

Odpověď je hodnota, nikdy šablona: napíšete-li `50%Netto`, dostanete složku jménem `50%Netto`.

Makro, které se ptá, nemůže spustit externí agent přes MCP — není tam koho se zeptat, a mlčky vzít výchozí hodnoty by znamenalo odpovědět za vás. Odmítne se a řekne to.


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

Vše, co lze rozpoznat jako chybné ještě před spuštěním — nástroj, který neexistuje, chybějící argument, krok, který by spustil jiné makro —, makro zastaví před prvním krokem, ne až po třetím. Selže-li krok už za běhu, makro se **zastaví tam** místo aby pokračovalo: krok dvě obvykle předpokládá, že se krok jedna stal, a přesouvat soubory do složky, která nevznikla, není částečný úspěch. Hlášení jmenuje krok, řekne, co se pokazilo, a kolik kroků už bylo provedeno; každý z nich je v protokolu akcí, i s cestou zpět, kde nějaká je.
## Co makro smí

Makro se posuzuje podle toho nejnáročnějšího, co obsahuje. Makro, jehož kroky jen čtou, se považuje za čtení; to, které končí trvalým smazáním, je hlídáno jako trvalé smazání — dřív než se cokoli spustí, ne o čtyři kroky později.

Krok, který spouští *příkaz*, se posuzuje podle toho, co ten příkaz dělá, ne podle toho, že je to příkaz — makro, které spouští `cm_DeleteReal`, je tedy mazací makro a jako takové se vám ukáže. Makro nemůže spustit jiné makro, ani jedním z obou zápisů.

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
