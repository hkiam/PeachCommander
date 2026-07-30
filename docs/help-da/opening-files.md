---
title: Åbning af filer og mapper
slug: opening-files
section: Filer og mapper
order: 20
related: [viewing-files, selecting-files]
---

Peach Commander åbner filer og mapper direkte fra begge paneler ved hjælp af de samme apps og systemfunktioner, du allerede stoler på i Finder. Tryk på en tast for at åbne emnet under markøren i dets standardapp, eller højreklik for at nå en fuld menu af handlinger — åbn med en anden app, vis emnet i Finder, del det eller åbn et Terminal-vindue lige der, hvor du står.

## Åbn et emne

1. Klik på en fil eller mappe i et panel for at sætte markøren på den (den fremhævede række).
2. Tryk på Retur (eller dobbeltklik).
   - En mappe åbnes i samme panel.
   - En fil åbnes i dens macOS-standardapp — den samme app, Finder ville bruge.
   - Et arkiv (såsom en .zip) åbnes som en mappe, så du kan gennemse indholdet.

![Peach Commanders hovedvindue med begge paneler der viser filer og mapper](screenshots/main-window.png)
*(Figur: sæt markøren på et emne, og tryk derefter på Retur for at åbne det.)*

## Åbn med en anden app, vis eller del

Højreklik på en fil (eller tryk på Shift+F10) for at åbne emnets menu, og vælg derefter:

- **Åbn** eller **Åbn i standardapp** — åbn filen som Retur ville.
- **Åbn med** — vælg en hvilken som helst installeret app, der kan åbne denne fil, eller vælg **Andet…** for at finde en.
- **Quick Look** — forhåndsvis filen uden at åbne en app.
- **Vis i Finder** — vis filen markeret i et Finder-vindue.
- **Del…** — send filen via macOS' delingsark.

Menuen fletter også de almindelige macOS-**tjenester** for den valgte fil og tilføjer **Mærker**, så du kan anvende de sædvanlige farvemærker fra Finder.

## Åbn en terminal i den aktuelle mappe

Vælg **Åbn Terminal her** fra menuen Arkiv eller Kommandoer (Cmd+Option+T) for at åbne et Terminal-vindue, der allerede er rettet mod det aktive panels mappe.

## Genveje

| Handling | Tast |
|---|---|
| Åbn emne under markøren | Retur |
| Vis fil (fremviser) | F3 |
| Rediger fil | F4 |
| Quick Look-forhåndsvisning | Cmd+Y |
| Vis info / egenskaber | Option+Retur |
| Åbn emnets menu | Shift+F10 eller højreklik |
| Åbn Terminal her | Cmd+Option+T |

## Bemærkninger

- "Standardapp" betyder den app, macOS er indstillet til at bruge for den filtype; skift den i filens Vis info-panel, præcis som i Finder.
- **Vis i Finder**, **Del…** og **Åbn med ▸ Andet…** gælder emner på din Macs disk. De er ikke tilgængelige for emner inde i et arkiv eller på en fjern (FTP/SFTP) forbindelse.
- Højreklik på en kørende proces (i en procesvisning) viser en kortere, processpecifik menu i stedet for filhandlingerne.
