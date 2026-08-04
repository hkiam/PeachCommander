---
title: Práca s archívmi
slug: archives
section: Archívy
order: 80
related: [copying-files]
---

Peach Commander zaobchádza s archívmi ako s priečinkami. Môžete vstúpiť do archívu ZIP, TAR alebo iného podporovaného archívu, prehliadať jeho obsah a kopírovať z neho súbory — všetko bez predchádzajúceho rozbalenia na disk. Keď chcete vytvoriť archív, príkaz Zabaliť zoskupí váš výber do formátu ZIP, 7z, TAR alebo iného, s voliteľným šifrovaním a rozdelenými zväzkami. Je to praktické na zbalenie súborov na odoslanie, zmenšenie priečinka na uloženie alebo nazretie do stiahnutého súboru pred tým, ako sa zaviažete k rozbaleniu.

## Prehliadajte archív ako priečinok

1. V paneli presuňte kurzor na súbor archívu (napríklad `.zip` alebo `.tar.gz`).
2. Stlačte Enter alebo Ctrl+PageDown na vstup, rovnako ako by ste otvorili priečinok.
3. Prechádzajte obsah normálne. Stlačte Backspace alebo Ctrl+PageUp na návrat hore a opustenie archívu.
4. Na vytiahnutie súborov ich vyberte a skopírujte (F5) do druhého panela.

![Prehliadanie vnútra archívu, akoby to bol priečinok](screenshots/archive-browse.png)
*(Obrázok: otvorený archív zobrazený ako bežný zoznam priečinka, so súbormi pripravenými na kopírovanie.)*

ZIP, TAR a TAR komprimovaný gzipom sa čítajú priamo. Iné formáty ako CPIO, ISO, CAB, LZH, XAR a PAX sa čítajú cez vstavané systémové nástroje. Šifrované archívy ZIP (klasické aj AES) možno otvoriť, keď zadáte heslo.

## Zabaľte súbory do nového archívu

1. Vyberte súbory a priečinky, ktoré chcete zahrnúť, v aktívnom paneli.
2. Vyberte Súbor ▸ Zabaliť… alebo stlačte Alt+F5. (Na zabalenie a následné odstránenie originálov použite Alt+Shift+F5.)
3. V dialógu vyberte formát archívu (ZIP, 7z, TAR, tar.gz, bzip2, xz alebo RAR), úroveň kompresie a kam ho uložiť.
4. Voliteľne zapnite šifrovanie AES-256 a nastavte heslo, alebo rozdeľte archív na zväzky s pevnou veľkosťou.
5. Potvrďte na vytvorenie archívu.

![Dialóg Zabaliť zobrazujúci formát, kompresiu, šifrovanie a možnosti rozdelenia](screenshots/pack-dialog.png)
*(Obrázok: dialóg Zabaliť, kde vyberiete formát a nastavíte možnosti šifrovania a rozdelenia na zväzky.)*

## Rozbaľte alebo otestujte archív

1. Umiestnite archív na rozbalenie do aktívneho panela a cieľový priečinok do druhého panela.
2. Vyberte Súbor ▸ Rozbaliť… alebo stlačte Alt+F9, potom potvrďte cieľ.
3. Na kontrolu archívu na poškodenie bez rozbalenia vyberte Súbor ▸ Otestovať archív.

## Upravte ZIP na mieste

Súbory môžete pridávať alebo odoberať vo vnútri existujúceho ZIP bez jeho rozbalenia. Otvorte ZIP ako priečinok, potom doň kopírujte súbory alebo mažte súbory ako obvykle — zmena sa zapíše priamo späť do archívu.

## Skratky

| Akcia | Skratka |
| --- | --- |
| Vstúpiť do archívu pod kurzorom | Enter alebo Ctrl+PageDown |
| Opustiť archív (ísť hore) | Backspace alebo Ctrl+PageUp |
| Zabaliť | Alt+F5 |
| Zabaliť a odstrániť originály | Alt+Shift+F5 |
| Rozbaliť | Alt+F9 |

## Poznámky

- Balenie do 7z, xz, bzip2 a RAR sa spolieha na externé nástroje. RAR konkrétne vyžaduje nainštalovaný proprietárny program RAR; bez neho tento formát nie je dostupný.
- Úprava ZIP na mieste prepíše celý archív, takže dátumy úprav súborov vo vnútri sa nezachovajú.
- Veľmi veľké jednotlivé položky sú pri rozbaľovaní obmedzené na 512 MiB. Rozbaľovanie možno zrušiť počas jeho behu.
- Archívy ZIP64 sa otvárajú ako každé iné, archív s viac ako 65 535 položkami alebo nad 4 GB teda možno normálne prehliadať; vyššie uvedený limit na jeden rozbalený súbor platí ďalej.
