---
title: Atributi in dovoljenja
slug: attributes-and-permissions
section: Napredna orodja
order: 96
related: [file-utilities]
---

Peach Commander vam omogoča pregledovanje in spreminjanje nizkonivojskih metapodatkov datotek in map, ki jih Finder večinoma drži zunaj dosega: dovoljenja POSIX za branje/pisanje/izvajanje, lastnika in skupino, datuma spremembe in ustvarjanja, zastavice macOS, kot sta skrit in zaklenjen, ter razširjene atribute. Uredite lahko tudi seznam za nadzor dostopa (ACL) datoteke za podrobna pravila na uporabnika ali skupino, ustvarite povezave in vzdevke, ki kažejo na druge elemente, ter pripnete lastne komentarje. Ta orodja so namenjena naprednim uporabnikom, ki potrebujejo natančen nadzor nad tem, kako se elementi obnašajo in kdo se jih lahko dotakne.

## Spreminjanje atributov

1. Izberite enega ali več elementov v dejavnem podoknu.
2. Izberite **Datoteka > Spremeni atribute…**.
3. Nastavite, kar potrebujete: preklopite polja za branje/pisanje/izvajanje za lastnika, skupino in vse (ali vnesite osmiško vrednost neposredno), spremenite lastnika ali skupino, preklopite zastavici skrit ali zaklenjen ter nastavite datum spremembe ali ustvarjanja. Uporabite **Uporabi trenutni** za trenutni čas, ali kopirajte datum iz druge datoteke.
4. Za uporabo iste spremembe skozi vsebino mape vklopite rekurzivno možnost in izberite, ali vpliva na datoteke, mape ali oboje.
5. Kliknite V redu, da izvedete spremembo. Rekurzivne spremembe se izvajajo kot opravilo v ozadju z vrstico napredka.

![Pogovorno okno Spremeni atribute, ki prikazuje mrežo dovoljenj, zastavice in polja datumov](screenshots/attributes-dialog.png)
*(Slika: pogovorno okno Spremeni atribute. Mešane vrednosti v izboru več datotek se prikažejo kot pomišljaj, dokler jih ne nastavite.)*

## Urejanje ACL

Za pravila zunaj osnovnega modela lastnik/skupina/vsi uredite seznam za nadzor dostopa elementa.

1. Odprite **Datoteka > Spremeni atribute…** in od tam odprite urejevalnik ACL.
2. Vsaka vrstica je eno pravilo: uporabnik ali skupina, na katero se nanaša, ali dovoljuje ali zavrača, in katera dovoljenja (branje, pisanje, brisanje itd.) podeljuje.
3. Dodajajte, odstranjujte ali urejajte vrstice, nato shranite, da seznam zapišete nazaj v element.

## Ustvarjanje povezav, vzdevkov in komentarjev

- **Datoteka > Ustvari simbolno povezavo…** ustvari simbolno povezavo (symlink), ki po poti kaže na element pod kazalko.
- **Datoteka > Ustvari trdo povezavo…** ustvari trdo povezavo do istih podatkov datoteke. Trde povezave delujejo le za datoteke na istem nosilcu.
- **Datoteka > Ustvari vzdevek…** ustvari vzdevek macOS, ki mu lahko sledi tudi Finder.
- **Datoteka > Uredi komentar…** (Ctrl+Z) odpre urejevalnik besedila za komentar na datoteko. Komentarje je mogoče prikazati v lastnem stolpcu in v namigih stanja.

## Bližnjice

| Dejanje | Bližnjica |
| --- | --- |
| Uredi komentar | Ctrl+Z |

## Opombe

- Spreminjanje lastnika ali skupine običajno zahteva pravice, ki jih kot običajen uporabnik nimate; ko se to zgodi, se sprememba prijavi kot neuspešna namesto uporabljena, preostale vaše spremembe pa še vedno gredo skozi.
- Komentarji so shranjeni v datoteki `descript.ion` poleg vaših elementov in jih je mogoče hraniti tudi kot komentarje Finder, odvisno od vaših nastavitev. Oba se bereta pri prikazu komentarja.
- Simbolna povezava in vzdevek oba kažeta na cilj, vendar simbolna povezava shrani navadno pot, medtem ko vzdevek shrani sklic macOS, ki še naprej deluje, če se cilj premakne ali preimenuje. Trda povezava je drugo ime za iste podatke datoteke, ne kazalec.
