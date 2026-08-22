---
title: Loggviseren
slug: log-viewer
section: Programtillegg
order: 128
related: [plugins, viewing-files, searching]
---

Sett markøren på en loggfil og velg **Vis som logg…** for å åpne den i et vindu bygget for logger i stedet for for tekst: én rad per linje, nivået på hver linje gjenkjent og farget, et filter, og en følging som holder tritt mens filen fortsatt skrives.

Det er et programtillegg: du kan slå det av eller fjerne det under **Konfigurasjon ▸ Programtillegg…**. Uten det viser F3 en logg som enhver annen tekstfil.

![Loggviseren med en tjenestelogg, hvert nivå i sin egen farge](screenshots/log-viewer.png)
*(Figur: hvert nivå får sin egen farge, og visningen følger filen videre.)*

## Hvorfor den åpnes umiddelbart

Filen legges i minnet, og det bygges bare en indeks over hvor hver linje begynner — i bakgrunnen. Ingenting lastes inn som tekst før det er på skjermen, og bare linjene som faktisk er synlige, dekodes. En logg på flere gigabyte åpnes like raskt som en liten, og å gå til slutten leser ikke midten.

## Nivåer og farge

Hver linje klassifiseres — **Feil**, **Advarsel**, **Info**, **Feilsøking**, **Sporing**, eller **Ukjent** når formatet ikke røper noe — og farges deretter. Standardfargene følger det lyse eller mørke utseendet; angi dine egne i programtilleggets innstillinger, så brukes dine.

Kolonnen **Nivå** viser med et blikk hvor feilene sitter, og filterfeltet snevrer listen inn til det du leter etter. Slå på **Regex** for å filtrere med et regulært uttrykk i stedet for ren tekst.

## Å følge en fil som fortsatt vokser

Slå på **Direkte (rull automatisk)**, så følger vinduet slutten av filen mens nye linjer kommer: indeksen utvides over de tilføyde bytene i stedet for å bygges om, så dette forblir billig uansett hvor lang filen blir. Rull opp, og du leser historikk; følgingen går videre under.

## Å finne fram

| | |
| --- | --- |
| **Finn…** | Søker i meldingene; **Finn (merk og hopp)…** merker hvert treff så du kan gå mellom dem |
| **Gå til linje…** | Hopper til et fysisk linjenummer |
| **Gå til dato/tid…** | Hopper til den første linjen fra og med et tidsstempel, f.eks. `2024-01-15 10:23:45` |

Kopieringen vet hva en logglinje er: **Kopier linje** tar linjen under markøren, **Kopier post (alle linjer)** tar hele posten når en post går over flere linjer — en stakksporing for eksempel — og **Kopier merkede linjer** tar nøyaktig det du merket.

## Formater

**log4j**, **log4net** og **CSV** er innebygd, og formatet gjenkjennes automatisk; vinduet viser hvilket det landet på. Er loggene dine ingen av dem, legger du til ditt eget under **Loggformater** i innstillingene: et regulært uttrykk med navngitte grupper for delene som betyr noe.

```
(?<time>…)   (?<level>…)   (?<msg>…)
```

En linje uttrykket ikke passer på, vises likevel — den klassifiseres ganske enkelt som Ukjent i stedet for å bli forkastet, for en logg man ikke kan lese er verre enn en logg uten farger.

## Visning

**Vis linjenumre** og **Bryt lange linjer** ligger i innstillingene. Detaljområdet under listen viser alltid hele teksten for den merkede posten, med linjebryting, uansett hva listen gjør.
