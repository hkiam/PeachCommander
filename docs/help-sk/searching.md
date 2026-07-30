---
title: Hľadanie súborov
slug: searching
section: Hľadanie súborov
order: 60
related: [selecting-files, quick-search-and-filter]
---

Keď potrebujete vystopovať súbory kdekoľvek na svojom Macu — podľa názvu, podľa toho, čo obsahujú, alebo podľa veľkosti a dátumu — použite okno Nájsť súbory. Hľadá v jednom alebo viacerých priečinkoch (a ich podpriečinkoch), dokáže nazrieť do textových súborov a archívov a umožňuje odoslať všetko, čo nájde, rovno do panela, takže na výsledkoch môžete konať, akoby to bol bežný priečinok.

## Nájdite súbory podľa názvu

1. V paneli, ktorý zobrazuje priečinok, ktorý chcete prehľadať, vyberte **Príkazy > Nájsť súbory…** (alebo stlačte Cmd+Shift+F).
2. Na karte **Všeobecné** zadajte vzor názvu do poľa **Hľadať**. Môžete použiť zástupné znaky ako `*.pdf` alebo `sprava_*.docx`. Na hľadanie vo viacerých priečinkoch naraz ich uveďte v poli počiatočného priečinka oddelené bodkočiarkou (`;`).
3. Kliknite na **Štart**. Zhody sa objavia v zozname výsledkov nižšie, ako sa nájdu.
4. Dvakrát kliknite na ktorýkoľvek výsledok na skok na ten súbor v aktívnom paneli, alebo vyberte výsledok a kliknite na **Zobraziť** (F3) na jeho otvorenie vo vstavanom prehliadači.

![Okno Nájsť súbory na karte Všeobecné zobrazujúce vzor názvu, priečinok a zoznam výsledkov](screenshots/find-files-general.png)
*(Obrázok: karta Všeobecné — hľadanie podľa vzoru názvu naprieč jedným alebo viacerými priečinkami.)*

## Hľadanie podľa obsahu, veľkosti a dátumu

1. Na hľadanie vnútri súborov vyberte **Nájsť text** na karte Všeobecné a zadajte hľadaný text. Možnosti umožňujú urobiť ho **rozlišujúcim veľkosť**, zhodovať sa len s **celým slovom**, zaobchádzať s textom ako s **regulárnym výrazom**, urobiť **šestnástkové hľadanie obsahu** alebo nájsť súbory, ktoré text **neobsahujú**.
2. Prepnite na kartu **Rozšírené** na zúženie výsledkov podľa **veľkosti** (napríklad `10K` až `5M`), podľa rozsahu **dátumu úpravy**, alebo na súbory zmenené za posledných N dní.
3. Zapnite **Hľadať vnútri archívov** na nazretie do archívov rodiny zip (zip, jar, war a podobné).
4. Na obmedzenie hľadania na to, čo ste už vybrali, zapnite pred štartom **Hľadať len vo vybraných položkách**.

![Okno Nájsť súbory na karte Rozšírené zobrazujúce filtre veľkosti a dátumu](screenshots/find-files-advanced.png)
*(Obrázok: karta Rozšírené — filtrujte podľa veľkosti, dátumu a iných atribútov.)*

Ak máte zásuvné moduly, ktoré pridávajú polia obsahu (ako rozmery obrázkov), karta **Zásuvné moduly** umožňuje vyžadovať, aby pole zodpovedalo podmienke — napríklad len obrázky širšie ako 1000 pixelov.

![Okno Nájsť súbory na karte Zásuvné moduly zobrazujúce podmienku na poli obsahu](screenshots/find-files-plugins.png)
*(Obrázok: karta Zásuvné moduly — zhoda podľa polí obsahu poskytnutých zásuvnými modulmi.)*

## Rýchle hľadania so Spotlightom

Pri lokálnych priečinkoch, ktoré macOS už zaindexoval, zapnite **Použiť Spotlight** na karte Všeobecné pre takmer okamžité výsledky. Spotlight hľadá v indexe namiesto skenovania súborov, takže ignoruje regulárne výrazy, obmedzenia hĺbky podpriečinkov a rozsah len-vybrané.

## Opätovné použitie a odovzdanie výsledkov

- **Poslať do zoznamu** umiestni každý výsledok do aktívneho panela ako dočasný zoznam, takže môžete celú sadu skopírovať, presunúť alebo odstrániť naraz.
- Na karte **Načítať / Uložiť** vyberte **Uložiť ako šablónu…** na uloženie aktuálneho hľadania (vzory a možnosti) a jeho neskoršie opätovné vybratie zo zoznamu šablón.

## Skratky

| Akcia | Skratka |
| --- | --- |
| Otvoriť Nájsť súbory | Cmd+Shift+F alebo Option+F7 |
| Spustiť / zastaviť hľadanie | Tlačidlo Štart v okne |
| Zobraziť vybraný výsledok | F3 |

## Poznámky

- Hľadanie obsahu číta celé súbory pri lokálnych priečinkoch; na iných umiestneniach sa veľmi veľké súbory preskočia (zhruba 16 MB, alebo 64 MB pri použití regulárneho výrazu).
- Hľadanie vnútri archívov zostupuje až do štyroch úrovní vnorených archívov.
- **Zahrnúť priečinky do výsledkov** uvádza aj priečinky, ktorých názvy sa zhodujú, nielen súbory.
- Spotlight pokrýva len zaindexované lokálne priečinky; pri sieťových umiestneniach alebo zhode podľa vzoru ho nechajte vypnutý a nechajte Nájsť súbory skenovať.
