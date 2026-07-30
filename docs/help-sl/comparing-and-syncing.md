---
title: Primerjava in sinhronizacija
slug: comparing-and-syncing
section: Napredna orodja
order: 90
related: [multi-rename]
---

Ko hranite dve kopiji iste mape — delovno mapo in varnostno kopijo, prenosnik in omrežno mapo, projekt in njegov arhiv — vam Peach Commander pomaga videti natanko, kaj se je spremenilo, in obe strani vrniti v korak. Sinhronizirate lahko dva imenika, primerjate posamezne datoteke vrstico za vrstico in pregledate datoteke bajt za bajtom, ko potrebujete gotovost do zadnjega znaka.

## Sinhronizirajte dva imenika

1. Odprite mapo, ki jo želite sinhronizirati, v levem podoknu in mapo za primerjavo v desnem podoknu.
2. Izberite **Ukazi ▸ Sinhroniziraj imenike…**. Poti obeh map se izpolnita iz vaših podoken.
3. Nastavite, kako temeljita naj bo primerjava: vključi podmape, primerjaj **po vsebini** (ne le po datumu in velikosti), ali prezri datum spremembe.
4. Dodajte masko filtra (na primer `*.jpg;*.png`), če želite sinhronizirati le določene datoteke.
5. Preglejte mrežo rezultatov. Vsaka vrstica prikazuje datoteko na levi, puščico smeri na sredini in ujemajočo datoteko na desni. Puščice vam povedo, kaj se bo zgodilo: **→** kopira z leve na desno, **←** kopira z desne na levo, **=** pa pomeni, da sta oba enaka.
6. Prilagodite posamezne vrstice, če se ne strinjate s predlagano smerjo, nato kliknite gumb za sinhronizacijo, da izvedete spremembe.

![Okno za sinhronizacijo imenikov z dvema potema map in mrežo rezultatov datotek s puščicami levo, enako in desno](screenshots/sync-dialog.png)
*(Slika: okno Sinhroniziraj imenike primerja obe strani in predlaga smer kopiranja za vsako datoteko.)*

## Primerjajte dve datoteki po vsebini

1. Izberite eno datoteko v vsakem podoknu (ali dve datoteki v istem podoknu).
2. Izberite **Datoteka ▸ Primerjaj po vsebini…**.
3. Obe datoteki se odpreta drug ob drugem s poudarjenimi razlikami. Uporabite gumba naslednji/prejšnji za preskakovanje med spremenjenimi bloki.
4. Če vklopite način urejanja, lahko katero koli datoteko neposredno prilagodite in shranite spremembe.

![Okno za primerjavo, ki prikazuje dve besedilni datoteki drug ob drugem s poudarjenimi različnimi vrsticami](screenshots/diff-window.png)
*(Slika: primerjava dveh besedilnih datotek; spremenjene vrstice so poudarjene na obeh straneh.)*

## Primerjajte datoteke bajt za bajtom

Ko dve datoteki izgledata enako, a morate dokazati, da sta res enaki (ali najti tisti en bajt, ki se razlikuje), uporabite dvojiško primerjavo. Prikaže obe datoteki v šestnajstiškem pogledu z označenimi neujemajočimi bajti, kar je idealno za preverjanje prenosov, preverjanje kodiranih podatkov ali potrjevanje natančne kopije.

## Primerjajte sezname imenikov

Za odkritje razlik med dvema odprtima mapama na prvi pogled izberite **Izbor ▸ Primerjaj imenike** (Shift+F2). Peach Commander označi datoteke, ki se razlikujejo ali manjkajo na drugi strani, tako da lahko na njih delujete z običajnimi ukazi kopiranja, premikanja in brisanja.

## Bližnjice

| Dejanje | Bližnjica |
| --- | --- |
| Primerjaj sezname imenikov (označi različne datoteke) | Shift+F2 |
| Primerjaj po vsebini | Datoteka ▸ Primerjaj po vsebini… |
| Sinhroniziraj imenike | Ukazi ▸ Sinhroniziraj imenike… |

## Opombe

- **Po vsebini proti po datumu/velikosti.** Hitra primerjava ujema datoteke po velikosti in datumu spremembe, kar je hitro, a je mogoče prevarati, ko se časovni žigi razlikujejo za enake datoteke. Vklopite **po vsebini** za zanesljiv rezultat za ceno branja vsake datoteke.
- **Podmape in filtri.** Okno za sinhronizacijo lahko sestopi v podmape in ga je mogoče omejiti z masko filtra, tako da lahko sinhronizirate le vrste datotek, ki vas zanimajo.
- **Vi ohranite nadzor.** Sinhronizacija se nikoli ne izvaja sama — pregledate predlagane smeri v mreži rezultatov in lahko katero koli od njih spremenite, preden je karkoli kopirano.
- **Prednastavitve.** Pogosto uporabljene nastavitve sinhronizacije je mogoče shraniti in ponovno uporabiti, tako da ne vnašate istih možnosti vsakič.
