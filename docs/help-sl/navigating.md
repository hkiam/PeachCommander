---
title: Premikanje po mapah
slug: navigating
section: Prvi koraki
order: 14
related: [interface-overview, favorites]
---

Peach Commander prikazuje dve mapi drugo ob drugi, zato večino časa premikate eno podokno iz mape v mapo. Odpirate lahko mape, se pomikate raven navzgor po hierarhiji, ponovno obiščete mesta, kjer ste že bili, neposredno vnesete pot in skočite naravnost na vsakdanja mesta, kot so Domov, Namizje in Prenosi. Vsako dejanje deluje na *aktivnem* podoknu — tistem z označeno vrstico poti.

## Odpiranje map in pomik navzgor

1. S puščičnimi tipkami premaknite izbirno vrstico, dokler ni označena mapa.
2. Pritisnite **Enter** (ali dvakrat kliknite), da jo odprete. S tem tudi vstopite v arhive in odprete datoteke s privzeto aplikacijo.
3. Za pomik raven navzgor v nadrejeno mapo pritisnite **Ctrl+PageUp** (ali **Backspace**).
4. Za skok na vrh trenutnega pogona izberite **Pojdi ▸ Koren**.

## Nazaj in naprej

Peach Commander si zapomni mape, ki ste jih obiskali v vsakem podoknu, tako kot spletni brskalnik.

- Pritisnite **Alt+Left** za pomik nazaj v prejšnjo mapo in **Alt+Right** za ponovni pomik naprej.
- Pritisnite **Alt+Down**, da odprete spustni seznam nedavnih map in skočite v katero koli od njih.

## Vnos poti ali uporaba vrstice poti

Vrstica poti na vrhu vsakega podokna prikazuje, kje se nahajate, hkrati pa je hiter način, da pridete drugam.

![Vrstica poti, ki prikazuje trenutno mapo kot segmente, po katerih lahko klikate](screenshots/path-bar-crop.png)
*(Slika: Vrstica poti. Kliknite kateri koli segment, da skočite v tisto mapo, ali svinčnik, da vnesete celotno pot.)*

- Kliknite kateri koli segment poti (na primer ime nadrejene mape), da skočite naravnost vanjo.
- Kliknite svinčnik na desni strani vrstice poti, da jo spremenite v besedilno polje, nato vnesite ali prilepite poljubno pot in pritisnite Enter.
- Lahko pa od kjer koli vnesete pot z izbiro **Datoteka ▸ Pojdi v mapo …** (**Cmd+Shift+G**).

## Skok na pogosta mesta

Meni **Pojdi** aktivno podokno popelje v mape, ki jih uporabljate najpogosteje:

- **Domov**, **Namizje**, **Prenosi**, **Koš** in **iCloud Drive**.
- **iCloud Drive** se pojavi, ko je nastavljen na vašem Macu.

## Preklapljanje med podokni in pogoni

- Pritisnite **Tab**, da premaknete fokus med levim in desnim podoknom.
- Vrstica pogonov nad vsakim podoknom navaja priklopljene nosilce s prostorom; kliknite nosilec, da nanj preklopite dano podokno.
- Pritisnite **Ctrl+U**, da zamenjate podokni (njuni mapi zamenjata strani); **Ctrl+Shift+U** ju zamenja skupaj z njunimi zavihki.
- Pritisnite **Ctrl+=**, da drugo podokno usmerite v isto mapo kot aktivno (*cilj = vir*) — priročno tik pred kopiranjem ali premikom.
- **Pojdi ▸ Levo = desno** in **Pojdi ▸ Desno = levo** naredita isto, a stran poimenujeta izrecno: prvi pokaže mapo desnega podokna na levi, drugi mapo levega podokna na desni. Drugače kot *cilj = vir* nista odvisna od tega, katero podokno je aktivno, zato njuna dva gumba v vrstici z gumbi vedno pomenita isto.

## Bližnjice

| Dejanje | Bližnjica |
| --- | --- |
| Odpri mapo / datoteko pod kazalcem | Enter |
| Pomik v nadrejeno mapo | Ctrl+PageUp (ali Backspace) |
| Nazaj / naprej po zgodovini | Alt+Left / Alt+Right |
| Spustni seznam zgodovine | Alt+Down |
| Pojdi v mapo … (vnos poti) | Cmd+Shift+G |
| Domov | Cmd+Shift+H |
| Namizje | Cmd+Shift+D |
| Prenosi | Option+Cmd+L |
| Preklop aktivnega podokna | Tab |
| Globalna zgodovina (kateri koli panel) | Ctrl+Cmd+H |

## Namigi

- Panel se posodablja sam: datoteka, ki jo drug program v prikazani mapi ustvari, spremeni ali izbriše, se pojavi sama, kazalec in izbori pa ostanejo tam, kjer so bili. V **Nastavitve ▸ Možnosti ▸ Prikaz** to izklopite, če se mapa, v katero nekaj nenehno zapisuje, osvežuje brez prestanka.
- Vsako podokno ohranja svojo zgodovino, zato Nazaj in Naprej vplivata samo na aktivno stran.
- Če vnesena pot ni veljavna mapa, vrstica poti tiho obdrži vašo zadnjo lokacijo, namesto da bi se premaknila.
- Koš in iCloud Drive v meniju Pojdi nimata privzete bližnjice, lahko pa jima jo dodelite v **Konfiguracija ▸ Možnosti ▸ Tipkovnica**.
