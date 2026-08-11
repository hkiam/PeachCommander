---
title: Datoteke CSV kot razpredelnica
slug: csv-lister
section: Plugins
order: 129
related: [plugins, viewing-files, log-viewer]
---

Pritisnite **F3** na datoteki `.csv` ali `.tsv` in odprla se bo kot prava razpredelnica — stolpci, glave, razvrščanje in filter — namesto kot besedilne vrstice z vejicami.

To je vtičnik: izklopite ali odstranite ga lahko v **Konfiguracija ▸ Vtičniki…**. Brez njega F3 pokaže datoteko kot golo besedilo, kar je pri majhni še vedno povsem berljivo.

## Ločilo se ugotovi, ne predpostavi

Vejica, podpičje, tabulator, navpičnica in dvopičje so vsi kandidati. Vtičnik vsakega prešteje čez prvih dvajset vrstic in izbere tistega, ki se na največ vrsticah pojavi enako mnogokrat — datoteka, v kateri ima vsaka vrstica štiri podpičja, je datoteka s podpičji, karkoli pravi njena pripona. To v praksi šteje: `.csv`, ki ga izvozi preglednica na slovenskem sistemu, je običajno ločen s podpičji, `.tsv` pa ni vedno ločen s tabulatorji.

Prva vrstica velja za glavo in postane naslovi stolpcev.

## Razvrščanje in filtriranje

Kliknite glavo stolpca, da razvrstite po njem, znova kliknite za obrat. Razvršča se **številsko, kadar sta obe vrednosti števili**, sicer po abecedi, tako da stolpec z velikostmi postavi 9 pred 10 in ne za.

Iskalno polje filtrira med tipkanjem, brez razlikovanja med velikimi in malimi črkami. Privzeto gleda v vse stolpce; izberite stolpec v meniju poleg, da gleda le tam.

## Česa ne zna

Razčlenjevalnik je namerno majhen in eno omejitev je vredno poznati, preden vas preseneti: **ločilo znotraj polja v narekovajih se še vedno obravnava kot ločilo.** Vrstica, kot je

```
"Smith, John",42
```

postane tri celice namesto dveh. Obdajajoči narekovaji se odstranijo, kadar objemajo celotno polje, sicer pa se navajanje ne razlaga. Za datoteko, kjer to šteje, je vgrajeni pregledovalnik ali preglednica boljše orodje.

Prazne vrstice se preskočijo, polje, ki se razteza čez več vrstic, pa ni podprto.
