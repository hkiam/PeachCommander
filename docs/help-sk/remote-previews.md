---
title: Náhľad súborov, ktoré nie sú na tomto Macu
slug: remote-previews
section: Zobrazenie a úpravy
order: 71
related: [viewing-files, archives, network-shares]
---

Peach Commander zobrazuje náhľad súboru pod kurzorom v bočnom informačnom paneli, v Quick View a ako miniatúry v zobrazení galérie. Keď ten súbor neleží na disku pripojenom k tomuto Macu, jeho zobrazenie niečo skutočne stojí — stiahnutie, rozbalenie alebo oboje — a nikto oň nepožiadal: kurzor naň iba nabehol. Peach Commander preto vopred rozhoduje, koľko smie náhľad stáť; táto stránka vysvetľuje, ako rozhoduje a ako to zmeniť.

## Súbory vnútri archívu

Súbor vnútri archívu možno zobraziť v náhľade úplne rovnako ako súbor mimo neho. Peach Commander ho na pozadí rozbalí do dočasnej kópie a zobrazí ju. To isté platí pre Quick Look, pre otvorenie v inej aplikácii klávesom Enter alebo dvojitým kliknutím a pre podponuku Otvoriť v.

To, čo dostane iná aplikácia, je kópia, a je len na čítanie: čo v nej zmeníte, sa do archívu nezapíše. Peach Commander to prvýkrát povie, so zaškrtávacím poľom, aby to prestal hovoriť. Ak chcete upraviť súbor, ktorý leží v archíve, najprv ho rozbaľte klávesom F5 a pracujte s rozbaleným súborom.

## Koľko smie náhľad stáť

Náhľad sleduje kurzor, deje sa teda bez vyžiadania. Preto podlieha rozpočtu, ktorý závisí od toho, kde je obsah súboru v skutočnosti:

- Na disku pripojenom k tomuto Macu nie je žiadny limit a náhľady sa správajú presne ako doteraz.
- V sieťovom umiestnení — pripojenom zdieľaní, FTP, SFTP, Amazon S3 alebo disku pluginu — sa súbory zobrazujú do 4 MB, kým Peach Commander nezmeria, aké rýchle je to spojenie naozaj. Potom povolí všetko, čo dokáže prečítať asi za jeden a pol sekundy, takže rýchle zdieľanie zobrazí veľké súbory a pomalé odmietne aj malé.
- V archíve sa súbor pre náhľad rozbaľuje do 32 MB.
- Súbor, ktorý cloudová služba doteraz nestiahla do tohto Macu, sa nikdy nesťahuje len preto, že naň nabehol kurzor.
- Pri formátoch archívov, ktoré treba rozbaľovať súbor po súbore — CPIO, ISO, CAB, LZH a podobné — sa automaticky nezobrazuje nič, pretože každý jednotlivý súbor stojí celý prechod archívom.

Odmietnutý náhľad nie je prázdny panel: bočný panel ukáže ikonu súboru, jeho názov, veľkosť a dátum a jeden riadok s dôvodom. Quick Look ho zobrazí aj tak a žiadnemu z týchto limitov nepodlieha.

## Zmena limitov

1. Otvorte Nastavenia ▸ Upraviť/Zobraziť.
2. Vypnite „Automaticky zobrazovať náhľady súborov v sieťových umiestneniach“, ak chcete sieťové náhľady úplne zastaviť, alebo nastavte „Sieťové súbory do (MB)“ na požadovanú veľkosť.
3. Zapnite „Sťahovať súbory z cloudu kvôli náhľadu“, ak dávate prednosť náhľadu pred ušetreným prenosom.
4. Nastavte „Rozbaľovať z archívov do (MB)“ pre to, aký veľký smie byť súbor v archíve.

Ďalšie dve nastavenia nemajú vlastný ovládací prvok a sú v `peachcmd.ini` v sekcii `[Preview]`: `AutoPreviewSeconds` je časový rozpočet platný po zmeraní spojenia (predvolene 1,5; 0 ho vypne) a `AutoPreviewLocalMB` je strop pre miestne disky (0 znamená bez limitu).

## Kam idú rozbalené kópie

Kópie sa zapisujú do dočasného priečinka systému a náhľady ich zdieľajú, namiesto toho, aby si každý robil vlastnú. Kópia vytvorená pre náhľad sa odstráni, len čo archív opustíte; kópia odovzdaná inej aplikácii zostane, kým Peach Commander neukončíte, pretože tá aplikácia ju má stále otvorenú. To, čo po sebe zanechá neočakávané ukončenie, sa rozpozná pri ďalšom spustení a vtedy sa upratá.

Miniatúry v zobrazení galérie podliehajú rovnakému rozpočtu a vytvárajú sa len bunky, ktoré sú naozaj na obrazovke — priečinok s dvoma tisícmi súborov teda stojí jednu obrazovku, nie dva tisíce. Aj súbory v archíve dostanú skutočné miniatúry; každý sa na to rozbalí, a práve preto tam rozpočet záleží najviac.
