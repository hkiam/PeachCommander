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
- **Spustiť na pozadí** — odovzdá kopírovanie správcovi prenosov na pozadí namiesto zobrazenia okna priebehu.
- **Zaradiť do fronty na neskôr** — pridá kopírovanie do frontu na pozadí bez toho, aby ho hneď spustilo.
- **Maska premenovania** — do cieľového poľa napíšte vzor so zástupnými znakmi (napríklad `*.bak`), aby ste položky pri kopírovaní premenovali.

Dve nastavenia platia pre každé kopírovanie a nájdete ich v **Konfigurácia ▸ Nastavenia… ▸ Kopírovať/odstrániť**: zachovanie dátumov, oprávnení a ďalších atribútov (predvolene zapnuté) a obmedzenie rýchlosti, aby veľké kopírovanie nezaťažilo váš disk alebo sieťové pripojenie. K úlohám vo fronte pozri Prenosy na pozadí.

## Priebeh

Okno priebehu zobrazuje dve lišty — kopírovaný súbor a celú úlohu — s počtom súborov a bajtov, prenosovou rýchlosťou a zostávajúcim časom. Kedykoľvek môžete kopírovanie pozastaviť a pokračovať v ňom. Ponuka rýchlosti vedľa tlačidiel toto kopírovanie hneď obmedzí (1, 5 alebo 20 MB/s, alebo plná rýchlosť) bez zmeny limitu v Konfigurácii; **Predvolené** sa vráti k tomuto limitu. **Na pozadí** odovzdá bežiace kopírovanie správcovi prenosov na pozadí: okno sa zatvorí a kopírovanie pokračuje tam.

![Dialóg priebehu prenosu s lištou pre aktuálny súbor a ďalšou pre celú úlohu, počtom súborov a bajtov, ponukou rýchlosti a tlačidlami Na pozadí, Pozastaviť a Zrušiť](screenshots/progress-dialog.png)
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
