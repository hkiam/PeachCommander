---
title: Úpravy souborů
slug: editing-files
section: Prohlížení a úpravy
order: 72
related: [viewing-files]
---

Když potřebujete soubor změnit, a ne jen si jej prohlédnout, Peach Commander jej otevře ve vestavěném editoru. Textové a kódové soubory se otevírají v plnohodnotném editoru se zvýrazněním syntaxe, hledáním a nahrazováním, přehledem symbolů ve vašem kódu a minimapou pro rychlou navigaci. Binární soubory lze otevřít v samostatném hexadecimálním editoru, kde můžete zkoumat a měnit jednotlivé byty. K rychlé úpravě nikdy nemusíte opustit aplikaci.

## Úprava textového nebo kódového souboru

1. V kterémkoli panelu přesuňte kurzor na soubor, který chcete změnit.
2. Stiskněte F4, nebo zvolte Soubor ▸ Upravit. Soubor se otevře v okně editoru.
3. Proveďte změny. Pokud je soubor rozpoznaným programovacím nebo datovým formátem, klíčová slova, řetězce a komentáře se automaticky obarví.
4. Stiskem Cmd+S (nebo klepnutím na Uložit) zapíšete své změny. První uložení uchová zálohu originálu vedle souboru, takže se k němu vždy můžete vrátit.

Chcete-li vytvořit zcela nový textový soubor v aktuálním umístění, stiskněte Shift+F4.

![Vestavěný textový editor zobrazující zvýraznění syntaxe, přehled symbolů a minimapu](screenshots/editor.png)
*(Obrázek: editor se zvýrazněním syntaxe, přehledem symbolů vlevo a minimapou vpravo.)*

Patří-li soubor `root` — záznam v `/etc`, launchd plist, konfigurace webového serveru —, uložení nabídne udělat to **jako správce**: macOS požádá o autorizaci jako obvykle, obsah se předá přes privátní dočasný soubor místo příkazové řádky a soubor si ponechá vlastního vlastníka i práva, místo aby se tiše stal vaším.

Okraj zobrazuje čísla řádků, řádek s kurzorem světlejší než ostatní; tlačítko vedle nabídky kódování jej skryje. Zalomený řádek je číslován jednou, takže číslo vždy znamená týž řádek, který má na mysli chyba kompilátoru nebo poznámka z revize.

## Hledání, nahrazování a navigace

- Stiskem Cmd+F otevřete lištu hledání. Chcete-li nahradit text, otevřete lištu hledání a přepněte ji na zobrazení nahrazování, nebo klepněte na Hledat/Nahradit na panelu nástrojů.
- Klepnutím na Formátovat JSON/XML znovu odsadíte dokument JSON nebo XML do čistého, čitelného rozvržení.
- Klepnutím na Symboly (nebo stiskem Cmd+Shift+O) zobrazíte postranní panel, který uvádí třídy, funkce a metody ve vašem kódu. Klepnutím na položku na ni přeskočíte přímo.
- Stiskem Cmd+L přeskočíte na konkrétní řádek.
- Stiskem Cmd+\ přeskakujete mezi závorkou a jejím odpovídajícím protějškem.
- Klepnutím na tlačítko mapy zobrazíte nebo skryjete minimapu, zmenšený přehled celého souboru, na který můžete klepnout pro rolování.
- Použijte nabídku Kódování na panelu nástrojů, pokud byl soubor uložen v jiném než výchozím kódování textu.

## Formátování souboru

Klikněte v editoru na **Formátovat** (stejný příkaz je i v prohlížeči) a soubor se znovu odsadí. Peach Commander vybere formátovač podle přípony a ve stavovém řádku ukáže, který to byl, například *formatted (jq)* — takže vždy víte, co výsledek utvářelo.

**Bez instalace čehokoli**: JSON, XML, SVG, plisty, HTML, konfigurace ve stylu INI a YAML. YAML je zvláštní případ: uklidí se, místo aby se znovu odsazoval, protože v YAML *je* odsazení strukturou a přepsat je bez skutečného parseru YAML by mohlo změnit význam souboru. Mezery na konci řádku zmizí, zbloudilé tabulátory v odsazení se stanou mezerami, řady prázdných řádků se zkrátí — a vše ve blokovém skaláru (`|` nebo `>`) zůstane přesně tak, jak je, protože tam je bílý znak obsahem.

**Lepší formátovače převezmou vládu automaticky.** Máte-li některý z nich, Peach Commander použije jej, protože specializovaný nástroj obvykle odpovídá tomu, co očekává okolní ekosystém — a u konfiguračních formátů zachová vaše komentáře:

| Nainstalujte | a získáte |
| --- | --- |
| `yq` nebo `prettier` | plné formátování YAML, komentáře zachovány |
| `taplo` | TOML |
| `sqlformat` nebo `sql-formatter` | SQL |
| `prettier` | Markdown |
| `jq` | JSON v obvyklém stylu |
| `xmllint` | XML a SVG |

Nemá-li typ souboru formátovač, je tlačítko zešedlé a položka nabídky vypnutá. Pokus vám přesto řekne proč — *„taplo není nainstalován“* se čte jinak než *„Neplatný JSON“*.

### Použití vlastního formátovače

Chcete-li formátovat typ, který Peach Commander nezná, nebo použít jiný nástroj, vytvořte v konfigurační složce `formatters.ini` — jedna sekce na příponu:

```ini
[swift]
tool = swiftformat
args = --quiet stdin

[sql]
tool = /opt/homebrew/bin/sqlfluff
args = format -
```

`tool` je jméno spustitelného programu (hledá se jako ve vašem shellu) nebo absolutní cesta; `args` se předají bez úprav. Text souboru jde dovnitř standardním vstupem a formátovaný text se čte ze standardního výstupu, takže funguje každý dobře vychovaný formátovač z příkazové řádky. Vaše záznamy vítězí nad všemi ostatními. Při prvním spuštění se vytvoří okomentovaná šablona — otevřete soubor a doplňte ji.

Formátovače mohou dodávat i zásuvné moduly — viz [Plugins](plugins.md).

## Úprava souboru byte po bytu

1. Vyberte soubor v panelu.
2. Zvolte Soubor ▸ Upravit jako hex (nebo klepněte na soubor pravým tlačítkem a zvolte Upravit jako hex).
3. Psaním hexadecimálních číslic přepisujete byty, nebo se šipkami pohybujte souborem. Backspace a Delete odstraňují byty.
4. Stiskem Cmd+S uložíte. Stejně jako u textového editoru se uchová jednorázová záloha originálu.

## Zkratky

| Akce | Klávesa |
|---|---|
| Upravit soubor | F4 |
| Vytvořit a upravit nový textový soubor | Shift+F4 |
| Uložit | Cmd+S |
| Hledat | Cmd+F |
| Zobrazit/skrýt přehled symbolů | Cmd+Shift+O |
| Přejít na řádek | Cmd+L |
| Přeskočit na odpovídající závorku | Cmd+\ |
| Zpět / Znovu (hex editor) | Cmd+Z / Cmd+Shift+Z |

## Poznámky

- Zvýraznění syntaxe pokrývá JSON, C, C#, Java, JavaScript, TypeScript, Python a Rust. Ostatní typy souborů se stále otevírají a upravují normálně se základním obarvením, ale podrobné zvýraznění a přehled symbolů jsou dostupné jen pro podporované jazyky.
- Přehled symbolů a Přejít na řádek platí pro textový editor. Hexadecimální editor je určen pro binární kontrolu a úpravy na úrovni bytů, ne pro text.
- Oba editory uchovávají zálohu původního souboru při prvním uložení, takže náhodnou změnu lze snadno vrátit obnovením té zálohy.
