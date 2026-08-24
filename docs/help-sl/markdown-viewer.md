---
title: Markdown in HTML v pregledovalniku
slug: markdown-viewer
section: Vtičniki
order: 136
related: [plugins, viewing-files, privacy-and-security]
---

Pritisnite F3 na datoteki `.md` ali `.html` in prikazala se bo oblikovana, ne kot izvorno besedilo: naslovi, seznami, tabele, povezave, seznami opravil in bloki kode, obarvani po jeziku. Diagrami, zapisani kot bloki ` ```mermaid `, se narišejo, matematika med znaki za dolar pa se stavi.

To je vstavek. Vse na tej strani prihaja iz **Markdown and HTML**, ki ga lahko izklopite v **Nastavitve ▸ Vstavki…** — spodaj je opisano, kaj se takrat spremeni.

## Kje se oblikovani prikaz pojavi

- **Pregledovalnik (F3).** Oblikovana stran. Meni **Pogled** še vedno ponuja Besedilo, Kodo in Hex, izvorno besedilo je torej en klik stran, ime vstavka pa je prav tako na tem seznamu.
- **Quick View (Ctrl+Q) in stran z informacijami** v stranskem podoknu prikazujeta isto, tako da predogled in polni prikaz iste datoteke nikoli nista v nasprotju.
- **Galerija** prikaže majhno sliko začetka datoteke Markdown namesto splošne ikone dokumenta.
- **Quick Look (Cmd+Y)** je lasten predogled sistema macOS in *ni* prizadet — to okno pripada sistemu in noben vstavek v njem ne more risati.

## Pregled simbolov

Pritisnite **Simboli** v pregledovalniku, da dobite naslove dokumenta, gnezdene tako, kot so zapisani, in kliknite enega, da nanj skočite na strani. Deluje v oblikovanem prikazu in v izvornem besedilu, oba pa se strinjata, kje naslov je.

## Diagrami in matematika

Blok kode z jezikom `mermaid` postane diagram; `$…$` in `$$…$$` postaneta stavljena matematika. Oboje se nariše **na vašem Macu**, s pripomočki, ki so priloženi v vstavku — nič se ne prenaša in noben del vašega dokumenta se nikamor ne pošilja. Znak za dolar v bloku kode ali v kodi v vrstici ostane znak za dolar.

Dokument brez diagrama in brez formule ne naloži nobenega pripomočka, zato navaden README ne stane nič dodatnega. Diagram, ki ga ni mogoče prebrati, pokaže napako tam, kjer je bil blok, z besedilom bloka pod njo, namesto da bi izginil.

Oboje je mogoče izklopiti ločeno v **Nastavitve ▸ Možnosti ▸ Markdown**, kjer je tudi vidno, katera različica je v uporabi in od kod prihaja.

## Vaša lastna različica

Če potrebujete novejšo ali drugačno različico Mermaid ali KaTeX, jo dajte v mapo, ki jo odpre gumb **Engine Folder…**, in uporabljena bo namesto priložene. Imena datotek so `mermaid.min.js`, `katex.min.js`, `katex.min.css` in `auto-render.min.js`. Z interneta se za vas nikoli nič ne prenese.

## Česa oblikovana stran ne bo storila

Oblikovana stran je namenoma odrezana, ker je datoteka Markdown vsebina, ki prihaja od drugod:

- **Ne nalaga ničesar prek omrežja.** Slika, katere naslov se začne z `http`, namenoma ostane prazna: njen prenos bi tistemu strežniku povedal, kdaj ste datoteko odprli in z katerega naslova. Slika, ki leži poleg dokumenta na disku, se naloži normalno.
- **Lastni skripti in HTML dokumenta se nikoli ne izvedejo.** HTML, zapisan v datoteki Markdown, je prikazan kot besedilo, datoteka `.html` pa je prikazana z izklopljenimi skripti.

## Izklop

Izklopite vstavek v **Nastavitve ▸ Vstavki…** in datoteke `.md` ter `.html` se bodo odprle kot besedilo. Pregled še naprej deluje, barvanje skladnje še naprej deluje in nič drugega se ne spremeni — oblikovani prikaz preprosto ni več na voljo. Isto velja, če na strani z možnostmi vstavka izklopite samo oblikovani prikaz.

## Omejitve

- Datoteke nad omejitvijo velikosti (privzeto 8 MB, na strani z možnostmi) se odprejo kot besedilo. Zelo velik ustvarjen dokument spremeniti v oblikovano stran je počasno, pregledovalnik besedila pa ga odpre takoj.
- Oblikovane strani ni mogoče urejati. Za to uporabite F4 ali pogled Besedilo za **Oblikuj**, **Kodiranje** in **Pojdi na**, ki veljajo za izvorno besedilo in ne za izrisano stran.
