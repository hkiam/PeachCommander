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

Klepnutím pravým tlačítkem na řádek se podíváte na soubory, které za ním stojí. **Porovnat** otevře obě strany vedle sebe, **Zobrazit levý soubor** a **Zobrazit pravý soubor** otevřou jednu stranu samostatně v prohlížeči — to je odpověď pro řádek, který existuje jen na jedné straně a kde není co porovnávat. Položky, které pro daný řádek nemají smysl, jsou zašedlé, místo aby nic nedělaly. Soubor v archivu `.zip` nebo na serveru se nejprve rozbalí či stáhne do temporární kopie určené jen ke čtení, takže originál zůstane nedotčen. Totéž platí pro **Porovnat**, takže složku lze porovnat s archivem či serverem — a tlačítka pro převzetí a uložení zůstanou pro takovou stranu vypnutá, protože otevřená je tam kopie.

## Porovnání dvou souborů podle obsahu

1. Vyberte jeden soubor v každém panelu (nebo dva soubory ve stejném panelu).
2. Zvolte **Soubor ▸ Porovnat podle obsahu…**.
3. Oba soubory se otevřou vedle sebe se zvýrazněnými rozdíly. Pomocí ovládacích prvků další/předchozí přeskakujte mezi změněnými bloky.
4. Zapnete-li režim úprav, můžete kterýkoli soubor přímo upravit a změny uložit.

![Okno porovnání zobrazující dva textové soubory vedle sebe se zvýrazněnými odlišnými řádky](screenshots/diff-window.png)
*(Obrázek: Porovnání dvou textových souborů; změněné řádky jsou zvýrazněny na obou stranách.)*

Pokud mezi soubory nejsou žádné rozdíly, okno to řekne barevným pásem v horní části, místo aby vás nechalo usoudit to z tabulky, v níž není nic zvýrazněno. Pás se objeví i ve výstražné barvě, když některý soubor nešlo vůbec přečíst — pak by jakýkoli verdikt o rozdílech byl tvrzení o porovnání, které se nikdy nekonalo. Porovnání po bajtech říká totéž ze stejného důvodu: dva soubory, které nelze otevřít, nejsou dva totožné soubory.

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
- Nic se nemaže na základě nepřítomnosti, kterou srovnání nemohlo potvrdit — nečitelná složka nebo
  složka, kterou zadržel filtr, nedokazuje nic o tom, co je uvnitř.
- Jen dvě složky na tomto Macu. Ne server a ne archiv: smazání v archivu jej přepíše, smazání na
  serveru je nevratné, a tento režim není ten, se kterým to zkoušet.

**Smazání nelze vzít zpět.** Na tomto Macu jde soubor do Koše a lze jej vrátit ve Finderu; to je celá
záchranná síť. **Paměť…** v okně vypíše každý pár, který si aplikace pamatuje, zvýrazní ten otevřený a umožní kterýkoli z nich zapomenout — poté se další srovnání těch složek zachová opět jako první. Samo se nikdy nic nezapomene: složka na odpojeném disku není pryč, jen není zapojená.

Záznam leží u nastavení: přesunete-li jednu ze složek, pár už žádnou historii nemá — a
běh bez historie nic nemaže.

## Co běh udělal a co z toho lze vzít zpět

Každá synchronizace se zapisuje. **Běhy…** v okně je vypisuje od nejnovějších — kdy, které dvě složky, který režim a kolik souborů bylo zkopírováno, smazáno nebo zadrženo — a u vybraného běhu ukazuje, co se stalo s každým souborem.

Právě tento seznam dělá Koš použitelným. Soubor, který tento Mac smazal, skončil v Koši, a běh si zapsal *kde*, což znamená víc, než to zní: Koš při kolizi přejmenovává, takže druhá `notes.txt` přistane jako `notes.txt 11-17-15-028.txt`, a kdo ji hledá podle jména, najde tu špatnou. **Zobrazit v Koši** namíří Finder přímo na položku.

**Vrátit zpět…** přesune soubory, které běh smazal, z Koše na cesty, ze kterých byly smazány. Každý se nejdřív zkontroluje a to, co neplatí, je odmítnuto s vlastním důvodem místo vynucení:

- Na té cestě už zase něco je. Zůstane nedotčeno — vrácení nesmí nikdy přepsat.
- Položka už v Koši není, nebo byla smazána trvale místo toho, aby tam byla přesunuta.
- Strana byla archiv nebo server. Archiv se přepisuje celý a server žádný Koš nemá, takže se nic
  neuchovalo.
- Složka, do které běh zapisoval, je pryč, nebo to už není tatáž složka — třeba znovu použitý
  přípojný bod. Pak je odmítnut celý běh místo toho, aby se provedla jeho část.
- Už to bylo vráceno. Záznam si to pamatuje, takže druhý pokus neudělá nic.
- Nebo je sám záznam takový, se kterým tato verze neumí pracovat — zapsaný novější verzí aplikace,
  nebo uvádí cestu mimo obě složky. Vzácné, a odmítnuté místo dohadování.

**Kopii vzít zpět nelze.** Odstranit ji by znamenalo smazat soubor, který jste mezitím mohli upravit, což je opačný obchod než vrácení smazání, takže to aplikace nenabízí — běh vám řekne, které soubory zkopíroval, a smazat je můžete sami. Soubor, který byl *přepsán*, je jediná skutečná mezera, a je už malá: na tomto Macu jde nahrazená verze do Koše jako smazaný soubor, takže ji **Zobrazit v Koši** najde. Do archivu, na server ani na svazek bez Koše to nejde, a potvrzení to řekne před během.

Uchovává se posledních 200 běhů, nebo 64 MB z nich, podle toho, co nastane dřív; nad to nejstarší postupně odpadají, jak přibývají nové, a **Zapomenout** i **Zapomenout vše** je uklidí na místě. Velmi velký běh — přes 20 000 souborů — si ponechá každý problém a všechno, co dal do Koše, ale ne kopie, které prošly, a řekne to místo toho, aby vás to nechal zjistit. Jeho smazání lze stále vrátit: vynechány byly kopie, a kopii by stejně nešlo vzít zpět.

Zapomenutí nemění nic na složkách; zmizí záznam o tom, co se udělalo, a s ním nabídka něco vrátit. Na rozdíl od oboustranné paměti se tohle zahazuje automaticky — ztratit paměť *dvojice* by změnilo, co udělá další běh, zatímco ztráta záznamu o běhu jen bere jednu nabídku.

## Klávesové zkratky

| Akce | Zkratka |
| --- | --- |
| Porovnat výpisy adresářů (označit odlišné soubory) | Shift+F2 |
| Porovnat podle obsahu | Soubor ▸ Porovnat podle obsahu… |
| Synchronizovat adresáře | Příkazy ▸ Synchronizovat adresáře… |
| Zobrazit jednu stranu řádku synchronizace | Pravé tlačítko na řádek ▸ Zobrazit levý soubor / Zobrazit pravý soubor |

## Poznámky

- **Podle obsahu vs. podle data/velikosti.** Rychlé porovnání srovnává soubory podle velikosti a data úpravy, což je rychlé, ale dá se oklamat, když se u shodných souborů liší časové značky. Zapněte **podle obsahu** pro spolehlivý výsledek za cenu čtení každého souboru.
- **Podsložky a filtry.** Okno synchronizace umí sestoupit do podsložek a lze jej omezit maskou filtru, takže můžete synchronizovat jen typy souborů, na kterých vám záleží.
- **Máte vše pod kontrolou.** Synchronizace nikdy neběží sama od sebe — navržené směry zkontrolujete ve výsledné mřížce a kterýkoli z nich můžete před zkopírováním čehokoli změnit.
- **Předvolby.** Často používaná nastavení synchronizace lze uložit a znovu použít, takže nemusíte pokaždé znovu zadávat stejné možnosti.
