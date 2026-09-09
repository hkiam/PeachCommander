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

## Omejitev tega, kar usklajevanje zajema

Polje maske vsebuje en seznam vključitev po imenih datotek. Za to, česar z njim ni mogoče povedati, **Filter…** ob njem odpre list s tremi zavihki. Kar se tam nastavi, velja za *naslednjo* primerjavo, gumb pa nato pove, koliko meril je dejavnih — filter, ki ga ni videti, je način, kako varnostna kopija ostane nepopolna, medtem ko okno sporoča, da je končala.

- **Izpusti** sprejme vzorce, ločene z `;` ali `|`. Ime brez poševnice velja na vsaki globini (`*.tmp`), poševnica na koncu pomeni mapo z vsem, kar je v njej (`node_modules/`), vzorec s poševnico pa velja za relativno pot (`src/*/generated`). Velikost črk ni pomembna.
- **Velikost** in **datum** presojata par kot celoto: če ena stran pade izven obsega, ostane zunaj cel par. To je namerno. Uporabljeno le na eni strani bi izpustitev naredila par videti enostranski in bi postala kopiranje v napačno smer.
- **V zadnjih N dneh** se meri od vsake primerjave, ne od shranjevanja prednastavitve — shranjeno opravilo torej še naprej pomeni »zadnji mesec«.
- Zavihek **Vstavki** vpraša vsebinski vstavek o strani, s katere bi bila datoteka kopirana. Potrebuje resnično datoteko, zato je na voljo le, kadar sta obe strani mapi na tem Macu.

Izpuščena mapa se ne izbriše niti v zrcalnem načinu — zrcalo odstrani samo tisto, kar je res primerjalo. Vrstica stanja pove, koliko vnosov je filter zadržal, poleg tega, kaj bo izvedba naredila. Filter se shrani in naloži skupaj s prednastavitvijo usklajevanja, ki ji pripada.

## Dve mapi držati enaki, v obe smeri

Prvotna načina ne moreta ločiti ene stvari: datoteka, ki je le na eni strani, je bodisi **tu nova**
bodisi **tam izbrisana**, in oboje izgleda enako. Simetrični način jo zato kopira — izbrišete nekaj na
prenosniku, uskladite, in se vrne iz varnostne kopije — zrcalni način pa briše, a le v eno smer.

**Dvosmerno (s pomnjenjem)** si zapomni, kako sta mapi izgledali, ko sta se nazadnje ujemali. S tem
zapisom je mogoče izbris na eni strani prenesti na drugo.

- **Prvi** zagon para nima zapisa: obnaša se kot prej in ne izbriše ničesar. Zapis zapiše. Od drugega
  zagona naprej način deluje.
- Prenesen izbris je prikazan v svoji barvi z `⇒🗑` in **ni** označen: je edina vrstica, ki prihaja iz
  spomina programa. Klik na puščico ponudi druge odgovore: datoteko kopirati nazaj ali pustiti obe
  strani pri miru.
- Spremenjeno na eni strani in izbrisano na drugi je **spor**, nikoli izbris. Enako datoteka,
  spremenjena na obeh straneh.
- Nič se ne izbriše na podlagi odsotnosti, ki je primerjava ni mogla potrditi.
- Le dve mapi na tem Macu, ne strežnik in ne arhiv.

**Izbrisa ni mogoče razveljaviti.** Na tem Macu gre datoteka v Koš in jo je mogoče vrniti v Finderju;
to je vsa varnostna mreža. **Spomin…** v oknu našteje vsak par, ki si ga program zapomni, označi tistega, ki ga gledate, in omogoča pozabiti kateregakoli — nato se naslednja primerjava tistih map spet obnaša kot prva. Nič se nikoli ne pozabi samo: mapa na odklopljenem disku ni izgubljena, le ni priključena.

Zapis leži pri nastavitvah: če eno od map premaknete, par nima več
zgodovine — in zagon brez zgodovine ne izbriše ničesar.

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
