---
title: Izbiranje datotek
slug: selecting-files
section: Datoteke in mape
order: 22
related: [copying-files, searching]
---

Preden kar koli kopirate, premaknete, izbrišete ali stisnete, najprej Peach Commanderju poveste, na katerih elementih naj dela. Element, na katerem je vaš kazalec, je vedno trenutni element, lahko pa tudi *označite* eno ali mnogo datotek in map, tako da se ukaz izvede na vseh naenkrat. Označeni elementi izstopajo z izrazito barvo imena v podoknu.

## Označevanje datotek in map

1. Kliknite vrstico, da nanjo premaknete kazalec. En sam klik izbere samo tisti element.
2. Za označitev več elementov hkrati držite Cmd in kliknite vsakega ali držite Shift in kliknite, da označite obseg.
3. Za označitev elementa pod kazalcem in pomik navzdol v enem gibu pritisnite Insert. Pritisnite ga večkrat, da hitro označite zaporedje zaporednih elementov. Tudi preslednica preklaplja oznako trenutnega elementa (in prikaže velikost mape).
4. Za označitev vsega v podoknu izberite Označi > Izberi vse (Ctrl+Num+) ali pritisnite Cmd+A. Izberite Označi > Odznači vse (Ctrl+Num-), da počistite vse oznake.

## Izbira ali odznačitev po vzorcu

1. Izberite Označi > Izberi skupino … (Num+), da dodate elemente, katerih imena se ujemajo z vzorcem, ali Označi > Odznači skupino … (Num-), da ujemajoče se elemente odstranite iz trenutnih oznak.
2. Vnesite masko z nadomestnimi znaki. Uporabite `*` za poljubne znake in `?` za posamezen znak. Več mask ločite s podpičjem, izjeme pa naštejte za navpično črto — na primer `*.jpg;*.png` označi vse slike, `*.*|*.bak` pa označi vse razen varnostnih kopij.

![Pogovorno okno Izberi skupino z masko z nadomestnimi znaki, vnešeno v polje vzorca](screenshots/select-by-mask.png)
*(Slika: Označevanje datotek z masko z nadomestnimi znaki.)*

## Obrni, ista pripona in obnovitev

- **Obrni izbor** (Num*, meni Označi) obrne vsako oznako: označeni elementi postanejo neoznačeni in obratno — priročno za »vse razen teh«.
- **Izberi vse z isto pripono** (Alt+Num+, meni Označi) označi vsako datoteko, ki si deli pripono elementa pod kazalcem, tako da en pritisk tipke zajame na primer vse datoteke `.pdf`.
- **Obnovi izbor** (Num/, meni Označi) prikliče nazaj vaš prejšnji nabor oznak — uporabno, če jih je ukaz počistil ali ste označili napačno skupino.

## Bližnjice

| Dejanje | Tipka |
|---|---|
| Preklop oznake, pomik navzdol | Insert |
| Preklop oznake (trenutni element) | Space |
| Izberi vse / odznači vse | Ctrl+Num+ / Ctrl+Num- |
| Izberi vse (nadomestno) | Cmd+A |
| Izberi skupino po maski | Num+ |
| Odznači skupino po maski | Num- |
| Obrni izbor | Num* |
| Izberi vse z isto pripono | Alt+Num+ |
| Obnovi prejšnji izbor | Num/ |

## Opombe

- Oznake in kazalec so neodvisni: premikanje kazalca s puščičnimi tipkami ne spremeni tega, kar je označeno.
- Vnosa nadrejene mape (`..`) nikoli ni mogoče označiti.
- Izberi skupino, Odznači skupino in Obrni izbor se ujemajo z imenom datoteke, tako da lahko mape vključite ali izpustite, odvisno od možnosti pogovornega okna.
- Ko se kopiranje, premik ali brisanje konča, se elementi, ki so bili uspešno obdelani, samodejno odznačijo, tisti, ki niso uspeli, pa ostanejo označeni, da jih lahko znova poskusite.
