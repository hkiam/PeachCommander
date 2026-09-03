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
4. Stiskem Cmd+S (nebo klepnutím na Uložit) zapíšete své změny. Uložení soubor přepíše; pokud chcete předchozí obsah zachovat vedle něj, zapněte zálohy v Nastavení ▸ Úpravy/Zobrazení.

Chcete-li vytvořit zcela nový textový soubor v aktuálním umístění, stiskněte Shift+F4.

![Vestavěný textový editor zobrazující zvýraznění syntaxe, přehled symbolů a minimapu](screenshots/editor.png)
*(Obrázek: editor se zvýrazněním syntaxe, přehledem symbolů vlevo a minimapou vpravo.)*

Patří-li soubor `root` — záznam v `/etc`, launchd plist, konfigurace webového serveru —, uložení nabídne udělat to **jako správce**: macOS požádá o autorizaci jako obvykle, obsah se předá přes privátní dočasný soubor místo příkazové řádky a soubor si ponechá vlastního vlastníka i práva, místo aby se tiše stal vaším.

Pokud do souboru nelze zapisovat, dozvíte se to při otevření, a ne až při ukládání: titulek nese zámek a stavový řádek pojmenuje překážku — patří jinému uživateli, oprávnění zápis zakazují, uzamčený soubor, svazek jen pro čtení nebo ochrana systémem. Jen první z nich lze vyřešit autorizací uložení a jen tam je nabídnuta; u ostatních by vás stála heslo a přesto by selhala.

Okraj zobrazuje čísla řádků, řádek s kurzorem světlejší než ostatní; tlačítko vedle nabídky kódování jej skryje. Zalomený řádek je číslován jednou, takže číslo vždy znamená týž řádek, který má na mysli chyba kompilátoru nebo poznámka z revize.

## Hledání, nahrazování a navigace

- Stiskem Cmd+F otevřete lištu hledání. Chcete-li nahradit text, otevřete lištu hledání a přepněte ji na zobrazení nahrazování, nebo klepněte na Hledat/Nahradit na panelu nástrojů.
- Pro **regulární výraz** použijte Hledat ▸ *Najít regulárním výrazem…* (Ctrl+Cmd+F) nebo *Nahradit regulárním výrazem…* (Ctrl+Opt+Cmd+F). `^` a `$` odpovídají začátku a konci řádku a v náhradě `$1` zastupuje první skupinu — `(\w+) (\d+)` nahrazeno `$2=$1` udělá z `alpha 11` tedy `11=alpha`. **Jen ve výběru** udrží změnu ve vybraném textu; **Nahradit vše** přepíše všechny výskyty jedním krokem, který Cmd+Z vrátí zpět.
- Najít další (Cmd+G) navazuje na naposledy použité hledání, ať prosté, nebo vzorem. Vzor, který nelze přeložit, se ohlásí v dialogu, místo aby tiše nic nenašel.
- Klepnutím na Formátovat JSON/XML znovu odsadíte dokument JSON nebo XML do čistého, čitelného rozvržení.
- Klepnutím na Symboly (nebo stiskem Cmd+Shift+O) zobrazíte postranní panel, který uvádí třídy, funkce a metody ve vašem kódu — nebo, u souboru JSON, YAML či XML, jeho klíče a prvky. Klepnutím na položku na ni přeskočíte přímo. K čemu ještě ta struktura je, viz [Práce s JSON, YAML a XML](#práce-s-json-yaml-a-xml).
- Stiskem Cmd+L přeskočíte na konkrétní řádek.
- Stiskem Cmd+\ přeskakujete mezi závorkou a jejím odpovídajícím protějškem.
- Klepnutím na tlačítko mapy zobrazíte nebo skryjete minimapu, zmenšený přehled celého souboru, na který můžete klepnout pro rolování.
- Použijte nabídku Kódování na panelu nástrojů, pokud byl soubor uložen v jiném než výchozím kódování textu.

## Práce s JSON, YAML a XML

Tyto tři formáty mají vlastní zacházení, protože konfiguračním souborem se prochází podle struktury, a ne podle čísel řádků.

Postranní panel **Symboly** uvádí klíče souboru JSON nebo YAML a prvky souboru XML, vnořené stejně jako dokument sám. Prvek se pojmenuje podle svého atributu `id`, `name` nebo `key`, pokud jej má, takže dvacet položek `<server>` lze rozlišit. Seznam zobrazuje své položky jako `[0]`, `[1]`, a kde položka začíná klíčem, je uveden i ten — `[0] name`. Filtrační pole nad seznamem najde klíč podle názvu v souboru jakékoli velikosti a stavový řádek vždy ukazuje cestu k tomu, v čem stojí kurzor.

I poškozený soubor dostane přehled až do místa, kde se rozbije — a právě tam je potřeba nejvíc.

Nabídka **Struktura** — v pruhu nabídek, dokud je editor vpředu — vás touto strukturou přesouvá:

- **Přejít na obklopující uzel** (Ctrl+Cmd+Nahoru) vyjde k bloku, který obsahuje kurzor: od `image:` ke službě, k níž patří.
- **Přejít na prvního potomka** (Ctrl+Cmd+Dolů) vejde dovnitř.
- **Přejít na předchozího / dalšího sourozence** (Ctrl+Cmd+Vlevo / Vpravo) se pohybuje mezi položkami téže úrovně a přeskočí celý blok mezi nimi — z jednoho serveru na další, aniž byste projížděli čtyřicet řádků nastavení.
- **Vybrat obklopující uzel** (Ctrl+Cmd+A) vybere blok, v němž stojí kurzor. Stiskněte znovu a výběr se rozšíří na blok okolo, takže vyberete přesně jednu službu nebo přesně jeden prvek bez tahání myší.
- **Kopírovat strukturní cestu** (Ctrl+Cmd+C) zkopíruje pozici jako výraz, který přijímají nástroje daného formátu: `.services.web.ports[0]` pro JSON a YAML, jak to očekávají `jq` a `yq`, a `//server[@id='web-1']/port` pro XML, tedy XPath. Klíče, které nejsou obyčejná slova, se za vás uzavřou do uvozovek — `."content-type"` a nikoli `.content-type`, což v `jq` znamená něco úplně jiného.
- **Zkontrolovat dokument** (Ctrl+Cmd+V) zkontroluje soubor a postaví kurzor **na problém**, s důvodem v titulku okna. Ohlásí i to, co žádný jiný nástroj v řetězci neohlásí: duplicitní klíč, který každý parser JSON tiše přijme a jednu z obou hodnot zahodí, a čárku na konci, kterou parser od Applu přijme, ale Python, Go a `jq` odmítnou.

Dlouhé soubory se čtou tak, že se sbalí to, na čem se právě nepracuje. **Sbalit uzel** (Alt+Cmd+Vlevo) sbalí blok, v němž stojí kurzor — nejbližší, který má tělo, takže stisk na jediném řádku sbalí mapování okolo něj —, **Rozbalit uzel** (Alt+Cmd+Vpravo) jej opět otevře, **Sbalit nejvyšší úroveň** (Alt+Cmd+Nahoru) sbalí kvůli přehledu vše na nejvyšší úrovni a **Rozbalit vše** (Alt+Cmd+Dolů) to obnoví. Řádek s klíčem nebo značkou zůstává vidět a je označen, takže sbalený blok je viditelně sbalený; čísla řádků přeskočí to, co je skryté. Z dokumentu se nic neodebírá — text se pouze nekreslí, takže uložení, vrácení a hledání zůstávají beze změny a hledání najde text i ve sbaleném bloku. Umístění kurzoru do sbaleného místa jej otevře a jakákoli úprava otevře vše: sbalení je dvojice pozic a vložený text je posune.

Tatáž nabídka nese převody, které přepíšou celý dokument — nebo, je-li vybraný text, jen ten — v jediném krocích, který lze vrátit: **Zmenšit (jeden řádek)** pro tělo JSON, které se musí vejít do příkazu `curl`, **Rekurzivně setřídit klíče**, aby dva výstupy týchž nastavení nevykazovaly žádný rozdíl, **Zakódovat jako řetězec JSON** a **Dekódovat řetězec JSON** pro každodenní práci vložit certifikát, skript nebo celý dokument JSON *do* pole JSON, a **Převést JSON na YAML**. Zmenšení zachovává pořadí klíčů a přesný zápis každého čísla, protože `1.0` a `1` nejsou tatáž verze; třídění to záměrně nedělá, neboť třídit znamená přeskládat. Kódování platí pro jakýkoli soubor, nejen pro JSON. Z YAML do JSON nic není a je to rozhodnutí: vyžadovalo by parser YAML, který v systému není, a chybný odhad o kotvě nebo o `true` v uvozovkách udělá z konfiguračního souboru jiný.

U JSON a XML soubor kontroluje skutečný parser. Pro YAML žádný v systému není, takže kontrola pokrývá chyby, které lze najít i bez něj — tabulátor použitý k odsazení, což YAML výslovně zakazuje, odsazení, které neodpovídá ničemu, duplicitní klíč, neuzavřenou uvozovku — a říká to, místo aby soubor prohlásila za platný.

## Filtrování příkazem shellu

Klepněte na **Filtrovat…** (nebo stiskněte Shift+Cmd+\), abyste vybraný text poslali přes příkaz a nahradili jej tím, co příkaz vypíše. Není-li nic vybráno, projde celý dokument. Z nástrojů, které už znáte, se tak stanou příkazy editoru: `sort -u` odstraní duplicitní řádky, `jq .` zpřehlední odpověď ve formátu JSON, `column -t` zarovná tabulku, `base64 -d` dekóduje blok, `openssl x509 -noout -text` vypíše certifikát v čitelné podobě.

Příkaz běží ve vašem přihlašovacím shellu: `PATH`, aliasy i funkce fungují přesně jako v Terminálu a roury i uvozovky znamenají to, co očekáváte. Pracovním adresářem je složka upravovaného souboru, takže relativní cesty se vyhodnotí tam, kde to čekáte. Použité příkazy se pamatují a příště se nabídnou v rozbalovacím seznamu.

Pokud příkaz selže, váš text zůstane nedotčen a chybová zpráva příkazu se objeví ve stavovém řádku — syntaktická chyba nástroje `jq` nikdy neskončí vložená do vašeho souboru. Příkaz, který nic nevypíše, vyprázdní výběr; přesně k tomu se filtrování nástrojem `grep` používá a Cmd+Z jej vrátí. Příkaz, který se nedokončí, se po dvaceti sekundách ukončí.

## Řádky setřídit, odduplikovat a uklidit

Menu **Řádky** — na nástrojové liště a, dokud je editor vpředu, také v hlavní nabídce — provádí úpravy, které přicházejí znovu a znovu, bez psaného příkazu a bez nainstalovaného nástroje:

- Setřídit A→Z nebo Z→A, přičemž čísla se porovnávají podle hodnoty, takže `file9` je před `file10`.
- Obrátit pořadí řádků.
- Odstranit duplicitní řádky, z každého ponechat první a ostatní nechat v jejich pořadí.
- Odstranit prázdné řádky, včetně těch, které jen vypadají prázdné, protože obsahují mezery.
- Odstranit mezery na konci řádků — nevidnitelný rozdíl, kvůli kterému je diff nepřehledný.
- Ponechat jen řádky obsahující text, který zadáte, nebo je naopak odstranit.

Je-li text vybrán, pracuje každá z operací na vybraných řádcích; výběr se nejprve rozšíří na celé řádky, protože setřídit půl řádku nemá smysl. Bez výběru platí pro celý dokument. Každá je jediným krokem zpět, takže Cmd+Z vezme zpět celou operaci.

Konce řádků jsou vedle nabídky Kódování: **LF** pro Unix a macOS, **CRLF** pro Windows, **CR** pro klasický Mac OS a *(mixed)*, když jeden soubor obsahuje více druhů — často důvod chyby, která nedává smysl. Výběrem jiného převedete celý soubor jedním krokem, který lze vzít zpět. Operace s řádky konec řádku nikdy nemění samy od sebe: setříděný soubor s CRLF zůstane CRLF.

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
4. Stiskem Cmd+S uložíte. Stejně jako v textovém editoru se předchozí obsah zachová jen tehdy, když jste zálohy zapnuli.

## Řetězce v souboru, který upravujete

Šestnáctkový editor má stejný panel **Řetězce** jako prohlížeč: každou čitelnou posloupnost textu v souboru, ve čtyřech kódováních naráz, a kliknutí na ni umístí kurzor i výběr.

- Čte bajty tak, jak jste je upravili, ne jak leží na disku, takže offsety ukazují na správné místo i poté, co vložení posunulo vše pod ním.
- Seznam sleduje vaše úpravy: změňte bajt a chvíli po dopsání se přestaví.
- Celý je popsán v [Prohlížení souborů](viewing-files.md#read-the-strings-in-a-binary) a chová se tu stejně.

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
| Přejít na obklopující uzel (JSON/YAML/XML) | Ctrl+Cmd+Nahoru |
| Přejít na prvního potomka | Ctrl+Cmd+Dolů |
| Přejít na předchozího / dalšího sourozence | Ctrl+Cmd+Vlevo / Vpravo |
| Vybrat obklopující uzel | Ctrl+Cmd+A |
| Kopírovat strukturní cestu | Ctrl+Cmd+C |
| Zkontrolovat dokument | Ctrl+Cmd+V |
| Sbalit / rozbalit uzel | Alt+Cmd+Vlevo / Vpravo |
| Sbalit nejvyšší úroveň / rozbalit vše | Alt+Cmd+Nahoru / Dolů |
| Zpět / Znovu (hex editor) | Cmd+Z / Cmd+Shift+Z |
| Filtrovat výběr příkazem | Shift+Cmd+\ |

## Poznámky

- Zvýraznění syntaxe pokrývá JSON, C, C#, Java, JavaScript, TypeScript, Python a Rust. Ostatní typy souborů se stále otevírají a upravují normálně se základním obarvením, ale podrobné zvýraznění je dostupné jen pro podporované jazyky.
- Přehled pokrývá podporované programovací jazyky a navíc JSON, YAML a XML — včetně formátů založených na XML, jako jsou `.plist`, `.svg`, `.csproj` a `.storyboard`. Příkazy pro strukturní navigaci, cestu a kontrolu platí pro JSON, YAML a XML.
- Přehled symbolů a Přejít na řádek platí pro textový editor. Hexadecimální editor je určen pro binární kontrolu a úpravy na úrovni bytů, ne pro text.
- Ani jeden editor neuchovává zálohu, dokud si o ni neřeknete. V Nastavení ▸ Úpravy/Zobrazení zapněte „Při ukládání zachovat záložní kopii (.bak) předchozího obsahu“ a první uložení zapíše originál vedle souboru jako `name.bak`, takže náhodnou změnu lze snadno vrátit.
