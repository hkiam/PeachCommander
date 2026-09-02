---
title: Náhled souborů, které nejsou na tomto Macu
slug: remote-previews
section: Prohlížení a úpravy
order: 71
related: [viewing-files, archives, network-shares]
---

Peach Commander zobrazuje náhled souboru pod kurzorem v postranním informačním panelu, v Quick View a jako miniatury v zobrazení galerie. Když ten soubor neleží na disku připojeném k tomuto Macu, jeho zobrazení něco skutečně stojí — stažení, rozbalení nebo obojí — a nikdo o to nepožádal: kurzor na něj jen najel. Peach Commander proto předem rozhoduje, kolik smí náhled stát; tato stránka vysvětluje, jak rozhoduje a jak to změnit.

## Soubory uvnitř archivu

Soubor uvnitř archivu lze zobrazit v náhledu úplně stejně jako soubor mimo něj. Peach Commander jej na pozadí rozbalí do dočasné kopie a zobrazí ji. Totéž platí pro Quick Look, pro otevření v jiné aplikaci klávesou Enter nebo dvojitým kliknutím a pro podnabídku Otevřít v.

To, co dostane jiná aplikace, je kopie, a je jen pro čtení: co v ní změníte, se do archivu nezapíše. Peach Commander to poprvé řekne, se zaškrtávacím polem, aby to říkat přestal. Chcete-li upravit soubor, který leží v archivu, nejprve jej rozbalte klávesou F5 a pracujte s rozbaleným souborem.

## Kolik smí náhled stát

Náhled sleduje kurzor, děje se tedy bez vyžádání. Proto podléhá rozpočtu, který závisí na tom, kde obsah souboru skutečně je:

- Na disku připojeném k tomuto Macu není žádný limit a náhledy se chovají přesně jako dosud.
- V síťovém umístění — připojeném sdílení, FTP, SFTP, Amazon S3 nebo disku pluginu — se soubory zobrazují do 4 MB, dokud Peach Commander nezměří, jak rychlé to spojení opravdu je. Poté povolí vše, co dokáže přečíst zhruba za jeden a půl sekundy, takže rychlé sdílení zobrazí velké soubory a pomalé odmítne i malé.
- V archivu se soubor pro náhled rozbaluje do 32 MB.
- Soubor, který cloudová služba dosud nestáhla do tohoto Macu, se nikdy nestahuje jen proto, že na něj najel kurzor.
- U formátů archivů, které je nutné rozbalovat soubor po souboru — CPIO, ISO, CAB, LZH a podobné — se automaticky nezobrazuje nic, protože každý jednotlivý soubor stojí celý průchod archivem.

Odmítnutý náhled není prázdný panel: postranní panel ukáže ikonu souboru, jeho název, velikost a datum a jeden řádek s důvodem. Quick Look jej zobrazí i tak a žádnému z těchto limitů nepodléhá.

## Změna limitů

1. Otevřete Nastavení ▸ Úpravy/Zobrazení.
2. Vypněte „Automaticky zobrazovat náhledy souborů v síťových umístěních“, chcete-li síťové náhledy zcela zastavit, nebo nastavte „Síťové soubory do (MB)“ na požadovanou velikost.
3. Zapněte „Stahovat soubory z cloudu kvůli náhledu“, pokud dáváte přednost náhledu před ušetřeným přenosem.
4. Nastavte „Rozbalovat z archivů do (MB)“ pro to, jak velký smí být soubor v archivu.

Další dvě nastavení nemají vlastní ovládací prvek a jsou v `peachcmd.ini` v sekci `[Preview]`: `AutoPreviewSeconds` je časový rozpočet platný po změření spojení (výchozí 1,5; 0 jej vypne) a `AutoPreviewLocalMB` je strop pro místní disky (0 znamená bez limitu).

## Kam jdou rozbalené kopie

Kopie se zapisují do dočasné složky systému a náhledy je sdílejí, místo aby si každý dělal vlastní. Kopie vytvořená pro náhled se odstraní, jakmile archiv opustíte; kopie předaná jiné aplikaci zůstane, dokud Peach Commander neukončíte, protože ta aplikace ji má stále otevřenou. Co po sobě zanechá neočekávané ukončení, se rozpozná při dalším spuštění a tehdy se uklidí.

Miniatury v zobrazení galerie podléhají stejnému rozpočtu a vytvářejí se jen buňky, které jsou skutečně na obrazovce — složka s dvěma tisíci soubory tedy stojí jednu obrazovku, ne dva tisíce. I soubory v archivu dostanou skutečné miniatury; každý se k tomu rozbalí, a právě proto tam rozpočet záleží nejvíc.
