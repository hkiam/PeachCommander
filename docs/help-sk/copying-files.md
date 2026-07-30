---
title: Kopírovanie súborov
slug: copying-files
section: Súbory a priečinky
order: 24
related: [moving-and-renaming, background-transfers]
---

Peach Commander je postavený okolo dvoch panelov vedľa seba: jeden obsahuje súbory, s ktorými pracujete, druhý je cieľom. Kopírovanie vezme to, čo je vybrané v aktívnom paneli, a umiestni kópiu do priečinka zobrazeného v druhom paneli, pričom originály ponechá na mieste. Toto je najrýchlejší spôsob, ako duplikovať súbory a priečinky medzi dvoma umiestneniami bez preťahovania.

## Skopírovanie výberu do druhého panela

1. V jednom paneli otvorte priečinok, ktorý obsahuje položky, ktoré chcete skopírovať.
2. V druhom paneli otvorte priečinok, kam majú kópie smerovať.
3. Vyberte súbory a priečinky na skopírovanie. Ak nie je nič vybrané, použije sa položka pod kurzorom.
4. Stlačte F5. Otvorí sa dialóg kopírovania s už vyplnenou cieľovou cestou.

![Dialóg kopírovania s cieľovou cestou a možnosťami](screenshots/copy-dialog.png)
*(Obrázok: Dialóg kopírovania. Cieľová cesta smeruje na druhý panel; pomocou možností dolaďte kopírovanie.)*

5. V prípade potreby upravte cieľ a potvrdením spustite kopírovanie.

## Možnosti kopírovania

Pred potvrdením môžete zmeniť, ako sa kopírovanie správa:

- **Iba novšie súbory** — preskočí každú položku, ktorej kópia už existuje a je rovnako stará alebo novšia, takže sa aktualizujú len zmenené súbory.
- **Zachovať metadáta** — zachová dátumy, oprávnenia a ďalšie atribúty súborov na kópiách. Toto je predvolene zapnuté.
- **Obmedzenie rýchlosti** — obmedzí prenosovú rýchlosť, aby veľké kopírovanie nezaťažilo váš disk alebo sieťové pripojenie.
- **Maska premenovania** — do cieľového poľa napíšte vzor so zástupnými znakmi (napríklad `*.bak`), aby ste položky pri kopírovaní premenovali.

Úlohu môžete tiež namiesto sledovania odoslať do frontu na pozadí — pozri Prenosy na pozadí.

## Priebeh

Okno priebehu zobrazuje aktuálny súbor a celkovú úlohu so samostatnými lištami, plus prenosovú rýchlosť. Kedykoľvek môžete pozastaviť a obnoviť, alebo odoslať prebiehajúce kopírovanie do správcu prenosov na pozadí a pracovať ďalej, kým sa dokončí.

![Dialóg priebehu prenosu s lištou priebehu, počtom súborov a bajtov a tlačidlami Pozastaviť a Zrušiť](screenshots/progress-dialog.png)
*(Obrázok: Dialóg priebehu zobrazený počas kopírovania alebo presunu.)*

## Riešenie súborov, ktoré už existujú

Ak by kopírovanie nahradilo existujúci súbor, Peach Commander sa zastaví a spýta sa, čo robiť. Rozhodnúť vám pomôže ukážka oboch súborov.

![Dialóg konfliktu pri prepísaní porovnávajúci dva súbory](screenshots/overwrite-dialog.png)
*(Obrázok: Dialóg prepísania porovnáva existujúci súbor s tým, ktorý sa kopíruje.)*

Medzi vaše možnosti patrí:

- **Prepísať** existujúci súbor alebo **Prepísať všetko**, aby sa to použilo na každý zvyšný konflikt.
- **Preskočiť** tento súbor alebo **Preskočiť všetky** zvyšné konflikty.
- **Premenovať** prichádzajúcu kópiu automaticky, takže sa zachovajú oba súbory.
- **Pripojiť** prichádzajúce dáta na koniec existujúceho súboru.
- Prepísať, len keď je zdroj **novší** alebo **väčší** než existujúci súbor.

## Klávesové skratky

| Akcia | Kláves |
|---|---|
| Skopírovať výber do druhého panela | F5 |
| Kopírovať v tom istom priečinku (vytvoriť premenovanú kópiu) | Shift+F5 |
| Otvoriť správcu prenosov na pozadí | Cmd+Shift+B |

## Poznámky

- Kopírovanie medzi dvoma umiestneniami na tom istom disku používa rýchle klonovanie, ak to disk podporuje, takže veľké súbory sa skopírujú takmer okamžite a zaberú málo miesta navyše.
- Priečinky sa kopírujú so všetkým, čo je v nich.
- Ak chcete súbory namiesto kopírovania presunúť, použite F6. Ak chcete sledovať alebo spravovať úlohy vo fronte, otvorte správcu prenosov na pozadí pomocou Cmd+Shift+B.
