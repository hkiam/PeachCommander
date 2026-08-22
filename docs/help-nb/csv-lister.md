---
title: CSV-filer som tabell
slug: csv-lister
section: Programtillegg
order: 129
related: [plugins, viewing-files, log-viewer]
---

Trykk **F3** på en `.csv`- eller `.tsv`-fil, så åpnes den som en ekte tabell — kolonner, overskrifter, sortering og et filter — i stedet for som tekstlinjer med kommaer i.

Det er et programtillegg: du kan slå det av eller fjerne det under **Konfigurasjon ▸ Programtillegg…**. Uten det viser F3 filen som ren tekst, noe som for en liten fil fortsatt er fullt lesbart.

## Skilletegnet regnes ut, det antas ikke

Komma, semikolon, tabulator, loddrett strek og kolon er alle kandidater. Programtillegget teller hvert av dem over de første tjue linjene og velger det som forekommer like mange ganger på flest linjer — en fil der hver rad har fire semikolon, er en semikolonfil, uansett hva filendelsen sier. Det betyr noe i praksis: en `.csv` eksportert av et regneark på et norsk system er som regel semikolonseparert, og en `.tsv` er ikke alltid tabulatorseparert.

Den første linjen behandles som overskriftsrad og blir kolonnetitlene.

## Sortering og filtrering

Klikk på en kolonneoverskrift for å sortere på den, klikk igjen for å snu. Det sorteres **numerisk når begge verdiene er tall**, ellers alfabetisk, slik at en kolonne med størrelser sorterer 9 før 10 i stedet for etter.

Søkefeltet filtrerer mens du skriver, uten å skille mellom store og små bokstaver. Som standard ser det i alle kolonner; velg en kolonne i menyen ved siden av for bare å se der.

## Hva den ikke gjør

Tolkeren er bevisst liten, og én grense er verdt å kjenne før den overrasker deg: **et skilletegn inne i et felt med anførselstegn behandles fortsatt som skilletegn.** En rad som

```
"Smith, John",42
```

blir tre celler i stedet for to. Omkringliggende anførselstegn fjernes når de omslutter et helt felt, men utover det tolkes ikke anførselstegn. For en fil der dette betyr noe, er den innebygde viseren eller et regneark det bedre verktøyet.

Tomme linjer hoppes over, og et felt som går over flere linjer, støttes ikke.
