---
title: CSV-fájlok táblázatként
slug: csv-lister
section: Plugins
order: 129
related: [plugins, viewing-files, log-viewer]
---

Nyomja meg az **F3** billentyűt egy `.csv` vagy `.tsv` fájlon, és valódi táblázatként nyílik meg — oszlopok, fejlécek, rendezés és szűrő —, nem pedig vesszőkkel teli szövegsorokként.

Bővítmény: kikapcsolhatja vagy eltávolíthatja a **Konfiguráció ▸ Bővítmények…** alatt. Nélküle az F3 sima szövegként mutatja a fájlt, ami egy kicsinél továbbra is jól olvasható.

## Az elválasztót kiszámolja, nem feltételezi

A vessző, a pontosvessző, a tabulátor, a függőleges vonal és a kettőspont mind szóba jön. A bővítmény mindegyiket megszámolja az első húsz sorban, és azt választja, amelyik a legtöbb soron ugyanannyiszor fordul elő — az a fájl, amelynek minden sorában négy pontosvessző van, pontosvesszős fájl, bármit is mond a kiterjesztése. Ez a gyakorlatban számít: egy magyar rendszeren táblázatkezelőből exportált `.csv` általában pontosvesszővel elválasztott, egy `.tsv` pedig nem mindig tabulátorral.

Az első sor fejlécsornak számít, és belőle lesznek az oszlopcímek.

## Rendezés és szűrés

Kattintson egy oszlopfejlécre a szerinte való rendezéshez, még egyszer a megfordításához. A rendezés **számszerű, ha mindkét érték szám**, egyébként betűrendes, így egy méreteket tartalmazó oszlop a 9-et a 10 elé rendezi, nem mögé.

A keresőmező gépelés közben szűr, a kis- és nagybetűket nem különböztetve meg. Alapértelmezés szerint minden oszlopban néz; a mellette lévő menüből válasszon oszlopot, hogy csak ott keressen.

## Amit nem tud

Az elemző szándékosan kicsi, és egy korlátot érdemes ismerni, mielőtt meglepi: **az idézőjeles mezőn belüli elválasztó továbbra is elválasztónak számít.** Egy ilyen sor:

```
"Smith, John",42
```

két cella helyett hárommá válik. A körülvevő idézőjelek eltávolításra kerülnek, ha egy egész mezőt fognak közre, ezen túl azonban az idézőjelezés nem kerül értelmezésre. Olyan fájlhoz, ahol ez számít, a beépített megjelenítő vagy egy táblázatkezelő a jobb eszköz.

Az üres sorokat átugorja, és a több sorra kiterjedő mezőt nem támogatja.
