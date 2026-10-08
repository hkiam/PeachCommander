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
din. Det er et programtillegg, så du kan slå det av eller fjerne det under **Konfigurasjon ▸ Administrer programtillegg…**.

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
**Commit** — med **Amend** foldes endringen inn i forrige commit i stedet. **Fetch**, **Pull** og **Push** ligger ved
siden av, der committen uansett skjer; alle tre viser framdrift og kan avbrytes.

Det er *indeksen* som committes, ikke `git commit -a`: det du har klargjort, er det som blir committet.

## Historikk i panelet

Under knappene viser panelet historikken for alle grener, fjerngrener og tagger som en tegnet graf, med arbeidskopien som første rad. Området under følger markeringen:

![Git-panelet med grengrafen, valgt merge-commit og den endrede filen med innebygd diff](screenshots/git-panel.png)

- **Lokale endringer** viser de stagede, endrede og usporede filene og commit-feltet beskrevet over.
- En commit viser enten **Commit** — forfatter, committer, dato, hash, foreldre, refs, signatur og hele meldingen — eller **Endringer**.
- **Endringer** viser de berørte filene som et tre og diffen for valgt fil med linjenumre; et dobbeltklikk åpner sammenligningsvinduet.
- Kontekstmenyen kopierer hash eller emne, tilbakefører, cherry-picker, åpner commiten på nettet og begrenser listen til **Bare gjeldende gren**.
- Fra samme meny kan en commit sjekkes ut, få en ny gren eller tagg, slås sammen inn i gjeldende gren, få gjeldende gren rebaset på seg eller tilbakestilt til seg, eller starte en interaktiv rebase.
- Søkefeltet over listen søker i hele historikken — melding, forfatterens navn og e-post eller en hash og de første tegnene — og viser treffene uten grafen.

## Mer i panelet og i Git-menyen

Arbeidskopien, historikken og menyen **Kommandoer ▸ Git** tilbyr mer enn å committe:

- En markert stagede eller endret fil viser diffen sin under listen; markerte linjer eller en hel hunk stages, unstages eller forkastes fra kontekstmenyen.
- Commitfeltet tar flere linjer — et emne, en tom linje, en brødtekst —, committer med **Cmd+Retur** og teller emnets tegn; menyknappen ved siden av holder dine siste commitmeldinger.
- **Vis i venstre panel** og **Vis i høyre panel** fører et filpanel til en fil fra listen eller fra en commits endringer, mens Git-panelet blir som det er; filer som Git LFS lagrer, er merket **LFS**.
- Stasher vises i historikken som små firkanter over commiten de ble laget på, med **Bruk stash**, **Bruk og fjern stash** og **Slett stash…** i kontekstmenyen.
- **Reflog…** viser hver flytting av HEAD; en commit som gikk tapt ved en tilbakestilling eller en slettet gren, kommer tilbake med **Ny gren her…**.
- **Repository-innstillinger…** legger til, gir nytt navn, omdirigerer og fjerner remotes, legger til, oppdaterer og fjerner undermoduler, styrer worktrees og gir dette repositoryet alene et navn og en e-post for commits.
- **Opprett repository her…** og **Klon repository…** arbeider i mappen til det aktive panelet, og klokken ved siden av panelets tittel går tilbake til et nylig repository.

## Når git stopper, og innstillingene

- **Push** setter upstream første gang en gren pushes. Har remoten commits denne grenen mangler, tilbyr den **Pull, deretter push** eller **Tving push**, alltid med en lease som avviser hvis noen har pushet siden din siste fetch; **Tving push (med lease)…** finnes også i hurtigmenyen til **Push**.
- Finner **Pull** at grenen og upstream har gått hver sin vei, spør den om det skal merges eller rebases i stedet for å stoppe ved gits melding.
- En merge, en cherry-pick, en revert, en rebase eller en patchserie som stopper i en konflikt, viser et banner over historikken med **Fortsett** og **Avbryt…**; en merge-commit reverteres eller cherry-pickes mot sin første forelder.
- Velg to commits for å sammenligne dem, eller flere for å cherry-picke dem på én gang. **Sammenlign med arbeidskopien** og **Lagre som patch…** står i historikkens meny, **Bruk patcher…** i Git-menyen.
- Søkefeltet tar også filtre — `author:name`, `path:folder/`, `since:"2 weeks ago"`, `until:2026-10-01` — alene eller sammen med ord.
- **Bisect: merk som dårlig** og **Bisect: merk som god** i historikkens meny starter en bisect; banneret tilbyr så **God**, **Dårlig**, **Hopp over** og **Avslutt bisect** til git nevner den første dårlige commiten.
- Å stashe valgte filer eller alle endringer ber om en melding og om usporede filer skal med eller indeksen skal bli. Filer i Git LFS kan låses og låses opp, og filtypen deres spores.
- I grenlisten kan en gren få nytt navn (**Gi nytt navn…**), få en upstream (**Angi upstream…**) eller slettes på serveren sin (**Slett på remoten…**).
- **Innstillinger ▸ Git** bestemmer git-programmet, ditt globale navn og din e-post, hvordan **Pull** arbeider, fetch i bakgrunnen, hva historikken viser og hvordan datoene ser ut, signering, sign-off og hooks for commits, og mellomrom og kontekstlinjer for differ. Forfattere har fargede initialer i historikken.

## Filer, fletting, Git flow og pull requests

- **Filer** ved siden av Commit og Endringer viser hele treet ved valgt commit; en fil åpnes med linjenumre, og menyen sammenligner den med arbeidskopien, lagrer den et annet sted eller legger den tilbake i arbeidskopien (**Gjenopprett denne versjonen…**).
- **Fletteredigering…** — på en fil med konflikt i panelet, i banneret, i **Løs konflikt…** og i Git-menyen — viser gjeldende konflikt som vår, basis og deres side om side og hele filen under, redigerbar. **Ta våre**, **Ta deres**, begge i valgfri rekkefølge eller **Ta basis** avgjør en konflikt, og **Lagre og stage** merker filen som løst når ingen markører er igjen.
- Grensymbolet i panelets topplinje er menyen **Git flow**: **Start funksjon…**, **Start release…** og **Start hotfix…** oppretter grenen fra develop eller main, og **Fullfør …** fletter den tilbake — en release eller hotfix inn i main med en tagg, så inn i develop. Å fullføre på nytt etter en konflikt fortsetter der det stoppet.
- **Pull requests…** i Git-menyen viser åpne pull requests (merge requests hos GitLab) og issues i prosjektet fjernlagrene peker på, med sjekkene for hver; den sjekker ut en pull request i en egen gren og åpner en ny for gjeldende gren.
- Det trengs et personlig tilgangstoken, som skrives inn i vinduet og lagres i nøkkelringen; tokenet sendes bare til tjenestens API. Med et token viser et symbol ved grenen i panelets topplinje om CI besto for gjeldende commit.
- **Innstillinger ▸ Git** navngir Git flow-grener og -prefikser og, under **Hosting**, selvhostede GitLab- eller GitHub Enterprise-servere.

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

## Å endre commit-meldinger i ettertid

- **Rediger melding…** i historikkens meny åpner meldingen til én commit for redigering; med flere commits valgt heter det **Rediger meldinger…**, og **Søk og erstatt i meldinger…** — også **Rediger commit-meldinger…** i Git-menyen — søker i meldingene til gjeldende gren, til commits som ikke er pushet ennå, eller til alle grener og tagger.
- Listen viser commitene der meldingen endres. Meldingen til den valgte vises slik den er, med treffene markert, og slik den blir, og der kan du også skrive; **La være som den er** tar en commit ut igjen.
- **Finn hemmeligheter…** leter etter tokener, nøkler og passord i de oppførte meldingene og fyller dem inn i søket; **Sladd** setter inn `***REDACTED***` som erstatning.
- **Bruk…** spør først: den lister hver endring, hvor mange commits som får nye hasher og hvilke grener og tagger som flyttes, og advarer mot commits som allerede er pushet. Commitene skrives direkte, så ingenting sjekkes ut og ingenting kan komme i konflikt; filer, forfattere og datoer forblir som de var. En signatur fjernes, eller lages på nytt når **Signer commits** er slått på i **Innstillinger ▸ Git**.
- De gamle commitene beholdes: **Angre** setter grenene tilbake så lenge ingen av dem har flyttet seg siden. En gren som allerede er pushet, erstattes på fjernlageret med **Tving push…**, med lease.
- For en hemmelighet sletter **Fjern gamle commits…** sikkerhetskopien og reflog-oppføringene som ingenting lenger når, rydder opp (prune) og sier deretter om en gammel commit fortsatt finnes. Commits som er pushet, kan fortsatt nås på serveren og i andre kloner, så en pushet hemmelighet må i tillegg tilbakekalles.

## Å ignorere filer, og legitimasjon

- **Ignorer denne filen…**, **Ignorer denne filtypen…** og **Ignorer denne mappen…** skriver riktig mønster i
  `.gitignore` — forankret der det hører hjemme, slik at *denne* `build`-mappen ignoreres og ikke enhver mappe
  som heter `build`.
- **Legitimasjon…** forteller hvordan dette arkivet autentiserer seg: SSH eller HTTPS, om en credential helper
  er satt opp, om en SSH-agent kjører og holder en nøkkel. Der det hjelper, tilbyr det nøyaktig én handling —
  la Git ta vare på legitimasjonen i macOS-nøkkelringen. Programtillegget spør aldri om en passordfrase, viser
  den ikke og lagrer den ikke.

## Merknader

- Programtillegget bruker systemets Git i `/usr/bin/git` eller programmet valgt i **Innstillinger ▸ Git**. Mangler Git, melder kommandoene at Git ikke er tilgjengelig. (Xcode Command Line Tools inneholder det.)
- Arkivstatusen leses én gang per mappe og mellomlagres, slik at det går raskt å bla i et stort arkiv; hurtig-
  lageret fornyes etter enhver kommando som endrer treet, og følger også en commit gjort utenfor appen.
- Tilknyttede arbeidstrær og undermoduler støttes: en fil i en undermodul viser *undermodulens* status og
  gren, ikke det overordnede arkivets.
- Hver liste har en kontekstmeny, **Retur** kjører hovedhandlingen og **Cmd+R** laster vinduet på nytt.
- Git LFS, `gpg` for signerte commits og credential-hjelpere finnes i mappene til Homebrew og MacPorts, også når appen er åpnet fra Finder.
