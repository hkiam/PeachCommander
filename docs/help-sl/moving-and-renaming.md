---
title: Premikanje in preimenovanje
slug: moving-and-renaming
section: Datoteke in mape
order: 26
related: [copying-files, multi-rename]
---

Premikanje datoteke in mape prestavi, namesto da bi jih podvojilo, preimenovanje pa spremeni njihova imena, ne da bi se dotaknilo njihove vsebine. Ker Peach Commander prikazuje dve podokni drug ob drugem, je premikanje zgolj vprašanje izbire tistega, kar želite, v enem podoknu in pošiljanja v mapo, odprto v drugem. Element lahko tudi preimenujete na mestu ali sproti dodelite nova imena premaknjenim elementom z uporabo maske z nadomestnimi znaki.

## Premik datotek v drugo podokno

1. V izvornem podoknu odprite mapo z elementi, ki jih želite premakniti, v drugem podoknu pa odprite ciljno mapo.
2. Izberite datoteko ali mapo za premik. Za premik več hkrati jih najprej izberite vse (glejte *Izbiranje datotek*).
3. Pritisnite F6 ali izberite **Datoteka > Premakni**.
4. Preverite ciljno mapo, prikazano v pogovornem oknu, in kliknite **V redu** (ali pritisnite Return) za začetek premika.

![Pogovorno okno premika s poljem ciljne poti, možnostmi in potrditvenim poljem čakalne vrste](screenshots/copy-dialog.png)
*(Slika: Pogovorno okno premika uporablja isto ciljno polje kot kopiranje — vnesite pot ali dodajte masko z nadomestnimi znaki za preimenovanje med premikanjem.)*

Premiki na istem pogonu se zgodijo skoraj v hipu. Kadar je cilj na drugem pogonu, Peach Commander elemente skopira in izvirnike odstrani šele, ko so vse datoteke varno prispele.

## Preimenovanje na mestu

1. Izberite eno samo datoteko ali mapo.
2. Pritisnite Shift+F6 ali izberite **Datoteka > Preimenuj**.
3. Uredite ime neposredno v podoknu, nato pritisnite Return za potrditev ali Esc za preklic.

## Preimenovanje med premikanjem

Ciljno polje v pogovornem oknu premika sprejme masko z nadomestnimi znaki, tako da lahko elemente preimenujete med premikanjem:

1. Izberite elemente in pritisnite F6.
2. V ciljno polje za ciljno mapo dodajte imensko masko, na primer `/Users/you/Archive/*_backup.*`.
3. `*` stoji za izvirno ime in `.*` za izvirno pripono. Potrdite za premik in preimenovanje v enem koraku.

## Bližnjice

| Dejanje | Bližnjica |
| --- | --- |
| Premik v drugo podokno | F6 |
| Preimenovanje na mestu | Shift+F6 |

## Namigi

- Pogovorno okno premika ponuja isti gumb za možnosti in potrditveno polje čakalne vrste v ozadju kot kopiranje, tako da lahko velike premike razvrstite v čakalno vrsto in jih pustite teči v ozadju.
- Premikanje znotraj istega pogona je hitra operacija na mestu, zato je varno tudi za zelo velike mape. Premik med pogoni traja dlje, ker se podatki najprej skopirajo, nato pa se vir izbriše.
- Za preimenovanje mnogih datotek naenkrat s številčenjem, iskanjem in zamenjavo ali vzorci raje uporabite orodje za množično preimenovanje (glejte *Množično preimenovanje*).
