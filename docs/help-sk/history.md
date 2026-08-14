---
title: Globálna história
slug: history
section: Usporiadanie zobrazenia
order: 47
related: [favorites, navigating]
---

Globálna história je jedno okno, ktoré si pamätá vašu vlastnú prácu: navštívené priečinky, otvorené súbory, vykonané operácie a spustené príkazy. Odkiaľkoľvek stlačte Ctrl+Cmd+H, začnite písať a za sekundu ste späť vo včerajšom priečinku — bez myši.

## Otvorenie histórie

1. Stlačte Ctrl+Cmd+H alebo zvoľte **Prejsť > História…**. Nezáleží na tom, ktorý panel je aktívny.
2. Napíšte niekoľko znakov. Zhoda nemusí byť presná ani súvislá: `proj rep` nájde `~/Projects/annual-report.txt`.
3. Medzi výsledkami sa posúvajte klávesmi Nahor a Nadol, kým ďalej píšete.
4. Enter vykoná označenú položku, Esc okno zavrie.

Položky sú zoradené podľa toho, ako nedávno *a* ako často ste ich použili, takže miesta, kde pracujete najviac, sú už navrchu. Pripnuté položky vedú vždy.

## Filtrovanie podľa druhu

Tlačidlá pod vyhľadávacím poľom obmedzia zoznam na všetky položky, priečinky, súbory, operácie alebo obľúbené. Option+1 až Option+5 medzi nimi prepínajú z klávesnice.

## Práca s položkou

| Akcia | Skratka |
| --- | --- |
| Otvoriť označenú položku | Return |
| Zobraziť v paneli, s kurzorom na nej | Option+Return |
| Otvoriť jednu z deviatich najrelevantnejších položiek | Cmd+1 … Cmd+9 |
| Prepnúť panel, v ktorom sa otvára | Tab |
| Pripnúť alebo odopnúť položku | Cmd+P |
| Odobrať položku z histórie | Cmd+Delete |
| Kopírovať cestu položky | Option+Cmd+C |
| Zobraziť položku vo Finderi | Cmd+Shift+R |
| Zavrieť históriu | Esc |

Enter urobí to, čo položke patrí: priečinok sa otvorí v cieľovom paneli, súbor sa otvorí rovnako ako z panela a príkazový riadok sa vloží do príkazového riadka, aby ste si ho mohli pozrieť a spustiť. Cieľový panel je uvedený dole v okne a Tab ho prepína.

## Zopakovanie operácie

Kopírovanie alebo presun sa zobrazí pod **Operácie** a Enter ich spustí znova — tie isté položky do toho istého priečinka, bežným prenosovým frontom aj s jeho otázkami na prepísanie. Položky, ktoré už neexistujú, sa preskočia, a ak nezostane žiadna, dozviete sa to.

Mazanie a premenovanie sú v zozname, ale nikdy sa neopakujú: Enter namiesto toho ukáže, kde sa stali. Zopakovať mazanie nemá byť na jedno stlačenie v zozname, ktorý len prezeráte.

## Udržanie pod kontrolou

Nastavenia ▸ Ostatné rozhodujú, či sa história vedie, koľko položiek si drží a po koľkých dňoch ich zabudne. Pripnuté položky sú z oboch vyňaté a 0 dní znamená uchovať všetko; zoznam leží v `history.ini` vo vašom konfiguračnom priečinku a prežije restart.

## Poznámky

- Otvoriť niečo z histórie sa počíta ako použitie — preto to, k čomu sa vraciate, stále stúpa.
- Priečinky vnútri archívu, na serveri alebo v disku zásuvného modulu sa nepamätajú: taká cesta bez pripojenia, ktoré ju vytvorilo, nič neznamená — vlastná história panela ich drží, kým je pripojenie otvorené.
- Nie je to vlastná história priečinkov panela na Alt+Nadol, ktorá vypisuje len to, kde bol ten jeden panel, v poradí.
