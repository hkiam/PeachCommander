---
title: Preimenovanje mnogih datotek
slug: multi-rename
section: Napredna orodja
order: 92
related: [moving-and-renaming]
---

Orodje za množično preimenovanje preimenuje celoten sveženj datotek v enem prehodu. Namesto urejanja imen po eno naenkrat spremembo opišete enkrat — vzorec poimenovanja, iskanje in zamenjavo, shemo oštevilčenja ali spremembo velikosti črk — in Peach Commander jo uporabi na vsaki izbrani datoteki. Predogled v živo prikaže natanko, kako se bo imenovala vsaka datoteka, preden se karkoli zgodi, en Razveljavi pa vrne izvirna imena, če rezultat ni bil tak, kot ste želeli.

## Preimenovanje svežnja datotek

1. Izberite datoteke, ki jih želite preimenovati (glejte *Izbor datotek*). Prizadeti so le izbrani elementi.
2. Izberite **Ukazi > Orodje za množično preimenovanje…** ali pritisnite Ctrl+M.
3. Zgradite pravilo preimenovanja z uporabo polj, opisanih spodaj. Mreža predogleda se med tipkanjem posodablja in prikazuje vsako **Staro ime** poleg njegovega **Novega imena**.
4. Preglejte predogled. Vrstica, prikazana v barvi poudarka, označuje ime, ki ga ni mogoče uporabiti (na primer dvojnik ali nedovoljeno ime), tako da lahko prilagodite pravilo.
5. Ko predogled izgleda pravilno, kliknite **Začni**. Če se premislite, kliknite **Razveljavi**, da obnovite izvirna imena.

![Okno za množično preimenovanje s polji mask, možnostmi in mrežo predogleda od starega do novega](screenshots/multi-rename.png)
*(Slika: mreža predogleda se posodablja v živo med urejanjem pravila preimenovanja; nič se ne spremeni na disku, dokler ne kliknete Začni.)*

## Gradnja pravila preimenovanja

- **Maska preimenovanja** in **Pripona** — vzorca, ki gradita novo ime in pripono. Uporabite gumbe za hitro vstavljanje, ali vnesite ograde neposredno: `[N]` za izvirno ime, `[N1-9]` za obseg znakov iz njega, `[C]` za števec, `[d]` za dele datuma in časa in `[P]` za ime nadrejene mape.
- **Poišči / Zamenjaj z** — zamenjaj besedilo znotraj imen. Vklopite **Regex** za ujemanje po vzorcu, **Razlikuj velikost** za natančno ujemanje velikosti črk in **Ponovi** za zamenjavo vsakega pojava.
- **Velikost črk** — pretvori imena v male črke, VELIKE ČRKE, Prva črka velika ali Vsaka Beseda Velika.
- **Števec** — nastavite **začetno** številko, **korak** med datotekami in na koliko **števk** dopolniti (na primer 001, 002, 003) povsod, kjer se pojavi `[C]`.

## Bližnjice

| Dejanje | Bližnjica |
| --- | --- |
| Odpri orodje za množično preimenovanje | Ctrl+M |
| Uporabi preimenovanje | Enter |
| Zapri okno | Esc |

## Nasveti

- Nič se ne zapiše na disk, dokler ne kliknete **Začni**, tako da lahko s pravilom prosto eksperimentirate in opazujete predogled.
- Po zagonu **Razveljavi** obrne preimenovanje v enem koraku.
- Shranite pravilo, ki ga pogosto uporabljate, kot **Prednastavitev**, nato jo naslednjič izberite iz menija prednastavitev, da naenkrat izpolnite vsa polja.
- Za preimenovanje ene datoteke ali preimenovanje datotek med njihovim premikanjem uporabite namesto tega preimenovanje na mestu ali pogovorno okno premikanja (glejte *Premikanje in preimenovanje*).
