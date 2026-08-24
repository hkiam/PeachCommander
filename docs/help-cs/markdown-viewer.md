---
title: Markdown a HTML v prohlížeči
slug: markdown-viewer
section: Zásuvné moduly
order: 136
related: [plugins, viewing-files, privacy-and-security]
---

Stiskněte F3 na souboru `.md` nebo `.html` a zobrazí se formátovaný, ne jako zdrojový text: nadpisy, seznamy, tabulky, odkazy, seznamy úkolů a bloky kódu obarvené podle jazyka. Diagramy zapsané jako bloky ` ```mermaid ` se nakreslí a matematika mezi znaky dolaru se vysází.

Toto je zásuvný modul. Vše na této stránce pochází z **Markdown and HTML**, který můžete vypnout v **Konfigurace ▸ Zásuvné moduly…** — níže je popsáno, co se pak změní.

## Kde se formátovaný pohled objeví

- **Prohlížeč (F3).** Formátovaná stránka. Nabídka **Zobrazení** stále nabízí Text, Kód a Hex, zdrojový text je tedy jedno kliknutí daleko, a jméno modulu je v tomto seznamu také.
- **Quick View (Ctrl+Q) a informační stránka** v postranním panelu zobrazují totéž, takže náhled a plné zobrazení téhož souboru si nikdy neodporují.
- **Galerie** zobrazí malý obrázek začátku souboru Markdown místo obecné ikony dokumentu.
- **Quick Look (Cmd+Y)** je vlastní náhled systému macOS a *není* ovlivněn — ten panel patří systému a žádný modul do něj nemůže kreslit.

## Přehled symbolů

Stiskněte **Symboly** v prohlížeči a získáte nadpisy dokumentu, vnořené tak, jak jsou zapsané; kliknutím na jeden na něj na stránce přeskočíte. Funguje ve formátovaném pohledu i ve zdrojovém textu a oba se shodují na tom, kde nadpis je.

## Diagramy a matematika

Blok kódu s jazykem `mermaid` se stane diagramem; `$…$` a `$$…$$` se stanou vysázenou matematikou. Obojí se kreslí **na vašem Macu**, nástroji dodanými uvnitř modulu — nic se nestahuje a žádná část dokumentu se nikam neposílá. Znak dolaru v bloku kódu nebo v kódu v řádku zůstává znakem dolaru.

Dokument bez diagramu a bez formule nenačte ani jeden nástroj, obyčejný README tedy nestojí nic navíc. Diagram, který nelze přečíst, zobrazí chybu tam, kde blok byl, s jeho vlastním textem pod ní, místo aby zmizel.

Obojí lze vypnout zvlášť v **Konfigurace ▸ Nastavení ▸ Markdown**, kde je také vidět, která verze se používá a odkud pochází.

## Vaše vlastní verze

Potřebujete-li novější nebo jinou verzi Mermaid či KaTeX, vložte ji do složky, kterou otevře tlačítko **Engine Folder…**, a použije se místo dodané. Jména souborů jsou `mermaid.min.js`, `katex.min.js`, `katex.min.css` a `auto-render.min.js`. Z internetu se pro vás nikdy nic nestahuje.

## Co formátovaná stránka neudělá

Formátovaná stránka je záměrně odříznutá, protože soubor Markdown je obsah, který přišel odjinud:

- **Nenačítá nic po síti.** Obrázek, jehož adresa začíná `http`, zůstane záměrně prázdný: jeho stažení by onomu serveru řeklo, kdy jste soubor otevřeli a z jaké adresy. Obrázek ležící vedle dokumentu na disku se načte normálně.
- **Vlastní skripty a HTML dokumentu se nikdy nespustí.** HTML zapsané v souboru Markdown se zobrazí jako text a soubor `.html` se zobrazí s vypnutými skripty.

## Vypnutí

Vypněte modul v **Konfigurace ▸ Zásuvné moduly…** a soubory `.md` a `.html` se otevřou jako text. Přehled dál funguje, barvení syntaxe dál funguje a nic jiného se nemění — formátovaný pohled se prostě už nenabízí. Totéž platí, pokud na stránce nastavení modulu vypnete jen formátovaný pohled.

## Omezení

- Soubory nad limitem velikosti (výchozí 8 MB, na stránce nastavení) se otevřou jako text. Proměnit velmi velký generovaný dokument ve formátovanou stránku je pomalé a textový prohlížeč jej otevře hned.
- Formátovanou stránku nelze editovat. Použijte k tomu F4 nebo pohled Text pro **Formátovat**, **Kódování** a **Přejít na**, které platí pro zdrojový text, ne pro vykreslenou stránku.
