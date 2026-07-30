---
title: Kopírování souborů
slug: copying-files
section: Soubory a složky
order: 24
related: [moving-and-renaming, background-transfers]
---

Peach Commander je postaven kolem dvou panelů vedle sebe: jeden obsahuje soubory, se kterými pracujete, druhý je cíl. Kopírování vezme to, co je vybráno v aktivním panelu, a vloží kopii do složky zobrazené ve druhém panelu, přičemž originály ponechá na místě. Toto je nejrychlejší způsob, jak duplikovat soubory a složky mezi dvěma umístěními bez přetahování.

## Zkopírování výběru do druhého panelu

1. V jednom panelu otevřete složku, která obsahuje položky, jež chcete zkopírovat.
2. Ve druhém panelu otevřete složku, kam mají kopie směřovat.
3. Vyberte soubory a složky ke zkopírování. Pokud není nic vybráno, použije se položka pod kurzorem.
4. Stiskněte F5. Otevře se dialog kopírování s již vyplněnou cílovou cestou.

![Dialog kopírování s cílovou cestou a možnostmi](screenshots/copy-dialog.png)
*(Obrázek: Dialog kopírování. Cílová cesta míří na druhý panel; možnostmi vyladíte kopírování.)*

5. V případě potřeby upravte cíl a poté potvrzením zahajte kopírování.

## Možnosti kopírování

Než potvrdíte, můžete změnit chování kopírování:

- **Pouze novější soubory** — přeskočí každou položku, jejíž kopie již existuje a je stejně stará nebo novější, takže se aktualizují jen změněné soubory.
- **Zachovat metadata** — u kopií zachová data, oprávnění a další atributy souborů. Toto je ve výchozím nastavení zapnuto.
- **Omezení rychlosti** — omezí přenosovou rychlost, aby rozsáhlé kopírování nezahltilo váš disk nebo síťové připojení.
- **Maska přejmenování** — do cílového pole zadejte zástupný vzor (například `*.bak`) k přejmenování položek při kopírování.

Úlohu můžete také namísto sledování odeslat do fronty na pozadí — viz Přenosy na pozadí.

## Průběh

Okno průběhu zobrazuje aktuální soubor a celkovou úlohu se samostatnými ukazateli, plus přenosovou rychlost. Kdykoli můžete pozastavit a obnovit nebo probíhající kopírování odeslat do správce přenosů na pozadí, abyste mohli během jeho dokončování dále pracovat.

![Dialog průběhu přenosu s ukazatelem průběhu, počty souborů a bajtů a tlačítky Pozastavit a Zrušit](screenshots/progress-dialog.png)
*(Obrázek: Dialog průběhu zobrazený během kopírování nebo přesunu.)*

## Řešení souborů, které již existují

Pokud by kopírování nahradilo existující soubor, Peach Commander se zastaví a zeptá se, co dělat. Náhled obou souborů vám pomůže rozhodnout se.

![Dialog konfliktu přepsání porovnávající dva soubory](screenshots/overwrite-dialog.png)
*(Obrázek: Dialog přepsání porovnává existující soubor s tím, který se kopíruje.)*

Vaše možnosti zahrnují:

- **Přepsat** existující soubor nebo **Přepsat vše** k použití na každý zbývající konflikt.
- **Přeskočit** tento soubor nebo **Přeskočit vše** u zbývajících konfliktů.
- **Přejmenovat** příchozí kopii automaticky, aby byly zachovány oba soubory.
- **Připojit** příchozí data na konec existujícího souboru.
- Přepsat pouze tehdy, když je zdroj **novější** nebo **větší** než existující soubor.

## Klávesové zkratky

| Akce | Klávesa |
|---|---|
| Zkopírovat výběr do druhého panelu | F5 |
| Zkopírovat ve stejné složce (vytvořit přejmenovanou kopii) | Shift+F5 |
| Otevřít správce přenosů na pozadí | Cmd+Shift+B |

## Poznámky

- Kopírování mezi dvěma umístěními na stejném disku používá rychlé klonování, pokud jej disk podporuje, takže se velké soubory zkopírují téměř okamžitě a spotřebují málo místa navíc.
- Složky se kopírují se vším, co je uvnitř.
- Chcete-li soubory přesunout namísto zkopírování, použijte F6. Ke sledování nebo správě úloh ve frontě otevřete správce přenosů na pozadí pomocí Cmd+Shift+B.
