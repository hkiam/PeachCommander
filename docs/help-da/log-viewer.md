---
title: Logfremviseren
slug: log-viewer
section: Plugins
order: 128
related: [plugins, viewing-files, searching]
---

Sæt markøren på en logfil, og vælg **Vis som log…** for at åbne den i et vindue bygget til logfiler frem for til tekst: én række pr. linje, niveauet for hver linje genkendt og farvet, et filter, og en følgning der holder trit, mens filen stadig skrives.

Det er et plugin: du kan slå det fra eller fjerne det under **Konfiguration ▸ Plugins…**. Uden det viser F3 en logfil som enhver anden tekstfil.

## Hvorfor den åbner med det samme

Filen lægges i hukommelsen, og der bygges kun et indeks over, hvor hver linje begynder — i baggrunden. Intet indlæses som tekst, før det er på skærmen, og kun de linjer, der faktisk er synlige, afkodes. En logfil på flere gigabyte åbner lige så hurtigt som en lille, og at gå til slutningen læser ikke midten.

## Niveauer og farve

Hver linje klassificeres — **Fejl**, **Advarsel**, **Info**, **Fejlfinding**, **Sporing** eller **Ukendt**, når formatet ikke røber noget — og farves derefter. Standardfarverne følger det lyse eller mørke udseende; angiv dine egne i pluginets indstillinger, så bruges dine.

Kolonnen **Niveau** viser med et blik, hvor fejlene sidder, og filterfeltet indsnævrer listen til det, du leder efter. Slå **Regex** til for at filtrere med et regulært udtryk i stedet for almindelig tekst.

## At følge en fil, der stadig vokser

Slå **Live (rul automatisk)** til, så følger vinduet filens slutning, mens nye linjer kommer til: indekset udvides over de tilføjede byte i stedet for at blive bygget om, så det forbliver billigt, uanset hvor lang filen bliver. Rul op, og du læser historik; følgningen kører videre nedenunder.

## At finde rundt

| | |
| --- | --- |
| **Find…** | Søger i beskederne; **Find (marker og hop)…** markerer hvert fund, så du kan gå fra det ene til det næste |
| **Gå til linje…** | Hopper til et fysisk linjenummer |
| **Gå til dato/tid…** | Hopper til den første linje fra og med et tidsstempel, f.eks. `2024-01-15 10:23:45` |

Kopieringen ved, hvad en loglinje er: **Kopier linje** tager linjen under markøren, **Kopier post (alle linjer)** tager hele posten, når en post strækker sig over flere linjer — et stakspor for eksempel — og **Kopier valgte linjer** tager præcis det, du valgte.

## Formater

**log4j**, **log4net** og **CSV** er indbygget, og formatet genkendes automatisk; vinduet viser, hvilket det landede på. Er dine logfiler ingen af dem, tilføjer du dit eget under **Logformater** i indstillingerne: et regulært udtryk med navngivne grupper til de dele, der betyder noget.

```
(?<time>…)   (?<level>…)   (?<msg>…)
```

En linje, udtrykket ikke passer på, vises alligevel — den klassificeres blot som Ukendt i stedet for at blive smidt væk, for en logfil, man ikke kan læse, er værre end en logfil uden farver.

## Visning

**Vis linjenumre** og **Ombryd lange linjer** står i indstillingerne. Detaljeområdet under listen viser altid hele teksten for den valgte post, ombrudt, uanset hvad listen gør.
