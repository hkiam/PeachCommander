---
title: Markdown og HTML i viseren
slug: markdown-viewer
section: Plugins
order: 136
related: [plugins, viewing-files, privacy-and-security]
---

Trykk F3 på en `.md`- eller `.html`-fil, og den vises formatert i stedet for som kildetekst: overskrifter, lister, tabeller, lenker, oppgavelister og kodeblokker farget etter språk. Diagrammer skrevet som ` ```mermaid `-blokker tegnes, og matematikk skrevet mellom dollartegn settes.

Dette er et plugin. Alt på denne siden kommer fra **Markdown and HTML**, som du kan slå av i **Konfigurasjon ▸ Plugins…** — lenger ned står det hva som da endres.

## Hvor den formaterte visningen vises

- **Viseren (F3).** Den formaterte siden. Menyen **Visning** tilbyr fortsatt Tekst, Kode og Hex, så kildeteksten er ett klikk unna, og navnet på pluginet står også i listen.
- **Quick View (Ctrl+Q) og infosiden** i sidepanelet viser samme gjengivelse, slik at en forhåndsvisning og en full visning av samme fil aldri er uenige.
- **Galleriet** viser et lite bilde av begynnelsen på en Markdown-fil i stedet for et generisk dokumentikon.
- **Quick Look (Cmd+Y)** er macOS' egen forhåndsvisning og påvirkes *ikke* — det panelet tilhører systemet, og ingen plugin kan tegne i det.

## Symboloversikten

Trykk **Symboler** i viseren for å få dokumentets overskrifter, nøstet slik de er skrevet, og klikk på en for å hoppe dit på siden. Det virker på den formaterte visningen og på kildeteksten, og de to er enige om hvor en overskrift står.

## Diagrammer og matematikk

En kodeblokk med språket `mermaid` blir et diagram; `$…$` og `$$…$$` blir satt matematikk. Begge tegnes **på din Mac**, av motorer som følger med inne i pluginet — ingenting lastes ned, og ingen del av dokumentet ditt sendes noe sted. Et dollartegn inne i en kodeblokk eller i inline-kode forblir et dollartegn.

Et dokument uten diagram og uten formel laster ingen av motorene, så en vanlig README koster ingenting ekstra. Et diagram som ikke kan leses viser feilen der blokken sto, med blokkens egen tekst under, i stedet for å forsvinne.

Begge kan slås av hver for seg i **Konfigurasjon ▸ Innstillinger ▸ Markdown**, der man også ser hvilken versjon som er i bruk og hvor den kommer fra.

## Din egen versjon

Trenger du en nyere eller annen utgave av Mermaid eller KaTeX, legg den i mappen som knappen **Engine Folder…** åpner, og den brukes i stedet for den medfølgende. Filnavnene er `mermaid.min.js`, `katex.min.js`, `katex.min.css` og `auto-render.min.js`. Ingenting hentes noen gang fra internett for deg.

## Hva den formaterte siden ikke gjør

Den formaterte siden er bevisst avstengt, for en Markdown-fil er innhold som kommer et annet sted fra:

- **Den laster ingenting over nettet.** Et bilde med en adresse som begynner med `http` forblir tomt med hensikt: å hente det ville fortelle den serveren når du åpnet filen, og fra hvilken adresse. Et bilde som ligger ved siden av dokumentet på disken lastes som normalt.
- **Dokumentets egne skript og HTML kjører aldri.** HTML som står inne i en Markdown-fil vises som tekst, og en `.html`-fil vises med skript slått av.

## Slå det av

Slå pluginet av i **Konfigurasjon ▸ Plugins…**, og `.md`- og `.html`-filer åpnes som tekst. Oversikten virker fortsatt, syntaksfargingen virker fortsatt, og ingenting annet endres — den formaterte visningen tilbys bare ikke. Det samme gjelder om du bare slår av den formaterte visningen på pluginets innstillingsside.

## Grenser

- Filer over en størrelsesgrense (8 MB som standard, på innstillingssiden) åpnes som tekst i stedet. Å gjøre et svært stort generert dokument til en formatert side er langsomt, og tekstviseren åpner det med én gang.
- Den formaterte siden kan ikke redigeres. Bruk F4 til det, eller visningen Tekst til **Formater**, **Koding** og **Gå til**, som gjelder kildetekst og ikke en gjengitt side.
