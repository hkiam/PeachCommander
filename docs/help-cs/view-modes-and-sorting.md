---
title: Režimy zobrazení a řazení
slug: view-modes-and-sorting
section: Uspořádání zobrazení
order: 42
related: [panels-and-tabs, quick-search-and-filter]
---

Každý panel může zobrazit svou složku v rozvržení, které se hodí k úloze: podrobný seznam se sloupci, kompaktní víceslupcový seznam názvů, mřížka ikon, galerie s velkými náhledy nebo strom složek. Můžete také řadit seznam podle názvu, typu souboru, velikosti nebo data, zvolit přesně, které sloupce se zobrazí, a zapnout přirozené (číselné) řazení, aby se názvy s čísly seřadily tak, jak očekáváte. Režim zobrazení, pořadí řazení a sloupce se nastavují pro každý panel, takže obě strany mohou vypadat zcela odlišně.

## Změna režimu zobrazení

1. Klepnutím na panel, který chcete změnit, jej učiníte aktivním.
2. Otevřete nabídku Zobrazení a zvolte režim: **Úplný (Podrobnosti)** pro seznam se sloupci, **Stručný (Sloupce)** pro hustý víceslupcový seznam názvů, **Ikony** pro mřížku ikon, **Náhledy (Galerie)** pro velké náhledy nebo **Strom** pro strom složek.
3. Chcete-li rychle procházet režimy bez otevírání nabídky, stiskněte Cmd+Shift+M. Každý stisk přejde na další režim.

![Panel zobrazující různé režimy zobrazení: podrobnosti, stručný, ikony a galerie](screenshots/view-modes.png)
*(Obrázek: tatáž složka zobrazená jako podrobný seznam, stručný seznam sloupců, mřížka ikon a galerie náhledů.)*

## Řazení seznamu souborů

1. V zobrazení Podrobnosti klepnutím na záhlaví sloupce (Název, Typ, Velikost nebo Datum) řadíte podle něj. Malá šipka v záhlaví ukazuje aktuální sloupec a směr řazení.
2. Opětovným klepnutím na totéž záhlaví obrátíte pořadí.
3. Můžete také zvolit Zobrazení > Řadit podle a vybrat Název, Typ souboru, Velikost, Datum nebo Neseřazeno.

Složky se vždy řadí společně nahoře, před soubory, a položka `..`, která vás vezme o úroveň výš, se připne jako první. Řazení podle názvu nebo typu souboru je ve výchozím nastavení vzestupné (A až Ž); řazení podle velikosti nebo data je ve výchozím nastavení nejnovější nebo největší jako první.

## Volba zobrazených sloupců

1. Zvolte Konfigurace > Sloupce….
2. Zapněte nebo vypněte sloupce a nastavte jejich pořadí. Dostupné sloupce zahrnují Název, Typ, Velikost, Datum, Atr (atributy), Štítky a Komentář.
3. Použijte změny. Sloupce ovlivňují zobrazení Podrobnosti aktivního panelu.

![Okno konfigurace sloupců se seznamem dostupných sloupců](screenshots/columns-config.png)
*(Obrázek: zvolte, které sloupce se zobrazí v zobrazení Podrobnosti, a nastavte jejich pořadí.)*

## Zkratky

| Akce | Zkratka |
|---|---|
| Procházet režimy zobrazení | Cmd+Shift+M |
| Stručné (sloupce) zobrazení | Ctrl+F1 |
| Úplné (podrobnosti) zobrazení | Ctrl+F2 |
| Zobrazení náhledů (galerie) | Ctrl+Shift+F1 |
| Stromové zobrazení | Ctrl+F8 |
| Řadit podle názvu | Ctrl+F3 |
| Řadit podle typu souboru | Ctrl+F4 |
| Řadit podle velikosti | Ctrl+F5 |
| Řadit podle data | Ctrl+F6 |

## Tipy

- Přirozené (číselné) řazení je ve výchozím nastavení zapnuté, takže `file2` je před `file10` místo za ním. Můžete jej vypnout v Konfigurace > Možnosti v nastavení zobrazení.
- Sloupec můžete v zobrazení Podrobnosti rozšířit nebo zúžit přetažením dělicí čáry mezi záhlavími sloupců.
- Používáte-li klávesovou navigaci macOS (Nastavení systému ▸ Klávesnice), patří řada Ctrl+F1 až Ctrl+F8 systému — řádek nabídek, Dock, panel nástrojů — a k Peach Commanderu se nikdy nedostane. Přepněte v nastavení schéma kláves na **macOS**: režimy zobrazení jsou pak na Cmd+1, Cmd+2 a Cmd+3 a řazení na Alt+Cmd+1 až Alt+Cmd+4.
- Režim zobrazení, pořadí řazení a volba sloupců se pamatují pro každý panel, takže můžete mít jednu stranu jako podrobný seznam a druhou jako fotogalerii.
