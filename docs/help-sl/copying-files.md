---
title: Kopiranje datotek
slug: copying-files
section: Datoteke in mape
order: 24
related: [moving-and-renaming, background-transfers]
---

Peach Commander je zgrajen okoli dveh podoken drug ob drugem: eno vsebuje datoteke, s katerimi delate, drugo je cilj. Kopiranje vzame vse, kar je izbrano v aktivnem podoknu, in postavi dvojnik v mapo, prikazano v drugem podoknu, izvirnike pa pusti na mestu. To je najhitrejši način za podvajanje datotek in map med dvema lokacijama brez vlečenja.

## Kopiranje izbora v drugo podokno

1. V enem podoknu odprite mapo z elementi, ki jih želite kopirati.
2. V drugem podoknu odprite mapo, kamor naj gredo kopije.
3. Izberite datoteke in mape za kopiranje. Če ni izbrano nič, se uporabi element pod kazalcem.
4. Pritisnite F5. Odpre se pogovorno okno kopiranja, v katerem je ciljna pot že izpolnjena.

![Pogovorno okno kopiranja s ciljno potjo in možnostmi](screenshots/copy-dialog.png)
*(Slika: Pogovorno okno kopiranja. Ciljna pot kaže na drugo podokno; z možnostmi natančno prilagodite kopiranje.)*

5. Po potrebi prilagodite cilj, nato potrdite za začetek kopiranja.

## Možnosti kopiranja

Preden potrdite, lahko spremenite, kako se kopiranje obnaša:

- **Samo novejše datoteke** — preskoči vsak element, katerega kopija že obstaja in je enako stara ali novejša, tako da se posodobijo samo spremenjene datoteke.
- **Ohrani metapodatke** — na kopijah ohrani datume, dovoljenja in druge atribute datotek. Privzeto je vklopljeno.
- **Omejitev hitrosti** — omeji hitrost prenosa, da veliko kopiranje ne zasede vsega diska ali omrežne povezave.
- **Maska preimenovanja** — v ciljno polje vnesite vzorec z nadomestnimi znaki (na primer `*.bak`), da elemente preimenujete med kopiranjem.

Opravilo lahko namesto opazovanja pošljete tudi v čakalno vrsto v ozadju — glejte Prenosi v ozadju.

## Napredovanje

Okno napredovanja z ločenimi vrsticami prikazuje trenutno datoteko in celotno opravilo ter hitrost prenosa. Kadar koli lahko naredite premor in nadaljujete ali pa potekajoče kopiranje pošljete v upravitelja prenosov v ozadju, da lahko med dokončanjem še naprej delate.

![Pogovorno okno napredovanja prenosa z vrstico napredovanja, števci datotek in bajtov ter gumboma Premor in Prekliči](screenshots/progress-dialog.png)
*(Slika: Pogovorno okno napredovanja, prikazano med kopiranjem ali premikom.)*

## Ravnanje z datotekami, ki že obstajajo

Če bi kopiranje zamenjalo obstoječo datoteko, se Peach Commander ustavi in vpraša, kaj naj stori. Predogled obeh datotek vam pomaga pri odločitvi.

![Pogovorno okno spora ob prepisovanju, ki primerja dve datoteki](screenshots/overwrite-dialog.png)
*(Slika: Pogovorno okno prepisovanja primerja obstoječo datoteko s tisto, ki se kopira.)*

Vaše izbire vključujejo:

- **Prepiši** obstoječo datoteko ali **Prepiši vse**, da to uporabite za vsak preostali spor.
- **Preskoči** to datoteko ali **Preskoči vse** preostale spore.
- **Preimenuj** dohodno kopijo samodejno, tako da se obdržita obe datoteki.
- **Pripni** dohodne podatke na konec obstoječe datoteke.
- Prepiši samo, kadar je vir **novejši** ali **večji** od obstoječe datoteke.

## Bližnjice

| Dejanje | Tipka |
|---|---|
| Kopiranje izbora v drugo podokno | F5 |
| Kopiranje v isto mapo (izdelava preimenovanega dvojnika) | Shift+F5 |
| Odpiranje upravitelja prenosov v ozadju | Cmd+Shift+B |

## Opombe

- Kopiranje med dvema lokacijama na istem disku uporabi hitro kloniranje, kadar disk to podpira, tako da se velike datoteke skopirajo skoraj v hipu in porabijo malo dodatnega prostora.
- Mape se kopirajo z vsem, kar je v njih.
- Za premik datotek namesto kopiranja uporabite F6. Za opazovanje ali upravljanje opravil v čakalni vrsti odprite upravitelja prenosov v ozadju s Cmd+Shift+B.
