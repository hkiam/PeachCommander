---
title: Git
slug: git
section: Programtillegg
order: 123
related: [plugins, view-modes-and-sorting]
---

Git-programtillegget viser tilstanden til et Git-depot rett i filpanelet – ingen egen app, ingen terminal. Det legger til to kolonner som viser hver fils status i arbeidstreet og gjeldende gren, en **Git**-undermeny for de daglige kommandoene (status, klargjøring, innsjekking, pull, push), og det bruker `git` som allerede er installert på Mac-en din. Det er et programtillegg, så du kan slå det av eller fjerne det i **Konfigurasjon ▸ Programtillegg…**.

## Hva det legger til

- **To kolonner i fillisten** – *Git Status* og *Branch*. I et depot viser hver fil et kort statusord (Endret, Lagt til, Slettet, Usporet, Omdøpt, Kopiert, Konflikt, Ignorert eller Forandret) og panelet viser gjeldende gren. Slå på kolonnene i **Konfigurasjon ▸ Kolonner…** (se [Visningsmoduser og sortering](view-modes-and-sorting.md)).
- **En Git-meny** – under **Kommandoer ▸ Git**, og i høyreklikkmenyen til en fil, med: **Git Status…**, **Git Add (stage)**, **Git Commit…**, **Git Pull** og **Git Push**.

![Git Status-dialogen som viser gjeldende gren og de endrede filene i depotet](screenshots/git-status.png)
*(Figur: Git Status rapporterer grenen og hver endring i arbeidstreet.)*

## Sjekk statusen

1. Sett markøren på en fil eller mappe inne i et Git-depot.
2. Velg **Kommandoer ▸ Git ▸ Git Status…** (eller høyreklikk ▸ **Git ▸ Git Status…**).
3. Et sammendrag vises: gjeldende gren (eller *(frakoblet)*), deretter enten *Arbeidstreet er rent.* eller en liste over endringer, der hver linje viser statusen og filstien.

Hvis markøren ikke er inne i et depot, sier programtillegget ganske enkelt *Ikke et Git-depot.*

## Klargjør, sjekk inn, pull og push

- **Git Add (stage)** klargjør filen under markøren (`git add`).
- **Git Commit…** ber om en innsjekkingsmelding og sjekker deretter inn alle endringer (`git commit -a`). Den kombinerte utdataen vises, så du kan se nøyaktig hva som skjedde.
- **Git Pull** gjør en pull med kun fast-forward (`git pull --ff-only`).
- **Git Push** dytter gjeldende gren (`git push`).

Etter en kommando som endrer depotet, oppdateres det aktive panelet slik at statuskolonnene holder seg oppdaterte.

## Merknader

- Programtillegget bruker systemets Git på `/usr/bin/git`. Hvis Git ikke er installert, rapporterer kommandoene at Git ikke er tilgjengelig. (Å installere Xcode Command Line Tools gir deg det.)
- Depotstatus leses én gang per mappe og bufres, så det å bla i et stort depot forblir raskt; bufferet oppdateres etter enhver kommando som endrer treet.
- Innsjekking bruker `git commit -a`, som sjekker inn sporede endringer; helt nye filer trenger fortsatt **Git Add (stage)** først.
- Kolonneoverskriftene *Git Status* og *Branch* vises for øyeblikket på engelsk selv i andre grensesnittspråk; verdiene og dialogene er oversatt.
