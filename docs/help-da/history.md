---
title: Global historik
slug: history
section: Organisér din visning
order: 47
related: [favorites, navigating]
---

Den globale historik er ét vindue, der husker dit eget arbejde: besøgte mapper, åbnede filer, udførte handlinger og kørte kommandoer. Tryk Ctrl+Cmd+H hvor som helst, begynd at skrive, og du er tilbage i gårsdagens mappe på et sekund — uden mus.

## Åbn historikken

1. Tryk Ctrl+Cmd+H, eller vælg **Gå > Historik…**. Det er uden betydning, hvilket panel der er aktivt.
2. Skriv et par bogstaver. Match behøver ikke være præcist eller sammenhængende: `proj rep` finder `~/Projects/annual-report.txt`.
3. Gå gennem resultaterne med Op- og Ned-tasterne, mens du bliver ved med at skrive.
4. Retur handler på den markerede post, Esc lukker vinduet.

Posterne er rangeret efter hvor nyligt *og* hvor ofte du brugte dem, så de steder, du arbejder mest, står allerede øverst. Fastgjorte poster går altid forrest.

## Filtrér efter type

Knapperne under søgefeltet begrænser listen til alle poster, mapper, filer, handlinger eller favoritter. Option+1 til Option+5 skifter mellem dem fra tastaturet.

## Handl på en post

| Handling | Genvej |
| --- | --- |
| Åbn den markerede post | Return |
| Vis den i panelet med markøren på den | Option+Return |
| Åbn en af de ni mest relevante poster | Cmd+1 … Cmd+9 |
| Skift panel, posterne åbnes i | Tab |
| Fastgør eller frigør posten | Cmd+P |
| Fjern posten fra historikken | Cmd+Delete |
| Kopier postens sti | Option+Cmd+C |
| Vis posten i Finder | Cmd+Shift+R |
| Luk historikken | Esc |

Retur gør det, posten fortjener: en mappe åbnes i målpanelet, en fil åbnes som den ville fra panelet, og en kommandolinje lægges i kommandolinjen, så du kan se den efter og køre den. Målpanelet står nederst i vinduet, og Tab skifter det.

## Gentag en handling

En kopiering eller flytning står under **Handlinger**, og Retur kører den igen — de samme emner til den samme mappe, gennem den almindelige overførselskø og dens spørgsmål om overskrivning. Emner, der ikke længere findes, springes over, og er ingen tilbage, får du det at vide.

Sletninger og omdøbninger står på listen, men gentages aldrig: Retur viser i stedet, hvor de skete. At gentage en sletning bør ikke ligge én tast væk i en liste, man blot skimmer.

## Hold den i kort snor

Indstillinger ▸ Andet afgør, om der føres en historik, hvor mange poster den beholder, og efter hvor mange dage den glemmer dem. Fastgjorte poster er undtaget, og 0 dage beholder alt; listen ligger i `history.ini` i din konfigurationsmappe og overlever genstarter.

## Bemærkninger

- At åbne noget fra historikken tæller som brug — derfor bliver det, du vender tilbage til, ved med at stige.
- Mapper inde i et arkiv, på en server eller i et plugindrev huskes ikke: en sådan sti betyder intet uden den montering, der frembragte den, og panelets egen historik beholder dem, så længe den er åben.
- Det er ikke panelets egen mappehistorik på Alt+Ned, som kun viser, hvor netop det panel har været, i rækkefølge.
