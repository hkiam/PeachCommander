---
title: Pregledovalnik dnevnikov
slug: log-viewer
section: Vtičniki
order: 128
related: [plugins, viewing-files, searching]
---

Postavite kazalec na datoteko dnevnika in izberite **Pokaži kot dnevnik…**, da se odpre v oknu, zgrajenem za dnevnike in ne za besedilo: ena vrstica na vrstico, raven vsake prepoznana in obarvana, filter in sledenje, ki drži korak, medtem ko se datoteka še zapisuje.

To je vtičnik: izklopite ali odstranite ga lahko v **Konfiguracija ▸ Vtičniki…**. Brez njega F3 pokaže dnevnik tako kot vsako drugo besedilno datoteko.

## Zakaj se odpre takoj

Datoteka se preslika v pomnilnik, v ozadju pa se zgradi le kazalo, kje se začne posamezna vrstica. Nič se ne naloži kot besedilo, dokler ni na zaslonu, in dekodirajo se le dejansko vidne vrstice. Dnevnik z več gigabajti se odpre enako hitro kot majhen, skok na konec pa ne prebere sredine.

## Ravni in barva

Vsaka vrstica se uvrsti — **Napaka**, **Opozorilo**, **Info**, **Razhroščevanje**, **Sledenje** ali **Neznano**, kadar zapis ničesar ne izda — in se temu ustrezno obarva. Privzete barve sledijo svetlemu ali temnemu videzu; nastavite svoje v nastavitvah vtičnika in uporabljene bodo vaše.

Stolpec **Raven** na prvi pogled pokaže, kje so napake, filtrirno polje pa zoži seznam na to, kar iščete. Vklopite **Regex**, da filtrirate z regularnim izrazom namesto z navadnim besedilom.

## Slediti datoteki, ki še raste

Vklopite **V živo (samodejno drsenje)** in okno bo sledilo koncu datoteke, ko prihajajo nove vrstice: kazalo se razširi čez pripete bajte, namesto da bi se zgradilo znova, zato ostane poceni, ne glede na to, kako dolga postane datoteka. Podrsajte navzgor in berete zgodovino; sledenje teče naprej spodaj.

## Znajti se

| | |
| --- | --- |
| **Poišči…** | Išče po sporočilih; **Poišči (označi in skoči)…** označi vsak zadetek, da lahko koračite med njimi |
| **Pojdi na vrstico…** | Skoči na fizično številko vrstice |
| **Pojdi na datum/čas…** | Skoči na prvo vrstico od navedenega časovnega žiga naprej, npr. `2024-01-15 10:23:45` |

Kopiranje ve, kaj je vrstica dnevnika: **Kopiraj vrstico** vzame vrstico pod kazalcem, **Kopiraj vnos (vse vrstice)** vzame celoten vnos, kadar se ta razteza čez več vrstic — na primer izpis sklada — in **Kopiraj izbrane vrstice** vzame natanko to, kar ste izbrali.

## Zapisi

**log4j**, **log4net** in **CSV** so vgrajeni, zapis pa se prepozna samodejno; okno pokaže, pri katerem se je ustavilo. Če vaši dnevniki niso nobeden od teh, dodajte svojega v nastavitvah pod **Zapisi dnevnikov**: regularni izraz z imenovanimi skupinami za dele, ki štejejo.

```
(?<time>…)   (?<level>…)   (?<msg>…)
```

Vrstica, ki se izrazu ne ujema, se vseeno prikaže — preprosto se uvrsti kot Neznano, namesto da bi bila zavržena, kajti dnevnik, ki ga ni mogoče brati, je slabši od dnevnika brez barv.

## Prikaz

**Pokaži številke vrstic** in **Prelomi dolge vrstice** sta v nastavitvah. Območje s podrobnostmi pod seznamom vedno pokaže celotno besedilo izbranega vnosa, prelomljeno, ne glede na to, kaj počne seznam.
