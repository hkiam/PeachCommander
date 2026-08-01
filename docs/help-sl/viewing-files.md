---
title: Ogled datotek
slug: viewing-files
section: Ogled in urejanje
order: 70
related: [editing-files, searching]
---

Peach Commander ima vgrajen pregledovalnik, ki omogoča, da pogledate v datoteko, ne da bi odprli drugo aplikacijo ali spremenili datoteko. Pritisnite F3 na elementu pod kazalcem in pregledovalnik se odpre v hipu, tudi za zelo velike datoteke. Samodejno izbere najboljši način prikaza vsebine: berljivo besedilo, skladenjsko obarvano kodo, surov izpis v šestnajstiškem zapisu ali sliko v polni velikosti. Datoteko lahko predoglejte tudi kar znotraj okna z uporabo Quick View ali jo predate v macOS Quick Look.

## Ogled datoteke

1. Premaknite kazalec na datoteko v aktivnem podoknu.
2. Pritisnite F3 (ali izberite Ogled v meniju Datoteka). Pregledovalnik se odpre v svojem oknu.
3. Z orodno vrstico preklopite, kako je prikazana vsebina: Besedilo, Koda, Hex, Slika ali Izrisano. Pustite ga na samodejni nastavitvi, da odloči Peach Commander.
4. Drsite s puščičnimi tipkami, Page Up/Page Down in drsnikom. Za dolgo besedilo vklopite gumb za mini zemljevid, da vidite in preskakujete po celotni datoteki na prvi pogled.
5. Pritisnite N za skok na naslednjo izbrano datoteko ali zaprite okno z Esc.

![Vgrajeni pregledovalnik, ki prikazuje besedilno datoteko z mini zemljevidom na desni](screenshots/lister-text.png)
*(Slika: Ogled besedilne datoteke, z izbirnikom predstavitve in mini zemljevidom v orodni vrstici.)*

## Iskanje besedila in sprememba kodiranja

- Pritisnite Ctrl+F za iskanje znotraj datoteke. Pritisnite F3 za skok na naslednje ujemanje in Shift+F3 za prejšnje.
- Če je besedilo videti popačeno, kliknite Kodiranje v orodni vrstici (ali pritisnite E), da se pomikate skozi kodiranja besedila, dokler se ne prebere pravilno; samodejna nastavitev to običajno zadene prav.
- Pritisnite W za preklop preloma besed za dolge vrstice.

## Quick View in Quick Look

Quick View prikaže sprotni predogled v podoknu, ki ga *ne* uporabljate, tako da lahko na eni strani še naprej brskate, na drugi pa predoglejete.

1. Pritisnite Ctrl+Q. Neaktivno podokno se spremeni v predoglednо območje.
2. Premikajte kazalec po različnih datotekah v aktivnem podoknu za predogled vsake.
3. Znova pritisnite Ctrl+Q ali Esc, da podokno vrnete v običajen seznam datotek.

Za hiter celozaslonski predogled, ki ga obravnava sam macOS, pritisnite Cmd+Y (Quick Look). Znova pritisnite Cmd+Y ali Space, da ga zaprete.

## Bližnjice

| Dejanje | Bližnjica |
| --- | --- |
| Ogled datoteke pod kazalcem | F3 |
| Ogled samo datoteke pod kazalcem (prezri označene datoteke) | Shift+F3 |
| Odpri v zunanjem pregledovalniku | Option+F3 |
| Iskanje znotraj pregledovalnika | Ctrl+F |
| Naslednje / prejšnje ujemanje | F3 / Shift+F3 |
| Quick View v drugem podoknu | Ctrl+Q |
| Quick Look (predogled macOS) | Cmd+Y |
| Zapri pregledovalnik ali Quick View | Esc |

## Stran z informacijami v stranskem pladnju

Stranski pladenj (**Pogled > Panel predogleda** ali Cmd+Shift+P) ima stran **Informacije**, ki prikaže element pod kazalko tako, kot to počne informacijski stranski pas Finderja.

- Predogled zapolni celotno širino pladnja — če pladenj razširite, raste predogled z njim.
- To je pravi predogled macOS, ne majhna sličica: deluje vsak zapis, ki ga zna prikazati Hitri pogled, po večstranskem dokumentu pa listate kar v predogledu, stran za stranjo.
- Pod njim so ime, vrsta in velikost, nato kdaj je bil element ustvarjen in spremenjen ter v kateri mapi je.

Ob premikanju kazalke se ime in podatki osvežijo takoj; predogled sledi trenutek pozneje, tako da zadržana puščična tipka skozi dolgo mapo ne zažene predogleda za vsako prehojeno vrstico.

## Opombe

- Pregledovalnik je samo za branje. Za spremembo datoteke raje uporabite urejevalnik (glejte Urejanje datotek).
- Zelo velike datoteke se odprejo brez zakasnitve: besedilo odpre hiter, drsljiv pogled, šestnajstiški pogled pa se pretaka naravnost z diska pri poljubni velikosti.
- Pritisnite F3 na mapi, da namesto bajtov datoteke vidite povzetek njene vsebine in skupno velikost.
- Način Izrisano prikaže oblikovano vsebino, kot so spletne strani; šestnajstiški način prikaže surove bajte ob njihovih znakih, kar je priročno za pregledovanje binarnih datotek.
