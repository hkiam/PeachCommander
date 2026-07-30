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
