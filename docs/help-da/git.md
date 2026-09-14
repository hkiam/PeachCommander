---
title: Git
slug: git
section: Plugins
order: 123
related: [plugins, view-modes-and-sorting]
---

Git-pluginet viser tilstanden i et Git-arkiv direkte i filpanelet — ingen separat app, ingen terminal. Det
tilføjer to kolonner, en undermenu **Git**, et fastgjort panel til at stage og committe og vinduer til
historik, blame, grene, konflikter og rebasing. Det bruger den `git`, der allerede er installeret på din Mac.
Det er et plugin, så du kan slå det fra eller fjerne det under **Konfiguration ▸ Plugins…**.

## Hvad det tilføjer

- **To kolonner i fillisten** — *Git-status* og *Gren*. Hver fil viser et ikon og et kort statusord (Ændret,
  Tilføjet, Slettet, Ikke sporet, Omdøbt, Kopieret, Konflikt, Ignoreret, Type ændret), med *(staged)*, når
  ændringen allerede ligger i indekset; kolonnen *Gren* viser den gren, som filens arkiv står på. Slå
  kolonnerne til under **Konfiguration ▸ Kolonner…** (se
  [Visningstilstande & sortering](view-modes-and-sorting.md)).
- **En Git-menu** — under **Kommandoer ▸ Git** og i en fils højrekliksmenu.

![Vinduet Git-status med den aktuelle gren og de ændrede filer i arkivet](screenshots/git-status.png)
*(Figur: Git-status nævner grenen og hver ændring i arbejdstræet.)*

## Panelet: stage, committe, synkronisere

**Kommandoer ▸ Git ▸ Panel** fastgør en visning, der grupperer arbejdstræet i *staged*, *ændret* og *ikke
sporet*. Vælg filer og brug **Stage**, **Unstage** eller **Kassér…**, skriv en besked og tryk på **Commit** —
med **Amend** foldes ændringen i stedet ind i den forrige commit. **Pull** og **Push** ligger ved siden af,
der hvor commit alligevel sker; begge viser forløb og kan afbrydes.

Der committes *indekset*, ikke `git commit -a`: det, du har staget, er det, der bliver committet.

## Historik, blame og nettet

- **Historik…** viser commits med en banegraf, de refs, der peger på hver enkelt (`● main`, `↗ origin/main`,
  `⚑ v1.0`), og de filer, hver commit har rørt. Retur eller et dobbeltklik åbner filens version over for sin
  forgænger i sammenligningsvinduet. **Fortryd commit** og **Cherry-pick** er der, og begge nægter på forhånd,
  hvis arbejdstræet ikke er rent.
- **Filhistorik…** er det samme vindue for én fil.
- **Blame (liste)…** viser hver linje med commit, forfatter og dato. **Blame i editoren** skriver de samme
  oplysninger i editorens margen ved siden af linjenumrene: peg på en linje for commit-beskeden, klik for at
  åbne den commit over for sin forgænger.
- **Åbn på nettet** åbner filen, committen eller grenen på GitHub, GitLab, Bitbucket eller Azure DevOps,
  bygget ud fra fjernarkivets URL — ingen konto, intet token. Ved en vært, hvis linkopbygning det ikke
  kender, tilbyder det arkivets side i stedet for at gætte.

## Grene, stashes og mærkater

**Grene, stashes & mærkater…** viser alle tre. Skift, opret, flet eller slet en gren; push, pop eller kassér
en stash; opret, slet eller push en mærkat, eller skift til den — en mærkat er ikke en gren, så det siges på
forhånd, at HEAD ender frakoblet. Fetch, Pull og Push ligger i samme vindue og kan afbrydes undervejs.

At pushe en mærkat er med vilje en selvstændig handling: `git push` tager ikke mærkater med.

## Konflikter

**Løs konflikt…** viser de konfliktramte områder i filen under markøren og træffer en beslutning for hvert
enkelt: *vores*, *deres*, *begge* — eller lad det stå åbent. Derefter **Skriv fil** eller **Skriv og stage**.
Det nægter at stage, så længe et område står åbent — Git committer gladeligt `<<<<<<<`-mærker — og det rører
ikke en fil, hvis mærker det ikke kan læse, frem for at gætte på dem. For et område, der kræver, at begge
sider flettes i hånden, er **Åbn i editor** én knap væk.

## Rebasing

**Rebase…** viser de commits, der ligger foran upstream — dem, ingen andre har endnu — og lader dig squashe,
fixuppe, kassere, omordne eller omformulere dem, før grenen skrives om. Standser en rebase i en konflikt,
bliver det samme vindue til **Fortsæt** / **Spring commit over** / **Afbryd rebase**, så en halvfærdig rebase
ikke skal gøres færdig i en terminal.

## At ignorere filer, og adgangsoplysninger

- **Ignorér denne fil…**, **Ignorér denne filtype…** og **Ignorér denne mappe…** skriver det rigtige mønster
  i `.gitignore` — forankret der, hvor det hører hjemme, så *denne* `build`-mappe ignoreres og ikke enhver
  mappe ved navn `build`.
- **Adgangsoplysninger…** fortæller, hvordan dette arkiv godkender sig: SSH eller HTTPS, om en credential
  helper er sat op, om en SSH-agent kører og holder en nøgle. Hvor det hjælper, tilbyder det præcis én
  handling — lade Git gemme adgangsoplysningerne i macOS-nøgleringen. Pluginet spørger aldrig om en
  adgangssætning, viser den ikke og gemmer den ikke.

## Bemærkninger

- Pluginet bruger systemets Git i `/usr/bin/git`. Mangler Git, melder kommandoerne, at Git ikke er
  tilgængelig. (Xcode Command Line Tools indeholder den.)
- Arkivets status læses én gang pr. mappe og gemmes, så det bliver ved med at være hurtigt at rulle gennem et
  stort arkiv; cachen fornyes efter enhver kommando, der ændrer træet, og følger også en commit, der er lavet
  uden for appen.
- Tilknyttede arbejdstræer og undermoduler understøttes: en fil i et undermodul viser *undermodulets* status
  og gren, ikke det overordnede arkivs.
- Hver liste har en højrekliksmenu, **Retur** kører dens hovedhandling og **Cmd+R** genindlæser vinduet.
