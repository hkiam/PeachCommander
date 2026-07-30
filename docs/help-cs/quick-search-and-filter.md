---
title: Rychlé hledání a filtr
slug: quick-search-and-filter
section: Uspořádání zobrazení
order: 44
related: [searching, view-modes-and-sorting]
---

Když složka obsahuje stovky položek, jen zřídka potřebujete rolovat. Peach Commander umožňuje přeskočit rovnou na soubor napsáním jeho názvu (rychlé hledání), zúžit seznam jen na položky, které vás zajímají (rychlý filtr), a zobrazit nebo skrýt tečkové soubory, které macOS obvykle drží mimo dohled. Všechny tři fungují uvnitř aktivního panelu bez otevírání dialogu.

## Přeskok na soubor psaním (rychlé hledání)

1. Klepnutím na souborový panel jej učiníte aktivním.
2. Začněte psát začátek názvu. Kurzor přeskočí na první odpovídající položku.
3. Pokračujte v psaní pro zpřesnění shody, nebo stiskněte totéž písmeno znovu pro procházení položek začínajících tímto písmenem.
4. Napsaný text se po krátké pauze vymaže, takže nové hledání můžete začít kdykoli.

Ve výchozím nastavení jdou obyčejná písmena do příkazového řádku a rychlé hledání se spouští pomocí Ctrl+Option+písmeno (klasické chování). Rychlé hledání můžete přepnout tak, aby reagovalo na obyčejné psaní, nebo jej vypnout, v nastavení konfigurace.

## Filtrování seznamu (rychlý filtr)

1. V aktivním panelu stiskem Ctrl+S zapněte rychlý filtr.
2. Zadejte masku filtru. Panel se za psaní živě zúží na odpovídající položky.
3. Stiskem Esc filtr vymažete a znovu zobrazíte vše.

Filtr přijímá několik druhů masek:

- **Prostý text** odpovídá jakémukoli názvu, který obsahuje to, co jste napsali (například `zprava` zobrazí každou položku se slovem „zprava“ kdekoli v názvu).
- **Zástupné znaky** používají `*` (libovolné znaky) a `?` (jeden znak). Více masek oddělte středníkem a výjimky přidejte za svislou čáru, například `*.jpg;*.png|*thumb*` pro zobrazení obrázků, ale skrytí náhledů.
- **Štítky Finderu** filtrují podle barvy štítku: napište `tag:red` (nebo `#red`) pro zobrazení jen položek s červeným štítkem, nebo samotné `tag:` pro zobrazení všeho, co nese jakýkoli štítek.

## Zobrazení skrytých souborů

Stiskem Ctrl+H, nebo volbou příkazu z nabídky Zobrazení, přepnete skryté položky (názvy začínající tečkou a systémově skryté soubory). Nastavení platí pro aktivní panel a pamatuje se mezi relacemi.

## Zkratky

| Akce | Zkratka |
| --- | --- |
| Rychlé hledání (klasický režim) | Ctrl+Option+písmeno |
| Rychlý filtr zap./vyp. | Ctrl+S |
| Vymazat filtr / zrušit | Esc |
| Zobrazit/skrýt skryté soubory | Ctrl+H |

## Poznámky

- Rychlé hledání pouze pohybuje kurzorem; rychlý filtr skutečně mění, které položky jsou uvedeny. Filtr použijte, když chcete pracovat s podmnožinou (například vybrat nebo zkopírovat jen shody).
- Nastavení filtru a skrytých souborů jsou pro každý panel, takže obě strany mohou zobrazovat různé věci současně.
- Rychlé hledání porovnává názvy od začátku; režim prostého textu rychlého filtru porovnává kdekoli v názvu. Použijte zástupný znak jako `*text*`, chcete-li, aby se filtr choval stejně.
