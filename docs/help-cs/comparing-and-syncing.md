---
title: Porovnávání a synchronizace
slug: comparing-and-syncing
section: Pokročilé nástroje
order: 90
related: [multi-rename]
---

Když udržujete dvě kopie stejné složky — pracovní složku a zálohu, notebook a síťové sdílení, projekt a jeho archiv — Peach Commander vám pomáhá přesně vidět, co se změnilo, a obě strany opět sladit. Můžete synchronizovat dva adresáře, porovnávat jednotlivé soubory řádek po řádku a zkoumat soubory bajt po bajtu, když potřebujete jistotu až do posledního znaku.

## Synchronizace dvou adresářů

1. Otevřete složku, kterou chcete synchronizovat, v levém panelu a složku, se kterou ji chcete porovnat, v pravém panelu.
2. Zvolte **Příkazy ▸ Synchronizovat adresáře…**. Obě cesty ke složkám se vyplní z vašich panelů.
3. Nastavte, jak důkladné má porovnání být: zahrnout podsložky, porovnat **podle obsahu** (nejen podle data a velikosti) nebo ignorovat datum úpravy.
4. Přidejte masku filtru (například `*.jpg;*.png`), pokud chcete synchronizovat jen určité soubory.
5. Prohlédněte si výslednou mřížku. Každý řádek zobrazuje soubor vlevo, směrovou šipku uprostřed a odpovídající soubor vpravo. Šipky vám říkají, co se stane: **→** kopíruje zleva doprava, **←** kopíruje zprava doleva a **=** znamená, že jsou oba shodné.
6. Upravte jednotlivé řádky, pokud s navrženým směrem nesouhlasíte, a poté kliknutím na tlačítko synchronizace změny proveďte.

![Okno synchronizace adresářů se dvěma cestami ke složkám a výslednou mřížkou souborů se šipkami vlevo, rovná se a vpravo](screenshots/sync-dialog.png)
*(Obrázek: Okno Synchronizovat adresáře porovnává obě strany a pro každý soubor navrhuje směr kopírování.)*

## Porovnání dvou souborů podle obsahu

1. Vyberte jeden soubor v každém panelu (nebo dva soubory ve stejném panelu).
2. Zvolte **Soubor ▸ Porovnat podle obsahu…**.
3. Oba soubory se otevřou vedle sebe se zvýrazněnými rozdíly. Pomocí ovládacích prvků další/předchozí přeskakujte mezi změněnými bloky.
4. Zapnete-li režim úprav, můžete kterýkoli soubor přímo upravit a změny uložit.

![Okno porovnání zobrazující dva textové soubory vedle sebe se zvýrazněnými odlišnými řádky](screenshots/diff-window.png)
*(Obrázek: Porovnání dvou textových souborů; změněné řádky jsou zvýrazněny na obou stranách.)*

## Porovnání souborů bajt po bajtu

Když dva soubory vypadají stejně, ale potřebujete dokázat, že jsou skutečně shodné (nebo najít ten jeden odlišný bajt), použijte binární porovnání. Zobrazí oba soubory v šestnáctkovém zobrazení s označenými neshodujícími se bajty, což je ideální k ověření stahování, kontrole zakódovaných dat nebo potvrzení přesné kopie.

## Porovnání výpisů adresářů

K rychlému odhalení rozdílů mezi dvěma otevřenými složkami zvolte **Označit ▸ Porovnat adresáře** (Shift+F2). Peach Commander označí soubory, které se liší nebo na druhé straně chybí, takže s nimi můžete pracovat pomocí obvyklých příkazů kopírování, přesunu a mazání.

## Omezení toho, co synchronizace zahrnuje

Pole masky nese jeden seznam zahrnutí přes jména souborů. Pro to, co se tím říci nedá, otevře **Filtr…** vedle něj list se třemi kartami. Co se tam nastaví, platí pro *následující* srovnání a tlačítko pak říká, kolik kritérií je aktivních — filtr, který není vidět, je způsob, jak záloha skončí neúplná, zatímco okno hlásí, že je hotovo.

- **Vynechat** bere vzory oddělené `;` nebo `|`. Jméno bez lomítka platí v každé hloubce (`*.tmp`), lomítko na konci znamená složku i vše v ní (`node_modules/`) a vzor s lomítkem platí na relativní cestu (`src/*/generated`). Na velikosti písmen nezáleží.
- **Velikost** a **datum** posuzují pár jako celek: vypadne-li jedna strana z rozsahu, zůstane mimo celý pár. Je to úmysl. Použito na jedinou stranu, vynechání by pár vypadalo jednostranně a změnilo by se v kopírování špatným směrem.
- **Za posledních N dní** se měří od každého srovnání, ne od uložení předvolby — uložená úloha tedy dál znamená „poslední měsíc“.
- Karta **Zásuvné moduly** se ptá obsahového modulu na tu stranu, ze které by se soubor kopíroval. Potřebuje skutečný soubor, takže se nabízí jen tehdy, když jsou obě strany složkami na tomto Macu.

Vynechaná složka se nemaže ani v režimu zrcadla — zrcadlo odstraňuje jen to, co skutečně srovnávalo. Stavový řádek říká, kolik položek filtr zadržel, vedle toho, co běh udělá. Filtr se ukládá a načítá spolu s předvolbou synchronizace, ke které patří.

## Držet dvě složky shodné, oběma směry

Dva původní režimy neumějí rozlišit jednu věc: soubor, který je jen na jedné straně, je buď **zde
nový**, nebo **tam smazaný**, a obojí vypadá stejně. Symetrický režim jej proto zkopíruje — smažete
něco na notebooku, synchronizujete, a vrátí se ze zálohy — a zrcadlový režim maže, ale jen v jednom
směru.

**Obousměrně (s pamětí)** si pamatuje, jak obě složky vypadaly, když se naposledy shodovaly. S tímto
záznamem lze smazání na jedné straně přenést na druhou.

- **První** běh páru žádný záznam nemá: chová se jako dřív a nic nemaže. Záznam zapíše. Od druhého
  běhu režim funguje.
- Přenesené smazání se zobrazí vlastní barvou s `⇒🗑` a **není** zaškrtnuté: je to jediný řádek, který
  pochází z paměti aplikace. Kliknutí na šipku nabídne ostatní odpovědi: zkopírovat soubor zpět, nebo
  ponechat obě strany být.
- Změněno na jedné straně a smazáno na druhé je **konflikt**, nikdy smazání. Stejně tak soubor
  změněný na obou stranách.
- Nic se nemaže na základě nepřítomnosti, kterou srovnání nemohlo potvrdit.
- Jen dvě složky na tomto Macu, ne server a ne archiv.

**Smazání nelze vzít zpět.** Na tomto Macu jde soubor do Koše a lze jej vrátit ve Finderu; to je celá
záchranná síť. Záznam leží u nastavení: přesunete-li jednu ze složek, pár už žádnou historii nemá — a
běh bez historie nic nemaže.

## Klávesové zkratky

| Akce | Zkratka |
| --- | --- |
| Porovnat výpisy adresářů (označit odlišné soubory) | Shift+F2 |
| Porovnat podle obsahu | Soubor ▸ Porovnat podle obsahu… |
| Synchronizovat adresáře | Příkazy ▸ Synchronizovat adresáře… |

## Poznámky

- **Podle obsahu vs. podle data/velikosti.** Rychlé porovnání srovnává soubory podle velikosti a data úpravy, což je rychlé, ale dá se oklamat, když se u shodných souborů liší časové značky. Zapněte **podle obsahu** pro spolehlivý výsledek za cenu čtení každého souboru.
- **Podsložky a filtry.** Okno synchronizace umí sestoupit do podsložek a lze jej omezit maskou filtru, takže můžete synchronizovat jen typy souborů, na kterých vám záleží.
- **Máte vše pod kontrolou.** Synchronizace nikdy neběží sama od sebe — navržené směry zkontrolujete ve výsledné mřížce a kterýkoli z nich můžete před zkopírováním čehokoli změnit.
- **Předvolby.** Často používaná nastavení synchronizace lze uložit a znovu použít, takže nemusíte pokaždé znovu zadávat stejné možnosti.
