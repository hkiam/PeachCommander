---
title: Datotečni pripomočki
slug: file-utilities
section: Napredna orodja
order: 94
related: [comparing-and-syncing]
---

Poleg kopiranja in premikanja Peach Commander vključuje nabor vsakodnevnih datotečnih pripomočkov za preverjanje nedotaknjenosti datotek, pridobivanje prostora na disku, razbijanje velikih datotek na manjše dele in pretvarjanje datotek v in iz besedilno varnih oblik. Do vseh dostopate iz menija **Datoteka** in delujejo na tem, kar imate izbrano v dejavnem podoknu (ali na elementu pod kazalko, ko ni nič izbrano). Ta tema pokriva nadzorne vsote, iskalnik dvojnikov, razdelitev/združitev, kodiranje/dekodiranje in izračun zasedenega prostora.

## Ustvarjanje ali preverjanje nadzornih vsot

Nadzorne vsote omogočajo potrditev, da se je datoteka prenesla ali kopirala brez poškodbe, ali prejemniku dajo način za preverjanje prejete kopije.

1. Izberite datoteke, ki jih želite odtisniti.
2. Izberite **Datoteka ▸ Ustvari nadzorne vsote…**, izberite algoritem (CRC32, MD5, SHA-1, SHA-256 ali SHA-512) in shranite datoteko nadzorne vsote.
3. Za kasnejše preverjanje datotek izberite datoteko nadzorne vsote in izberite **Datoteka ▸ Preveri nadzorne vsote…**. Peach Commander ponovno izračuna vsak zgoščevalnik in prijavi vsako datoteko, ki se ne ujema.

Nadzorne vsote se izračunavajo neposredno prek trenutne lokacije, tako da jih lahko ustvarite ali preverite tudi za datoteke znotraj arhivov ali na strežniku FTP.

## Iskanje dvojnikov datotek

Iskalnik dvojnikov najde enake datoteke, raztresene po mapah, tako da lahko odstranite odvečne kopije.

1. Izberite mape (ali datoteke), ki jih želite pregledati.
2. Izberite **Datoteka ▸ Poišči dvojnike…**. Peach Commander primerja kandidate in združi datoteke, ki so enake bajt za bajtom.
3. Preglejte vsako skupino, označite kopije, ki jih ne potrebujete več, in jih izbrišite.

![Iskalnik dvojnikov, ki našteva skupine enakih datotek](screenshots/duplicate-finder.png)
*(Slika: iskalnik dvojnikov združi enake datoteke, tako da lahko obdržite eno in odstranite preostale.)*

## Razdelitev in združitev datotek

Razdelitev razbije eno veliko datoteko na oštevilčeno serijo manjših delov — priročno za omejitve shranjevanja ali prenosa. Združitev jih znova sestavi.

1. Za razdelitev izberite datoteko in izberite **Datoteka ▸ Razdeli datoteko…**, nato nastavite velikost dela. Deli se zapišejo v mapo drugega podokna.
2. Za ponovno sestavitev izberite prvi del in izberite **Datoteka ▸ Združi datoteke…**. Izvirna datoteka se obnovi iz oštevilčenih delov.

## Kodiranje in dekodiranje

Kodiranje spremeni dvojiško datoteko v navadno besedilo, da preživi kanale, ki prenašajo le besedilo (na primer starejšo e-pošto ali polja za lepljenje). Dekodiranje to obrne.

1. Izberite datoteko in izberite **Datoteka ▸ Kodiraj…**, nato izberite obliko — MIME (Base64), UUE (uuencode) ali XXE.
2. Za obnovitev izvirnika izberite kodirano datoteko in izberite **Datoteka ▸ Dekodiraj…**. Oblika se zazna samodejno.

## Izračun zasedenega prostora

Za ogled, koliko prostora mapa ali izbor dejansko uporablja na disku, izberite elemente in pritisnite **Ctrl+L** (**Datoteka ▸ Izračunaj zasedeni prostor…**). Peach Commander sešteje vsako datoteko znotraj, vključno s podmapami, in prikaže vsoto.

## Bližnjice

| Dejanje | Bližnjica |
| --- | --- |
| Izračunaj zasedeni prostor | Ctrl+L |

## Opombe

- Nadzorne vsote, razdelitev/združitev in kodiranje/dekodiranje so usmerjeni v naprednejša opravila, a vsako je eno pogovorno okno s smiselnimi privzetimi vrednostmi.
- Ko pripomoček ustvari nove datoteke (dele razdelitve, kodirano datoteko, seznam nadzornih vsot), se zapišejo v mapo, prikazano v drugem podoknu — najprej nastavite to podokno na svoj namenjeni cilj.
- Brisanje dvojnikov je trajno glede na vaše nastavitve brisanja; skrbno preglejte vsako skupino in obdržite vsaj eno kopijo vsega, kar še potrebujete.
