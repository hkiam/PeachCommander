---
title: Hledání souborů
slug: searching
section: Hledání souborů
order: 60
related: [selecting-files, quick-search-and-filter]
---

Když potřebujete vystopovat soubory kdekoli na svém Macu — podle názvu, podle toho, co obsahují, nebo podle velikosti a data — použijte okno Najít soubory. Prohledává jednu nebo více složek (a jejich podsložky), umí nahlédnout dovnitř textových souborů a archivů a umožňuje odeslat vše, co najde, rovnou do panelu, takže s výsledky můžete pracovat jako s obyčejnou složkou.

## Hledání souborů podle názvu

1. V panelu zobrazujícím složku, kterou chcete prohledat, zvolte **Příkazy > Najít soubory…** (nebo stiskněte Cmd+Shift+F).
2. Na kartě **Obecné** zadejte vzor názvu do pole **Hledat**. Můžete použít zástupné znaky jako `*.pdf` nebo `zprava_*.docx`. Chcete-li prohledat více složek najednou, uveďte je v poli počáteční složky oddělené středníkem (`;`).
3. Klepněte na **Start**. Shody se objevují v seznamu výsledků níže, jak jsou nalezeny.
4. Poklepáním na kterýkoli výsledek přeskočíte na ten soubor v aktivním panelu, nebo vyberte výsledek a klepněte na **Zobrazit** (F3), abyste jej otevřeli ve vestavěném prohlížeči.

![Okno Najít soubory na kartě Obecné zobrazující vzor názvu, složku a seznam výsledků](screenshots/find-files-general.png)
*(Obrázek: karta Obecné — hledání podle vzoru názvu napříč jednou nebo více složkami.)*

## Hledání podle obsahu, velikosti a data

1. Chcete-li hledat uvnitř souborů, zadejte text do pole **Najít text** na kartě Obecné — hledá se to, co je v poli, prázdné pole hledá jen podle názvů. Možnosti umožňují učinit jej **rozlišujícím velikost**, shodovat se jen s **celým slovem**, zacházet s textem jako s **regulárním výrazem**, provést **hexadecimální hledání obsahu** nebo najít soubory, které text **neobsahují**.
2. Přepněte na kartu **Pokročilé** pro zúžení výsledků podle **velikosti** (například `10K` až `5M`), podle rozsahu **data změny** nebo na soubory změněné za posledních N dní.
3. Zapněte **Hledat uvnitř archivů** pro nahlédnutí do archivů rodiny zip (zip, jar, war a podobné).
4. Chcete-li omezit hledání jen na to, co jste už vybrali, zapněte před spuštěním **Hledat jen ve vybraných položkách**.
5. Zapněte **Hledat i v komentářích souborů** a text se bude hledat vedle obsahu také v komentáři každého souboru. Tak najdete soubor znovu podle toho, co jste o něm napsali — „originál zákazníka“, „nahrazeno exportem 2026“ —, když v samotném souboru nic takového není. Takto nalezený výsledek zobrazí komentář místo řádku souboru a žádné číslo řádku, protože nález neleží v textu souboru. Velikost písmen, celé slovo i regulární výrazy platí pro komentář stejně jako pro obsah; hexadecimální hledání ne, neboť komentář je napsaný text. **Neobsahující** zůstává bezesporné: soubor se vypíše, když text není ani v obsahu, ani v komentáři. Je-li zapnutý modul Poznámky, je jeho poznámka dostupná jako obsahové pole, na které lze v části **Plugins** nasadit podmínku — viz [Práce s moduly](plugins.md).
6. Některé zásuvné moduly umí ze souboru udělat text, který sám soubor neobsahuje — modul dekompilátoru udělá z `.class` zdrojový kód Javy. Zapněte **Hledat v textu od zásuvných modulů** a takové soubory se prohledávají jako ten text, ne jako vlastní bajty, takže obrat ze zdrojového kódu se najde ve zkompilované třídě. Volba se objeví jen tehdy, je-li takový modul nainstalován, a je pomalejší: vytvoření textu může znamenat jeden dekompilátor na soubor.

![Okno Najít soubory na kartě Pokročilé zobrazující filtry velikosti a data](screenshots/find-files-advanced.png)
*(Obrázek: karta Pokročilé — filtrujte podle velikosti, data a dalších atributů.)*

Pokud máte zásuvné moduly, které přidávají pole obsahu (jako rozměry obrázků), karta **Zásuvné moduly** umožňuje vyžadovat, aby pole odpovídalo podmínce — například jen obrázky širší než 1000 pixelů.

![Okno Najít soubory na kartě Zásuvné moduly zobrazující podmínku pro pole obsahu](screenshots/find-files-plugins.png)
*(Obrázek: karta Zásuvné moduly — shoda podle polí obsahu poskytnutých zásuvnými moduly.)*

## Rychlá hledání se Spotlightem

U místních složek, které macOS už zaindexoval, zapněte **Použít Spotlight** na kartě Obecné pro téměř okamžité výsledky. Spotlight prohledává index místo skenování souborů, takže ignoruje regulární výrazy, limity hloubky podsložek a rozsah jen-vybrané.

## Opětovné použití a předání výsledků

- **Poslat do seznamu** umístí každý výsledek do aktivního panelu jako dočasný seznam, takže můžete zkopírovat, přesunout nebo smazat celou sadu najednou.
- Na kartě **Načíst / Uložit** zvolte **Uložit jako šablonu…** pro uložení aktuálního hledání (vzory a možnosti) a jeho pozdější opětovný výběr ze seznamu šablon.
- **Hledat** a **Najít text** si pamatují posledních 20 použitých výrazů, naposledy použité první — klepnutím na šipku na konci pole některý z nich vyberete znovu. Dvakrát použitý výraz se vrátí nahoru, místo aby se objevil dvakrát, a seznamy přežijí zavření okna i ukončení aplikace. **Vymazat historii…** na kartě **Načíst / Uložit** zapomene oba; uložených šablon se to netýká.

## Zkratky

| Akce | Zkratka |
| --- | --- |
| Otevřít Najít soubory | Cmd+Shift+F nebo Option+F7 |
| Spustit / zastavit hledání | Tlačítko Start v okně |
| Zobrazit vybraný výsledek | F3 |

## Poznámky

- Hledání obsahu čte celé soubory u místních složek; na jiných umístěních se velmi velké soubory přeskočí (zhruba 16 MB, nebo 64 MB při použití regulárního výrazu).
- Hledání uvnitř archivů sestupuje až do čtyř úrovní vnořených archivů.
- **Zahrnout složky do výsledků** rovněž uvádí složky, jejichž názvy odpovídají, nejen soubory.
- Spotlight pokrývá jen zaindexované místní složky; pro síťová umístění nebo shodu podle vzoru jej nechte vypnutý a nechte Najít soubory skenovat.
