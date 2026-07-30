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

## Hledání, nahrazování a navigace

- Stiskem Cmd+F otevřete lištu hledání. Chcete-li nahradit text, otevřete lištu hledání a přepněte ji na zobrazení nahrazování, nebo klepněte na Hledat/Nahradit na panelu nástrojů.
- Klepnutím na Formátovat JSON/XML znovu odsadíte dokument JSON nebo XML do čistého, čitelného rozvržení.
- Klepnutím na Symboly (nebo stiskem Cmd+Shift+O) zobrazíte postranní panel, který uvádí třídy, funkce a metody ve vašem kódu. Klepnutím na položku na ni přeskočíte přímo.
- Stiskem Cmd+L přeskočíte na konkrétní řádek.
- Stiskem Cmd+\ přeskakujete mezi závorkou a jejím odpovídajícím protějškem.
- Klepnutím na tlačítko mapy zobrazíte nebo skryjete minimapu, zmenšený přehled celého souboru, na který můžete klepnout pro rolování.
- Použijte nabídku Kódování na panelu nástrojů, pokud byl soubor uložen v jiném než výchozím kódování textu.

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
