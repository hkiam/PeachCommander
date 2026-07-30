---
title: Git
slug: git
section: Zásuvné moduly
order: 123
related: [plugins, view-modes-and-sorting]
---

Zásuvný modul Git zpřístupňuje stav repozitáře Git přímo v panelu souborů — bez samostatné aplikace, bez terminálu. Přidává dva sloupce, které u každého souboru ukazují stav v pracovním stromu a aktuální větev, podnabídku **Git** pro každodenní příkazy (status, přidání do indexu, commit, pull, push), a spouští `git`, který již máte v Macu nainstalovaný. Je to zásuvný modul, takže jej můžete vypnout nebo odebrat v nabídce **Konfigurace ▸ Zásuvné moduly…**.

## Co přidává

- **Dva sloupce v seznamu souborů** — *Git Status* a *Branch*. V repozitáři každý soubor zobrazuje krátké slovo stavu (Modified, Added, Deleted, Untracked, Renamed, Copied, Conflict, Ignored nebo Changed) a panel zobrazuje aktuální větev. Sloupce zapnete v nabídce **Konfigurace ▸ Sloupce…** (viz [Režimy zobrazení a řazení](view-modes-and-sorting.md)).
- **Nabídka Git** — pod **Příkazy ▸ Git** a v místní nabídce souboru (po kliknutí pravým tlačítkem), s položkami: **Git Status…**, **Git Add (přidat do indexu)**, **Git Commit…**, **Git Pull** a **Git Push**.

![Dialog Git Status zobrazující aktuální větev a změněné soubory v repozitáři](screenshots/git-status.png)
*(Obrázek: Git Status hlásí větev a každou změnu v pracovním stromu.)*

## Kontrola stavu

1. Umístěte kurzor na soubor nebo složku uvnitř repozitáře Git.
2. Zvolte **Příkazy ▸ Git ▸ Git Status…** (nebo klepněte pravým tlačítkem ▸ **Git ▸ Git Status…**).
3. Objeví se souhrn: aktuální větev (nebo *(detached)*), poté buď *Working tree clean.*, nebo seznam změn, kde každý řádek zobrazuje stav a cestu k souboru.

Pokud kurzor není uvnitř repozitáře, zásuvný modul jednoduše oznámí *Not a Git repository.*

## Přidání do indexu, commit, pull, push

- **Git Add (přidat do indexu)** přidá soubor pod kurzorem do indexu (`git add`).
- **Git Commit…** vyžádá zprávu commitu a poté zapíše všechny změny (`git commit -a`). Zobrazí se kombinovaný výstup, takže přesně vidíte, co se stalo.
- **Git Pull** provede pull pouze s převinutím vpřed (`git pull --ff-only`).
- **Git Push** odešle aktuální větev (`git push`).

Po příkazu, který mění repozitář, se aktivní panel obnoví, takže sloupce se stavem zůstávají aktuální.

## Poznámky

- Zásuvný modul používá systémový Git na cestě `/usr/bin/git`. Pokud Git není nainstalován, příkazy nahlásí, že Git není k dispozici. (Poskytne jej instalace nástrojů Xcode Command Line Tools.)
- Stav repozitáře se pro každou složku načte jednou a uloží do mezipaměti, takže procházení velkého repozitáře zůstává rychlé; mezipaměť se obnoví po každém příkazu, který změní strom.
- Commit používá `git commit -a`, který zapíše sledované změny; zcela nové soubory je stále nutné nejprve přidat pomocí **Git Add (přidat do indexu)**.
- Záhlaví sloupců *Git Status* a *Branch* se aktuálně zobrazují anglicky i v ostatních jazycích rozhraní; hodnoty a dialogy jsou lokalizovány.
