---
title: Åpne filer og mapper
slug: opening-files
section: Filer og mapper
order: 20
related: [viewing-files, selecting-files]
---

Peach Commander åpner filer og mapper rett fra begge paneler, ved hjelp av de samme appene og systemfunksjonene du allerede stoler på i Finder. Trykk en tast for å åpne elementet under markøren i standardappen, eller høyreklikk for å nå en fullstendig meny med handlinger — åpne med en annen app, vis elementet i Finder, del det, eller åpne et Terminal-vindu akkurat der du står.

## Åpne et element

1. Klikk på en fil eller mappe i et panel for å sette markøren på den (den uthevede raden).
2. Trykk Enter (eller dobbeltklikk).
   - En mappe åpnes i samme panel.
   - En fil åpnes i sin standard macOS-app — den samme appen Finder ville brukt.
   - Et arkiv (som en .zip) åpnes som en mappe slik at du kan bla inni det.

![Hovedvinduet i Peach Commander med begge paneler som viser filer og mapper](screenshots/main-window.png)
*(Figur: Sett markøren på et hvilket som helst element, og trykk deretter Enter for å åpne det.)*

## Åpne med en annen app, vis eller del

Høyreklikk på en fil (eller trykk Shift+F10) for å åpne elementets meny, og velg deretter:

- **Åpne** eller **Åpne i standardapp** — åpne filen slik Enter ville gjort.
- **Åpne med** — velg en hvilken som helst installert app som kan åpne denne filen, eller velg **Annet…** for å bla etter en.
- **Quick Look** — forhåndsvis filen uten å åpne en app.
- **Vis i Finder** — vis filen valgt i et Finder-vindu.
- **Del…** — send filen via macOS Delings-arket.

Menyen fletter også inn de standard macOS-**Tjenestene** for den valgte filen, og legger til **Etiketter** slik at du kan bruke de vanlige fargeetikettene fra Finder.

## Åpne en Terminal i gjeldende mappe

Velg **Åpne Terminal her** fra Fil- eller Kommandoer-menyen (Cmd+Option+T) for å åpne et Terminal-vindu som allerede peker mot det aktive panelets mappe.

## Snarveier

| Handling | Tast |
|---|---|
| Åpne element under markøren | Enter |
| Vis fil (visning) | F3 |
| Rediger fil | F4 |
| Quick Look-forhåndsvisning | Cmd+Y |
| Vis info / egenskaper | Option+Enter |
| Åpne elementets meny | Shift+F10 eller høyreklikk |
| Åpne Terminal her | Cmd+Option+T |

## Merknader

- "Standardapp" betyr appen macOS er satt til å bruke for den filtypen; endre den i filens Vis info-panel, akkurat som i Finder.
- **Vis i Finder**, **Del…** og **Åpne med ▸ Annet…** gjelder for elementer på Macens disk. De er ikke tilgjengelige for elementer inne i et arkiv eller på en ekstern (FTP/SFTP) forbindelse.
- Høyreklikk på en kjørende prosess (i en prosessvisning) viser en kortere, prosessspesifikk meny i stedet for filhandlingene.
