---
title: Premenovanie mnohých súborov
slug: multi-rename
section: Pokročilé nástroje
order: 92
related: [moving-and-renaming]
---

Nástroj hromadného premenovania premenuje celú dávku súborov v jednom prechode. Namiesto úpravy názvov po jednom opíšete zmenu raz — vzor pomenovania, hľadanie a nahradenie, schému číslovania alebo zmenu veľkosti písmen — a Peach Commander ju použije na každý vybraný súbor. Živý náhľad ukazuje presne, ako sa bude volať každý súbor, skôr než sa čokoľvek stane, a jediné Späť vráti pôvodné názvy, ak výsledok nebol taký, aký ste chceli.

## Premenovanie dávky súborov

1. Vyberte súbory, ktoré chcete premenovať (pozri *Výber súborov*). Ovplyvnené sú iba vybrané položky.
2. Vyberte **Príkazy > Nástroj hromadného premenovania…** alebo stlačte Ctrl+M.
3. Zostavte pravidlo premenovania pomocou polí opísaných nižšie. Mriežka náhľadu sa počas písania aktualizuje a zobrazuje každý **Starý názov** vedľa jeho **Nového názvu**.
4. Skontrolujte náhľad. Riadok zobrazený farbou zvýraznenia označuje názov, ktorý nemožno použiť (napríklad duplikát alebo nepovolený názov), takže môžete upraviť pravidlo.
5. Keď náhľad vyzerá správne, kliknite na **Štart**. Ak si to rozmyslíte, kliknite na **Späť** na obnovenie pôvodných názvov.

![Okno hromadného premenovania s poliami masky, možnosťami a mriežkou náhľadu zo starého na nový](screenshots/multi-rename.png)
*(Obrázok: mriežka náhľadu sa aktualizuje naživo počas úpravy pravidla premenovania; nič sa nezmení na disku, kým nekliknete na Štart.)*

## Zostavenie pravidla premenovania

- **Maska premenovania** a **Prípona** — vzory, ktoré zostavia nový názov a príponu. Použite tlačidlá rýchleho vloženia, alebo zadajte zástupné symboly priamo: `[N]` pre pôvodný názov, `[N1-9]` pre rozsah znakov z neho, `[C]` pre počítadlo, `[d]` pre časti dátumu a času a `[P]` pre názov nadradeného priečinka.
- **Hľadať / Nahradiť za** — nahradiť text vnútri názvov. Zapnite **Regex** pre zhodu podľa vzoru, **Rozlišovať veľkosť** pre presnú zhodu veľkosti písmen a **Opakovať** pre nahradenie každého výskytu.
- **Veľkosť písmen** — previesť názvy na malé písmená, VEĽKÉ PÍSMENÁ, Prvé písmeno veľké alebo Každé Slovo Veľké.
- **Počítadlo** — nastavte **počiatočné** číslo, **krok** medzi súbormi a na koľko **číslic** doplniť (napríklad 001, 002, 003) všade, kde sa objaví `[C]`.

## Skratky

| Akcia | Skratka |
| --- | --- |
| Otvoriť nástroj hromadného premenovania | Ctrl+M |
| Použiť premenovanie | Enter |
| Zatvoriť okno | Esc |

## Tipy

- Nič sa nezapíše na disk, kým nekliknete na **Štart**, takže môžete s pravidlom voľne experimentovať a sledovať náhľad.
- Po spustení **Späť** obráti premenovanie v jednom kroku.
- Uložte pravidlo, ktoré často používate, ako **Predvoľbu**, potom ju nabudúce vyberte z ponuky predvolieb na vyplnenie všetkých polí naraz.
- Na premenovanie jedného súboru alebo premenovanie súborov počas ich presúvania použite namiesto toho premenovanie na mieste alebo dialóg presunu (pozri *Presun a premenovanie*).
