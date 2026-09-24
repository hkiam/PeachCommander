---
title: Markdown a HTML v prehliadači
slug: markdown-viewer
section: Zásuvné moduly
order: 136
related: [plugins, viewing-files, privacy-and-security]
---

Stlačte F3 na súbore `.md` alebo `.html` a zobrazí sa formátovaný, nie ako zdrojový text: nadpisy, zoznamy, tabuľky, odkazy, zoznamy úloh a bloky kódu zafarbené podľa jazyka. Diagramy zapísané ako bloky ` ```mermaid ` sa nakreslia a matematika medzi znakmi dolára sa vysadí.

Toto je zásuvný modul. Všetko na tejto stránke pochádza z **Markdown and HTML**, ktorý môžete vypnúť v **Konfigurácia ▸ Zásuvné moduly…** — nižšie je opísané, čo sa potom zmení.

## Kde sa formátovaný pohľad objaví

- **Prehliadač (F3).** Formátovaná stránka. Ponuka **Zobrazenie** stále nabízí Text, Kód a Hex, zdrojový text je teda jedno kliknutie ďaleko, a názov modulu je v tom zozname tiež.
- **Quick View (Ctrl+Q) a informačná stránka** v bočnom paneli zobrazujú to isté, takže náhľad a plné zobrazenie toho istého súboru si nikdy neodporujú.
- **Galéria** zobrazí malý obrázok začiatku súboru Markdown namiesto všeobecnej ikony dokumentu.
- **Quick Look (Cmd+Y)** je vlastný náhľad systému macOS a *nie je* ovplyvnený — ten panel patrí systému a žiadny modul doňho nemôže kresliť.

## Prehľad symbolov

Stlačte **Symboly** v prehliadači a získate nadpisy dokumentu, vnorené tak, ako sú zapísané; kliknutím na jeden naň na stránke preskočíte. Funguje vo formátovanom pohľade aj v zdrojovom texte a oba sa zhodujú na tom, kde nadpis je.

## Diagramy a matematika

Blok kódu s jazykom `mermaid` sa stane diagramom; `$…$` a `$$…$$` sa stanú vysadenou matematikou. Oboje sa kreslí **na vašom Macu**, nástrojmi dodanými vnútri modulu — nič sa nestahuje a žiadna časť dokumentu sa nikam neposiela. Znak dolára v bloku kódu alebo v kóde v riadku zostáva znakom dolára.

Dokument bez diagramu a bez formuly nenačíta ani jeden nástroj, obyčajný README teda nestojí nič navyše. Diagram, ktorý nemožno prečítať, zobrazí chybu tam, kde blok bol, s jeho vlastným textom pod ňou, namiesto toho, aby zmizol.

Oboje sa dá vypnúť zvlášť v **Konfigurácia ▸ Nastavenia ▸ Markdown**, kde je tiež vidieť, ktorá verzia sa používa a odkiaľ pochádza.

## Vaša vlastná verzia

Ak potrebujete novšiu alebo inú verziu Mermaid či KaTeX, vložte ju do priečinka, ktorý otvorí tlačidlo **Engine Folder…**, a použije sa namiesto dodanej. Názvy súborov sú `mermaid.min.js`, `katex.min.js`, `katex.min.css` a `auto-render.min.js`. Z internetu sa pre vás nikdy nič nestahuje.

## Vytvoriť PDF

Keď kurzor stojí na súbore `.md` alebo `.html`, **Príkazy ▸ Exportovať do PDF…** — alebo tá istá položka v kontextovej ponuke panela — zapíše dokument ako PDF vedľa neho, pod jeho vlastným menom. Ponúka sa len v bežných priečinkoch — v archíve alebo na pripojenej jednotke niet súboru na disku na čítanie ani miesta vedľa na zápis. Označte viac dokumentov a exportujú sa jeden po druhom.

PDF je tá istá stránka, ktorú vidíte pod F3: rovnaký štýl, rovnako zafarbený kód, rovnaké diagramy a rovnaká matematika. Sádza sa predvolene na A4 (Letter je nastavenie), zlomy strán padnú medzi odseky, položky zoznamu a riadky tabuľky namiesto doprostred riadku textu, a žiadna strana nezačína bez nadpisu, ktorým sa jej časť začína. Dokument s niečím, čo je širšie ako textový stĺpec — tabuľka s mnohými stĺpcami, dlhý neprerušený riadok — sa zmenší, aby sa zmestil, namiesto toho, aby bol na okraji odrezaný, tak ako to robí tlač prehliadača.

Na stránke nastavení doplnku, pod **PDF**:

- **Ponúkať „Exportovať do PDF“ pri súboroch .md a .html** — po vypnutí príkaz odmietne a povie to. Samotná položka ponuky zostáva viditeľná: aplikácia stavia ponuky doplnku z jeho vlastného popisu seba samého bez toho, aby ho načítala, takže v tej chvíli nie je odkiaľ nastavenie prečítať.
- **Papier** — A4 alebo US Letter.
- **Nahradiť existujúce PDF s rovnakým názvom** — predvolene vypnuté, takže druhý export sa zapíše vedľa prvého ako `Name 2.pdf` namiesto jeho prepísania.
- **Zobraziť nové PDF v paneli** — presunie panel na práve zapísaný súbor. Keď je to vypnuté, dostanete namiesto toho krátku správu, aby export nikdy nebol tichý.

Dokument, ktorý je príliš veľký pre formátované zobrazenie (pozri **Obmedzenia**), sa ani exportovať nedá; správa ho pomenuje.

## Čo formátovaná stránka neurobí

Formátovaná stránka je zámerne odrezaná, pretože súbor Markdown je obsah, ktorý prišel odinakiaľ:

- **Nenačítava nič po sieti.** Obrázok, ktorého adresa začína `http`, zostane zámerne prázdny: jeho stiahnutie by onomu serveru povedalo, kedy ste súbor otvorili a z akej adresy. Obrázok ležiaci vedľa dokumentu na disku sa načíta normálne.
- **Vlastné skripty a HTML dokumentu sa nikdy nespustia.** HTML zapísané v súbore Markdown sa zobrazí ako text a súbor `.html` sa zobrazí s vypnutými skriptami.

## Vypnutie

Vypnite modul v **Konfigurácia ▸ Zásuvné moduly…** a súbory `.md` a `.html` sa otvoria ako text. Prehľad ďalej funguje, farbenie syntaxe ďalej funguje a nič iné sa nemení — formátovaný pohľad sa jednoducho už nenabízí. To isté platí, ak na stránke nastavení modulu vypnete len formátovaný pohľad.

## Obmedzenia

- Súbory nad limitom veľkosti (predvolene 8 MB, na stránke nastavení) sa otvoria ako text. Premeniť veľmi veľký generovaný dokument na formátovanú stránku je pomalé a textový prehliadač ho otvorí hneď.
- Formátovanú stránku nemožno editovať. Použite na to F4 alebo pohľad Text pre **Formátovať**, **Kódovanie** a **Prejsť na**, ktoré platia pre zdrojový text, nie pre vykreslenú stránku.
