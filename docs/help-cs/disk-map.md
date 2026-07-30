---
title: Mapa disku
slug: disk-map
section: Zásuvné moduly
order: 121
related: [plugins, deleting-files, settings]
---

Mapa disku je vestavěný zásuvný modul, který na první pohled ukazuje, co zabírá místo ve složce nebo na celém svazku. Prohledá vámi zvolenou složku a vykreslí každou položku s velikostí úměrnou místu, které skutečně zabírá na disku, takže největší žrouti místa okamžitě vyniknou. Můžete se zavrtat do složek, vidět, jak se váš scan srovnává s volným, uvolnitelným a skrytým místem svazku, a uklidit rovnou z mapy.

## Zahájení scanu

1. V aktivním panelu přejděte do složky (nebo svazku), kterou chcete změřit.
2. Zvolte **Příkazy ▸ Mapa disku: Analyzovat aktuální složku**.
3. Zobrazení Mapa disku se otevře vpravo a prohledává na pozadí, přičemž ukazuje běžící počet položek a bajtů. Velké složky se dokončí za pár sekund — scan čte metadata adresářů hromadně a pracuje na několika jádrech CPU.

![Mapa disku zobrazující čtvercový treemap složky, pruh svazku, seznam největších souborů a legendu kategorií](screenshots/disk-map.png)
*(Obrázek: Zobrazení treemap obarvené podle kategorie souborů, s pruhem svazku nahoře a seznamem největších souborů vpravo.)*

## Čtení mapy

- Každý blok (treemap) nebo segment prstence (sunburst) má velikost podle **skutečné velikosti položky na disku**, takže obraz odpovídá tomu, co hlásí Finder a systém.
- Bloky jsou **obarveny podle typu souboru** — video, obrázky, zvuk, dokumenty, kód, archivy, aplikace, obrazy disků — s legendou podél spodního okraje. V nastavení lze přepnout na velikostní **teplotní mapu**.
- **Kliknutím na složku** se do ní zavrtáte; drobečková navigace nahoře ukazuje, kde jste, a tlačítko **◂** vás vrátí zpět nahoru.
- Najetím na kterýkoli blok zobrazíte jeho úplnou cestu, velikost a počet položek.

## Dvě zobrazení: treemap a sunburst

Mapa disku nabízí dvě vizualizace a můžete mezi nimi přepínat tlačítkem **◎ / ▦** v záhlaví nebo na stránce nastavení:

- **Treemap** — vnořené obdélníky, nejhustší pro odhalení jednotlivého největšího souboru.
- **Sunburst** — soustředné prstence (jeden pro každou hloubku složky) kolem aktuální složky, nejlepší pro sledování, jak je místo rozloženo napříč hlubokým stromem.

![Zobrazení sunburst Mapy disku ukazující soustředné prstence pro hloubku složky](screenshots/disk-map-sunburst.png)
*(Obrázek: Zobrazení sunburst — vnitřní kotouč je aktuální složka a každý prstenec je o úroveň hlouběji.)*

## Pruh svazku

Pruh přes horní okraj srovnává váš scan s celým svazkem:

- **Prohledáno / Tato složka** — kolik zabírá analyzovaná složka.
- **Skryté** (v kořeni svazku) nebo **Zbytek svazku** (u podsložky) — vše, co není v tomto scanu, včetně systémem chráněných složek, dalších uživatelů a snímků.
- **Uvolnitelné** — místo, které macOS umí automaticky získat zpět, převážně místní snímky Time Machine a mezipaměti.
- **Volné** — místo dostupné právě teď.

Když má svazek místní snímky, pruh zobrazuje prvek **· N snímků (ⓘ)**; kliknutím na něj zobrazíte seznam jen pro čtení s nápovědou, jak je spravovat v Diskové utilitě nebo Time Machine. Mapa disku snímky sama nikdy nemaže.

## Největší soubory

Zapnutím **Zobrazit seznam největších souborů** uvidíte největší soubory v aktuální složce seřazené podle velikosti, každý s barevným čipem pro svou kategorii. Kliknutím na jeden jej zvýrazníte na mapě.

## Úklid z mapy

Klikněte pravým tlačítkem na kterýkoli blok pro akce:

- **Otevřít v levém panelu** / **Otevřít v pravém panelu** — zobrazí položku v panelu souborů.
- **Zobrazit ve Finderu**.
- **Přesunout do Koše** — smaže jen tuto položku; mapa se aktualizuje bez úplného opětovného scanu.

K odstranění několika položek naráz použijte **Sběrač**: u každé položky klikněte pravým tlačítkem ▸ **Označit pro sběrač** a poté kliknutím na tlačítko **🗑 N** v záhlaví přesuňte vše, co jste označili, do Koše v jednom potvrzeném kroku.

## Nastavení

Mapa disku přidává vlastní stránku do okna Nastavení (**Konfigurace ▸ Nastavení ▸ Mapa disku**):

- **Styl grafu** — treemap nebo sunburst.
- **Barevné kódování** — podle typu souboru (kategorie) nebo podle velikosti (teplotní mapa).
- **Zůstat na výchozím svazku** — nepřecházet na jiné připojené disky.
- **Zobrazit pruh svazku** a **Zobrazit seznam největších souborů**.

Změny se u otevřené Mapy disku projeví okamžitě.

## Poznámky

- Mapa disku měří **alokovanou** velikost (na disku) a soubory spojené **pevným odkazem** počítá jen jednou, takže její součty odpovídají využitému místu svazku, místo aby je nadhodnocovaly.
- Ve výchozím nastavení scan zůstává na výchozím svazku, takže se nezatoulá na jiné připojené disky ani síťová sdílení.
