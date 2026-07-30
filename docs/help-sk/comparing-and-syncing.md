---
title: Porovnávanie a synchronizácia
slug: comparing-and-syncing
section: Pokročilé nástroje
order: 90
related: [multi-rename]
---

Keď udržiavate dve kópie toho istého priečinka — pracovný priečinok a zálohu, notebook a sieťové zdieľanie, projekt a jeho archív — Peach Commander vám pomôže vidieť presne, čo sa zmenilo, a vrátiť obe strany do súladu. Môžete synchronizovať dva adresáre, porovnávať jednotlivé súbory riadok po riadku a kontrolovať súbory bajt po bajte, keď potrebujete istotu až po posledný znak.

## Synchronizujte dva adresáre

1. Otvorte priečinok, ktorý chcete synchronizovať, v ľavom paneli a priečinok na porovnanie v pravom paneli.
2. Vyberte **Príkazy ▸ Synchronizovať adresáre…**. Cesty oboch priečinkov sa vyplnia z vašich panelov.
3. Nastavte, aké dôkladné má byť porovnanie: zahrnúť podpriečinky, porovnávať **podľa obsahu** (nielen podľa dátumu a veľkosti), alebo ignorovať dátum úpravy.
4. Pridajte masku filtra (napríklad `*.jpg;*.png`), ak chcete synchronizovať iba určité súbory.
5. Preskúmajte mriežku výsledkov. Každý riadok zobrazuje súbor vľavo, šípku smeru v strede a zhodujúci sa súbor vpravo. Šípky vám hovoria, čo sa stane: **→** kopíruje zľava doprava, **←** kopíruje sprava doľava a **=** znamená, že oba sú rovnaké.
6. Upravte jednotlivé riadky, ak nesúhlasíte s navrhovaným smerom, potom kliknite na tlačidlo synchronizácie na vykonanie zmien.

![Okno synchronizácie adresárov s dvoma cestami priečinkov a mriežkou výsledkov súborov so šípkami vľavo, rovnosti a vpravo](screenshots/sync-dialog.png)
*(Obrázok: okno Synchronizovať adresáre porovnáva obe strany a navrhuje smer kopírovania pre každý súbor.)*

## Porovnajte dva súbory podľa obsahu

1. Vyberte jeden súbor v každom paneli (alebo dva súbory v tom istom paneli).
2. Vyberte **Súbor ▸ Porovnať podľa obsahu…**.
3. Oba súbory sa otvoria vedľa seba so zvýraznenými rozdielmi. Použite ovládacie prvky ďalší/predchádzajúci na preskakovanie medzi zmenenými blokmi.
4. Ak zapnete režim úprav, môžete ktorýkoľvek súbor priamo upraviť a uložiť zmeny.

![Okno porovnania zobrazujúce dva textové súbory vedľa seba so zvýraznenými odlišnými riadkami](screenshots/diff-window.png)
*(Obrázok: porovnávanie dvoch textových súborov; zmenené riadky sú zvýraznené na oboch stranách.)*

## Porovnajte súbory bajt po bajte

Keď dva súbory vyzerajú rovnako, ale musíte dokázať, že sú naozaj rovnaké (alebo nájsť ten jeden bajt, ktorý sa líši), použite binárne porovnanie. Zobrazí oba súbory v šestnástkovom zobrazení s označenými nezhodnými bajtmi, čo je ideálne na overovanie stiahnutí, kontrolu kódovaných údajov alebo potvrdenie presnej kópie.

## Porovnajte zoznamy adresárov

Na zbadanie rozdielov medzi dvoma otvorenými priečinkami na prvý pohľad vyberte **Výber ▸ Porovnať adresáre** (Shift+F2). Peach Commander označí súbory, ktoré sa líšia alebo chýbajú na druhej strane, takže na nich môžete konať bežnými príkazmi kopírovania, presúvania a mazania.

## Skratky

| Akcia | Skratka |
| --- | --- |
| Porovnať zoznamy adresárov (označiť odlišné súbory) | Shift+F2 |
| Porovnať podľa obsahu | Súbor ▸ Porovnať podľa obsahu… |
| Synchronizovať adresáre | Príkazy ▸ Synchronizovať adresáre… |

## Poznámky

- **Podľa obsahu vs. podľa dátumu/veľkosti.** Rýchle porovnanie zhoduje súbory podľa veľkosti a dátumu úpravy, čo je rýchle, ale možno oklamať, keď sa časové značky líšia pre rovnaké súbory. Zapnite **podľa obsahu** pre spoľahlivý výsledok za cenu čítania každého súboru.
- **Podpriečinky a filtre.** Okno synchronizácie môže zostúpiť do podpriečinkov a možno ho obmedziť maskou filtra, takže môžete synchronizovať iba typy súborov, ktoré vás zaujímajú.
- **Zostávate pod kontrolou.** Synchronizácia nikdy nebeží sama — preskúmate navrhované smery v mriežke výsledkov a ktorýkoľvek z nich môžete zmeniť pred tým, ako sa čokoľvek skopíruje.
- **Predvoľby.** Často používané nastavenia synchronizácie možno uložiť a znovu použiť, takže nezadávate tie isté možnosti zakaždým.
