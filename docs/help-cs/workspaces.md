---
title: Pracovní plochy
slug: workspaces
section: Přizpůsobení
order: 118
related: [settings, panels-and-tabs]
---

Pracovní plocha je pojmenovaná souvislost, ve které pracujete: „Úklid záloh“, „Třídění podkladů uchazečů“. Každá si pamatuje oba panely, všechny otevřené panely karet, která karta je na které straně aktivní, režim zobrazení, strom složek, historii zpět/vpřed i které soubory jste měli označené, rychlý filtr i uspořádání okna — postranní panel, dok, lišty a polohu dělicí čáry. Přepnutí stojí jedno kliknutí a cestou se nikdy nic neztratí — pracovní plocha se nikdy neukládá, protože nikdy nekončí.

Dokud nevytvoříte druhou, není co vidět. Žádná lišta, žádná nabídka, žádné zkratky.

## Jak na to

1. Připravte oba panely pro úkol, který máte před sebou: otevřete složky, přidejte karty, zvolte požadované zobrazení.
2. Otevřete nabídku **Přejít** a zvolte **Pracovní plochy…**, poté **Nová pracovní plocha…**. Pojmenujte ji.
3. V horní části okna se objeví pruh barevných štítků a v nabídkové liště se objeví nabídka **Pracovní plocha**. Nová pracovní plocha začíná jako kopie uspořádání, ve kterém jste byli.
4. Připravte novou pracovní plochu pro její vlastní úkol. Ta, ze které jste přišli, si ponechá, co měla.
5. Klikněte na štítek pro přepnutí, nebo stiskněte **Ctrl+1** až **Ctrl+9**. Přepne se všechno.

## Návrat k výchozímu stavu

Každá pracovní plocha si navíc pamatuje uspořádání, se kterým byla založena. **Pracovní plocha ▸ Uložit aktuální stav do pracovní plochy** (Cmd+Ctrl+S) udělá z aktuálního uspořádání tento výchozí stav a **Obnovit uložený stav** vás tam po odpoledni bloudění vrátí.

To je nezávislé na průběžném pamatování: nikdy nemusíte ukládat, abyste neztratili své místo.

## Odkladiště

Každá pracovní plocha má odkladiště — pro to, co se při úklidu opravdu stává: tři složky hluboko v
zálohách najdete něco, co patří k úplně jinému tématu. **Přetáhněte soubory na štítek jiné pracovní
plochy** a přistanou v *jejím* odkladišti: nepřepínáte a nic se nekopíruje ani nepřesouvá; počítadlo na
štítku stoupne a vy pokračujete. Při puštění podržte **⌥**, chcete-li místo toho kopírovat do složky
oné plochy, nebo **⌘** pro přesun. **Ctrl+Cmd+A** vloží výběr do odkladiště aktuální plochy, stránka
**Odkladiště** v postranním panelu ukáže obsah a **Pracovní plocha ▸ Kopírovat odkladiště do druhého
panelu** zvládne celé odkladiště jednou operací.

Soubory mezitím smazané, nebo ležící na nepřipojeném svazku, se zobrazují jako chybějící, místo aby
byly odebrány, a hromadná operace nabídne je přeskočit nebo je nejdřív z odkladiště vyjmout. Přesun
odkladiště o přesunuté vyprázdní; kopírování ho nechá, jak bylo.

| Akce | Zkratka |
| --- | --- |
| Přepnout na pracovní plochu 1 až 9 | Ctrl+1 … Ctrl+9 |
| Udělat z aktuálního uspořádání výchozí stav | Cmd+Ctrl+S |

## Tipy

- Klikněte na štítek pravým tlačítkem a přejmenujte jej, dejte mu barvu nebo jej smažte — nebo klikněte na **✕** u jeho pravého okraje, které pracovní plochu po dotazu smaže. Barva je to, podle čeho pracovní plochy poznáte na první pohled, když je okno úzké a názvy se už nevejdou.
- Devět je mez, aby každý štítek zůstal rozpoznatelný.
- **Zobrazit ▸ Zobrazit lištu pracovních ploch** skryje pruh, aniž by funkci vypnul — pro ty, kdo mezi pracovními plochami přepínají klávesnicí.
- Pracovní plochy lze zcela vypnout v **Nastavení ▸ Karty**. Vaše pracovní plochy zůstanou zachovány a vrátí se beze změny, až funkci znovu zapnete.

## Omezení pracovní plochy na složku

Pracovní ploše lze říct, čeho se týká, a ta pak kontroluje, než operace sáhne mimo. Klikněte pravým
tlačítkem na její štítek, **Omezit na složku ▸ Nastavit na aktivní složku**, a zvolte, zda mají být
operace mimo povoleny, dotazovány, nebo odmítány.

Kontroluje se, než smazání vezme soubory zvenčí, než kopírování nebo přesun přistane mimo a než
přejmenování nebo nová složka zapíše mimo. **Navigace se nikdy neomezuje** — správce souborů, který
odmítá ukázat složku, je rozbitý, a celá hodnota je v okamžiku před F8. Uložení v editoru rovněž
zahrnuta nejsou; dějí se ve vlastním okně.

## Deník

Každá pracovní plocha si vede záznam o tom, co se v ní dělalo — navštívené složky, provedené operace,
napsané řádky shellu a vše, co omezení složkou odmítlo. **Pracovní plocha ▸ Deník…** jej ukáže,
nejnovějším dnem počínaje, s filtrem **Problémy** pro vše, co selhalo nebo bylo zastaveno.

Return zopakuje vybraný řádek podle stejného pravidla jako historie: jedním stiskem lze zopakovat jen
kopírování nebo přesun a řádek shellu se vloží do příkazového řádku místo spuštění. Deník je záměrně
oddělen od globální historie — ta odpovídá na „kam obvykle chodím“ a řadí podle četnosti; tento
odpovídá na „co se tu stalo“ a zachovává pořadí. Maže se se svou pracovní plochou, jinak se uchovává
bez omezení, a lze jej vypnout v **Nastavení ▸ Karty**.

## Předání pracovní plochy

**Pracovní plocha ▸ Exportovat pracovní plochu…** zapíše aktuální pracovní plochu do souboru
`.pcworkspace`, který můžeš někomu poslat nebo si ho nechat ve složce projektu. **Importovat pracovní
plochu…** ho načte zpět a dvojklik ve Finderu také.

Cestuje **uložený výchozí stav** pracovní plochy — stiskni nejdřív ⌘⌃S, pokud to má být uspořádání,
které máš právě před sebou — spolu s názvem, barvou, omezením složkou a odkladištěm. Složky uvnitř
tvé domovské složky se zapisují zkráceně, aby se soubor otevřel v domovské složce toho *druhého*, a
ne ve složce pojmenované po tobě.

Co záměrně necestuje:

- **Cokoli, co by mohlo být přihlašovací údaj.** Panely ukazující na připojení nebo připojený disk zásuvného modulu se při exportu odstraní a zpráva uvede kolik. Není co ztratit, protože o připojení se nic nezapisuje.
- **Deník.** Zaznamenává, co jsi dělal *ty*, a jmenuje složky na tvém počítači. Zůstává tady.
- Pozice kurzoru, historie zpětných kroků, velikost okna a otevřená okna prohlížeče, editoru, hledání či porovnání.
- Panely terminálu a rozhovory s asistentem. Patří k tomuto Macu; soubor pracovní plochy nese *kde* se pracuje, ne co běží.

Import pracovní plochu vždy **přidá**; nikdy nenahradí tu, ve které jsi, a nikdy sám nepřepne —
soubor, který někdo poslal, nemá přestavovat tvé okno. Složky, které na tomto Macu nejsou, se otevřou
na nejbližší existující, položky odkladiště si ponechají své cesty a jsou zobrazeny šedě a omezení
složkou, jehož složka chybí, zůstane zachováno, ale ptá se místo odmítání. Vše vypíše zpráva.

## Poznámky

- Přepnutí se nikdy neptá na uložení a nikdy nic nezavírá. Probíhající souborové operace pokračují a stejně tak vše v terminálu: karty pracovní plochy, kterou opouštíte, se odloží se živými shelly, nezavřou se. Také konverzace asistenta následují pracovní plochu.
- Zpět sleduje pracovní plochu jen po dobu běhu aplikace: krok zpět s sebou nese akci, která jej vrátí, a tu nelze zapsat na disk.
- Pracovní plocha si pamatuje umístění složek, nikoli soubory v nich. Pokud byla uložená složka přesunuta nebo smazána, otevře se ta karta v nejbližší složce, která ještě existuje.
- Při přechodu ze starší verze: pracovní plochy, které jste dříve uložili, se stanou štítky a relace, ve které jste byli, se stane první. Nic se neztratí a starý soubor `workspaces.ini` zůstane zachován jako `workspaces.ini.migrated`.
