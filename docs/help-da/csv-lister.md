---
title: CSV-filer som tabel
slug: csv-lister
section: Plugins
order: 129
related: [plugins, viewing-files, log-viewer]
---

Tryk **F3** på en `.csv`- eller `.tsv`-fil, så åbner den som en rigtig tabel — kolonner, overskrifter, sortering og et filter — i stedet for som tekstlinjer med kommaer i.

Det er et plugin: du kan slå det fra eller fjerne det under **Konfiguration ▸ Plugins…**. Uden det viser F3 filen som ren tekst, hvilket for en lille fil stadig er fint læsbart.

## Skilletegnet regnes ud, det antages ikke

Komma, semikolon, tabulator, lodret streg og kolon er alle kandidater. Pluginet tæller hvert af dem over de første tyve linjer og vælger det, der optræder lige mange gange på flest linjer — en fil, hvor hver række har fire semikolonner, er en semikolonfil, uanset hvad endelsen siger. Det betyder noget i praksis: en `.csv` eksporteret af et regneark på et dansk system er som regel semikolonadskilt, og en `.tsv` er ikke altid tabulatoradskilt.

Den første linje behandles som overskriftsrække og bliver til kolonnetitlerne.

## Sortering og filtrering

Klik på en kolonneoverskrift for at sortere efter den, klik igen for at vende om. Der sorteres **numerisk, når begge værdier er tal**, og ellers alfabetisk, så en kolonne med størrelser sorterer 9 før 10 i stedet for efter.

Søgefeltet filtrerer, mens du skriver, uden hensyn til store og små bogstaver. Som standard kigger det i alle kolonner; vælg en kolonne i menuen ved siden af for kun at kigge der.

## Hvad den ikke gør

Fortolkeren er bevidst lille, og én grænse er værd at kende, før den overrasker dig: **et skilletegn inde i et felt med anførselstegn behandles stadig som skilletegn.** En række som

```
"Smith, John",42
```

bliver til tre celler i stedet for to. Omgivende anførselstegn fjernes, når de omslutter et helt felt, men derudover fortolkes anførselstegn ikke. Til en fil, hvor det betyder noget, er den indbyggede fremviser eller et regneark det bedre værktøj.

Tomme linjer springes over, og et felt, der strækker sig over flere linjer, understøttes ikke.
