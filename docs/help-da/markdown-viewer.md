---
title: Markdown og HTML i fremviseren
slug: markdown-viewer
section: Plugins
order: 136
related: [plugins, viewing-files, privacy-and-security]
---

Tryk på F3 på en `.md`- eller `.html`-fil, og den vises formateret i stedet for som kildetekst: overskrifter, lister, tabeller, links, opgavelister og kodeblokke farvet efter sprog. Diagrammer skrevet som ` ```mermaid `-blokke tegnes, og matematik skrevet mellem dollartegn sættes.

Dette er et plugin. Alt på denne side kommer fra **Markdown and HTML**, som du kan slå fra i **Konfiguration ▸ Plugins…** — længere nede står, hvad der så ændrer sig.

## Hvor den formaterede visning optræder

- **Fremviseren (F3).** Den formaterede side. Menuen **Visning** tilbyder stadig Tekst, Kode og Hex, så kildeteksten er ét klik væk, og pluginets navn står også på den liste.
- **Quick View (Ctrl+Q) og infosiden** i sidepanelet viser samme gengivelse, så et forhåndsvisning og en fuld visning af samme fil aldrig er uenige.
- **Galleriet** viser et lille billede af begyndelsen på en Markdown-fil i stedet for et generisk dokumentikon.
- **Quick Look (Cmd+Y)** er macOS' egen forhåndsvisning og er *ikke* påvirket — det panel tilhører systemet, og intet plugin kan tegne i det.

## Symboloversigten

Tryk på **Symboler** i fremviseren for at få dokumentets overskrifter, indlejret som de er skrevet, og klik på en for at springe dertil på siden. Det virker på den formaterede visning og på kildeteksten, og de to er enige om, hvor en overskrift står.

## Diagrammer og matematik

En kodeblok med sproget `mermaid` bliver et diagram; `$…$` og `$$…$$` bliver sat matematik. Begge tegnes **på din Mac**, af motorer der leveres inde i pluginet — intet hentes, og ingen del af dit dokument sendes nogen steder. Et dollartegn inde i en kodeblok eller i inline-kode bliver ved med at være et dollartegn.

Et dokument uden diagram og uden formel indlæser ingen af motorerne, så en almindelig README koster ikke noget ekstra. Et diagram, der ikke kan læses, viser fejlen der, hvor blokken stod, med blokkens egen tekst nedenunder, i stedet for at forsvinde.

Begge kan slås fra hver for sig i **Konfiguration ▸ Indstillinger ▸ Markdown**, hvor man også kan se, hvilken version der er i brug, og hvor den kommer fra.

## Din egen version

Har du brug for en nyere eller anden udgave af Mermaid eller KaTeX, så læg den i den mappe, knappen **Engine Folder…** åbner, og den bruges i stedet for den medfølgende. Filnavnene er `mermaid.min.js`, `katex.min.js`, `katex.min.css` og `auto-render.min.js`. Der hentes aldrig noget fra internettet for dig.

## Lav en PDF

Med markøren på en `.md`- eller `.html`-fil skriver **Kommandoer ▸ Eksportér til PDF…** — eller samme punkt i panelets kontekstmenu — dokumentet som en PDF ved siden af det, under dets eget navn. Det tilbydes kun i almindelige mapper — inde i et arkiv eller på et monteret drev er der ingen fil på disken at læse og ingen plads ved siden af at skrive til. Markér flere dokumenter, og de eksporteres et efter et.

PDF'en er den side, du ser med F3: samme stylesheet, samme farvede kode, samme diagrammer og samme matematik. Der sættes op på A4 som standard (Letter er en indstilling), sideskiftene falder mellem afsnit, listepunkter og tabelrækker frem for midt gennem en tekstlinje, og ingen side begynder uden den overskrift, som dens afsnit starter med. Et dokument med noget, der er for bredt til tekstspalten — en tabel med mange kolonner, en lang ubrudt linje — skaleres ned, så det passer, i stedet for at blive skåret af ved kanten, sådan som en browsers egen udskrift gør det.

På pluginets indstillingsside, under **PDF**:

- **Tilbyd “Eksportér til PDF” på .md- og .html-filer** — slået fra afviser kommandoen og siger det. Selve menupunktet bliver stående: programmet bygger et plugins menuer ud fra pluginets egen beskrivelse af sig selv uden at indlæse det, så der er intet at læse en indstilling fra i det øjeblik.
- **Papir** — A4 eller US Letter.
- **Erstat en eksisterende PDF med samme navn** — slået fra som standard, så en anden eksport skrives ved siden af den første som `Name 2.pdf` i stedet for at overskrive den.
- **Vis den nye PDF i panelet** — flytter panelet til den fil, der lige er skrevet. Er dette slået fra, får du en kort besked i stedet, så en eksport aldrig er tavs.

Et dokument, der er for stort til den formaterede visning (se **Grænser**), kan heller ikke eksporteres; beskeden nævner det.

## Hvad den formaterede side ikke gør

Den formaterede side er bevidst lukket af, for en Markdown-fil er indhold, der kommer fra et andet sted:

- **Den indlæser intet over netværket.** Et billede, hvis adresse begynder med `http`, forbliver tomt med vilje: at hente det ville fortælle den server, hvornår du åbnede filen, og fra hvilken adresse. Et billede, der ligger ved siden af dokumentet på disken, indlæses normalt.
- **Dokumentets egne scripts og HTML kører aldrig.** HTML skrevet inde i en Markdown-fil vises som tekst, og en `.html`-fil vises med scripts slået fra.

## Slå det fra

Slå pluginet fra i **Konfiguration ▸ Plugins…**, og `.md`- og `.html`-filer åbnes som tekst. Oversigten virker fortsat, syntaksfarvningen virker fortsat, og intet andet ændrer sig — den formaterede visning tilbydes blot ikke. Det samme gælder, hvis du kun slår den formaterede visning fra på pluginets indstillingsside.

## Grænser

- Filer over en størrelsesgrænse (8 MB som standard, på indstillingssiden) åbnes som tekst i stedet. At gøre et meget stort genereret dokument til en formateret side er langsomt, og tekstfremviseren åbner det med det samme.
- Den formaterede side kan ikke redigeres. Brug F4 til det, eller visningen Tekst til **Formatér**, **Kodning** og **Gå til**, som gælder for kildetekst og ikke for en gengivet side.
