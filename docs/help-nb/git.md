---
title: Git
slug: git
section: Programtillegg
order: 123
related: [plugins, view-modes-and-sorting]
---

Git-programtillegget viser tilstanden til et Git-arkiv rett i filpanelet — ingen egen app, ingen terminal. Det
legger til to kolonner, en undermeny **Git**, et festet panel for å klargjøre og committe, og vinduer for
historikk, blame, grener, konflikter og rebasing. Det bruker den `git` som allerede er installert på Macen
din. Det er et programtillegg, så du kan slå det av eller fjerne det under **Konfigurasjon ▸ Programtillegg…**.

## Hva det legger til

- **To kolonner i fillisten** — *Git-status* og *Gren*. Hver fil viser et ikon og et kort statusord (Endret,
  Lagt til, Slettet, Ikke sporet, Omdøpt, Kopiert, Konflikt, Ignorert, Type endret), med *(klargjort)* når
  endringen allerede ligger i indeksen; kolonnen *Gren* viser grenen som filens arkiv står på. Slå på
  kolonnene under **Konfigurasjon ▸ Kolonner…** (se
  [Visningsmoduser og sortering](view-modes-and-sorting.md)).
- **En Git-meny** — under **Kommandoer ▸ Git**, og i høyreklikkmenyen til en fil.

![Vinduet Git-status med gjeldende gren og de endrede filene i arkivet](screenshots/git-status.png)
*(Figur: Git-status nevner grenen og hver endring i arbeidstreet.)*

## Panelet: klargjøre, committe, synkronisere

**Kommandoer ▸ Git ▸ Panel** fester en visning som grupperer arbeidstreet i *klargjort*, *endret* og *ikke
sporet*. Velg filer og bruk **Klargjør**, **Fjern klargjøring** eller **Forkast…**, skriv en melding og trykk
**Commit** — med **Amend** foldes endringen inn i forrige commit i stedet. **Pull** og **Push** ligger ved
siden av, der committen uansett skjer; begge viser framdrift og kan avbrytes.

Det er *indeksen* som committes, ikke `git commit -a`: det du har klargjort, er det som blir committet.

## Historikk, blame og nettet

- **Historikk…** lister commitene med en banegraf, refene som peker på hver av dem (`● main`,
  `↗ origin/main`, `⚑ v1.0`), og filene hver commit har rørt. Retur eller dobbeltklikk åpner filens versjon
  mot forgjengeren i sammenligningsvinduet. **Angre commit** og **Cherry-pick** ligger der, og begge nekter på
  forhånd hvis arbeidstreet ikke er rent.
- **Filhistorikk…** er det samme vinduet for én fil.
- **Blame (liste)…** viser hver linje med commit, forfatter og dato. **Blame i editoren** skriver den samme
  informasjonen i editorens marg, ved siden av linjenumrene: pek på en linje for commit-meldingen, klikk for
  å åpne den commiten mot forgjengeren.
- **Åpne på nettet** åpner filen, commiten eller grenen på GitHub, GitLab, Bitbucket eller Azure DevOps,
  bygget fra URL-en til fjernarkivet — ingen konto, ingen token. For en vert hvis lenkeoppbygning det ikke
  kjenner, tilbyr det arkivsiden i stedet for å gjette.

## Grener, stasher og merkelapper

**Grener, stasher og merkelapper…** lister alle tre. Bytt, opprett, flett eller slett en gren; push, pop eller
forkast en stash; opprett, slett eller push en merkelapp, eller bytt til den — en merkelapp er ingen gren, så
det sies på forhånd at HEAD havner frakoblet. Fetch, Pull og Push ligger i samme vindu og kan avbrytes mens de
går.

Å pushe en merkelapp er en egen handling med hensikt: `git push` tar ikke med merkelapper.

## Konflikter

**Løs konflikt…** lister de konfliktrammede områdene i filen under markøren og tar en avgjørelse for hvert av
dem: *våre*, *deres*, *begge* — eller la det stå åpent. Deretter **Skriv fil** eller **Skriv og klargjør**.
Det nekter å klargjøre så lenge et område står åpent — Git committer `<<<<<<<`-merker uten å blunke — og det
rører ikke en fil hvis merker det ikke kan lese, framfor å gjette på dem. For et område der begge sider må
flettes for hånd, er **Åpne i editor** én knapp unna.

## Rebasing

**Rebase…** lister commitene som ligger foran upstream — de ingen andre har ennå — og lar deg squashe, legge
til som fixup, forkaste, omordne eller omformulere dem før grenen skrives om. Stopper en rebase i en konflikt,
blir det samme vinduet til **Fortsett** / **Hopp over commit** / **Avbryt rebase**, slik at en halvferdig
rebase ikke må fullføres i en terminal.

## Å ignorere filer, og legitimasjon

- **Ignorer denne filen…**, **Ignorer denne filtypen…** og **Ignorer denne mappen…** skriver riktig mønster i
  `.gitignore` — forankret der det hører hjemme, slik at *denne* `build`-mappen ignoreres og ikke enhver mappe
  som heter `build`.
- **Legitimasjon…** forteller hvordan dette arkivet autentiserer seg: SSH eller HTTPS, om en credential helper
  er satt opp, om en SSH-agent kjører og holder en nøkkel. Der det hjelper, tilbyr det nøyaktig én handling —
  la Git ta vare på legitimasjonen i macOS-nøkkelringen. Programtillegget spør aldri om en passordfrase, viser
  den ikke og lagrer den ikke.

## Merknader

- Programtillegget bruker systemets Git i `/usr/bin/git`. Mangler Git, melder kommandoene at Git ikke er
  tilgjengelig. (Xcode Command Line Tools har den med.)
- Arkivstatusen leses én gang per mappe og mellomlagres, slik at det går raskt å bla i et stort arkiv; hurtig-
  lageret fornyes etter enhver kommando som endrer treet, og følger også en commit gjort utenfor appen.
- Tilknyttede arbeidstrær og undermoduler støttes: en fil i en undermodul viser *undermodulens* status og
  gren, ikke det overordnede arkivets.
- Hver liste har en kontekstmeny, **Retur** kjører hovedhandlingen og **Cmd+R** laster vinduet på nytt.
