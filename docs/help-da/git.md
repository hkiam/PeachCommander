---
title: Git
slug: git
section: Plugins
order: 123
related: [plugins, view-modes-and-sorting]
---

Git-pluginet viser tilstanden af et Git-lager direkte i filpanelet — ingen separat app, ingen terminal. Det tilføjer to kolonner, der viser hver fils status i arbejdstræet og den aktuelle gren, en **Git**-undermenu til de daglige kommandoer (status, stage, commit, pull, push), og det bruger den `git`, der allerede er installeret på din Mac. Det er et plugin, så du kan slå det fra eller fjerne det i **Konfiguration ▸ Plugins…**.

## Hvad det tilføjer

- **To kolonner i fillisten** — *Git Status* og *Branch*. I et lager viser hver fil et kort statusord (Ændret, Tilføjet, Slettet, Usporet, Omdøbt, Kopieret, Konflikt, Ignoreret eller Forandret), og panelet viser den aktuelle gren. Slå kolonnerne til i **Konfiguration ▸ Kolonner…** (se [View modes & sorting](view-modes-and-sorting.md)).
- **En Git-menu** — under **Kommandoer ▸ Git** og i højrekliksmenuen for en fil, med: **Git Status…**, **Git Add (stage)**, **Git Commit…**, **Git Pull** og **Git Push**.

![Git Status-dialogen der viser den aktuelle gren og de ændrede filer i lageret](screenshots/git-status.png)
*(Figur: Git Status rapporterer grenen og hver ændring i arbejdstræet.)*

## Tjek status

1. Placér markøren på en fil eller mappe inde i et Git-lager.
2. Vælg **Kommandoer ▸ Git ▸ Git Status…** (eller højreklik ▸ **Git ▸ Git Status…**).
3. En opsummering vises: den aktuelle gren (eller *(detached)*), derefter enten *Working tree clean.* eller en liste over ændringer, hvor hver linje viser status og filstien.

Hvis markøren ikke er inde i et lager, siger pluginet blot *Not a Git repository.*

## Stage, commit, pull, push

- **Git Add (stage)** stager filen under markøren (`git add`).
- **Git Commit…** beder om en commit-besked og committer derefter alle ændringer (`git commit -a`). Det samlede output vises, så du kan se præcis, hvad der skete.
- **Git Pull** udfører en fast-forward-only pull (`git pull --ff-only`).
- **Git Push** pusher den aktuelle gren (`git push`).

Efter en kommando, der ændrer lageret, opdateres det aktive panel, så statuskolonnerne forbliver aktuelle.

## Bemærkninger

- Pluginet bruger systemets Git på `/usr/bin/git`. Hvis Git ikke er installeret, rapporterer kommandoerne, at Git ikke er tilgængelig. (Installering af Xcode Command Line Tools leverer den.)
- Lagerets status læses én gang pr. mappe og caches, så det forbliver hurtigt at rulle gennem et stort lager; cachen opdateres efter enhver kommando, der ændrer træet.
- Commit bruger `git commit -a`, som committer sporede ændringer; helt nye filer skal stadig igennem **Git Add (stage)** først.
- Kolonneoverskrifterne *Git Status* og *Branch* vises i øjeblikket på engelsk selv i andre grænsefladesprog; værdierne og dialogerne er lokaliseret.
