---
title: Hitro iskanje in filter
slug: quick-search-and-filter
section: Urejanje pogleda
order: 44
related: [searching, view-modes-and-sorting]
---

Ko mapa vsebuje stotine elementov, le redko potrebujete drsenje. Peach Commander vam omogoča, da skočite naravnost do datoteke z vnosom njenega imena (hitro iskanje), zmanjšate seznam le na elemente, ki vas zanimajo (hitri filter), ter prikažete ali skrijete pikaste datoteke, ki jih macOS običajno drži zunaj pogleda. Vsi trije delujejo znotraj dejavnega podokna brez odpiranja pogovornega okna.

## Skok na datoteko z vnosom (hitro iskanje)

1. Kliknite podokno z datotekami, da postane dejavno.
2. Začnite tipkati začetek imena. Kazalka skoči na prvi ujemajoči element.
3. Nadaljujte tipkanje za izboljšanje ujemanja, ali se s ↑ in ↓ premikajte med zadetki, dokler je iskanje prikazano. Ponovni pritisk iste črke prav tako kroži po elementih, ki se z njo začnejo.
4. Vneseno besedilo se po kratkem premoru počisti, tako da lahko kadar koli začnete novo iskanje.

Privzeto navadne črke gredo v ukazno vrstico, hitro iskanje pa se sproži s Ctrl+Option+črka (klasično obnašanje). Hitro iskanje lahko preklopite, da se odziva na navadno tipkanje, ali ga izklopite, v nastavitvah konfiguracije.

## Filtriranje seznama (hitri filter)

1. V dejavnem podoknu pritisnite Ctrl+S, da vklopite hitri filter.
2. Vnesite masko filtra. Panel se med tipkanjem sproti zoži na ustrezajoče elemente, kurzor pa ostane na elementu, ki ste ga gledali, dokler ga ožja maska ohranja.
3. Po rezultatu se premikajte s ↑ in ↓. V filtriranem seznamu se puščici ovijeta, tako da zadnji element vodi nazaj na začetek in kratek rezultat lahko krožno pregledate, ne da bi obtičali na koncih.
4. Pritisnite Esc, da počistite filter in znova prikažete vse. Kurzor ostane na najdenem elementu, zdaj prikazanem med sosedi.

Filter sprejema več vrst mask:

- **Navadno besedilo** se ujema s katerim koli imenom, ki vsebuje, kar ste vnesli (na primer `poročilo` prikaže vsak element z »poročilo« kjer koli v imenu).
- **Nadomestni znaki** uporabljajo `*` (kateri koli znaki) in `?` (en znak). Ločite več mask s podpičjem in dodajte izključitve za navpično črto, na primer `*.jpg;*.png|*thumb*` za prikaz slik, a skrivanje sličic.
- **Oznake Finder** filtrirajo po barvi oznake: vnesite `tag:red` (ali `#red`) za prikaz le elementov z rdečo oznako, ali golo `tag:` za prikaz vsega, kar nosi katero koli oznako.

## Prikaz skritih datotek

Pritisnite Ctrl+H, ali izberite ukaz iz menija Pogled, da preklopite skrite elemente (imena, ki se začnejo s piko, in sistemsko skrite datoteke). Nastavitev velja za dejavno podokno in se ohrani med sejami.

## Bližnjice

| Dejanje | Bližnjica |
| --- | --- |
| Hitro iskanje (klasični način) | Ctrl+Option+črka |
| Prejšnji / naslednji zadetek (med hitrim iskanjem) | ↑ / ↓ |
| Hitri filter vklop/izklop | Ctrl+S |
| Počisti filter / prekliči | Esc |
| Prikaži/skrij skrite datoteke | Ctrl+H |

## Opombe

- Hitro iskanje le premakne kazalko; hitri filter dejansko spremeni, kateri elementi so našteti. Filter uporabite, ko želite delati na podmnožici (na primer izbrati ali kopirati le ujemanja).
- Nastavitvi filtra in skritih datotek veljata za vsako podokno, tako da lahko obe strani hkrati prikazujeta različne stvari.
- Hitro iskanje ujema imena od začetka; način navadnega besedila hitrega filtra ujema kjer koli v imenu. Uporabite nadomestni znak, kot je `*besedilo*`, če želite, da se filter obnaša enako.
