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
med **Amend** foldes ændringen i stedet ind i den forrige commit. **Fetch**, **Pull** og **Push** ligger ved siden af,
der hvor commit alligevel sker; alle tre viser forløb og kan afbrydes.

Der committes *indekset*, ikke `git commit -a`: det, du har staget, er det, der bliver committet.

## Historik i panelet

Under knapperne viser panelet historikken for alle grene, fjerngrene og tags som en tegnet graf, med arbejdskopien som første række. Området nedenunder følger markeringen:

![Git-panelet med grengrafen, det valgte merge-commit og den ændrede fil med indlejret diff](screenshots/git-panel.png)

- **Lokale ændringer** viser de stagede, ændrede og usporede filer og commit-feltet beskrevet ovenfor.
- Et commit viser enten **Commit** — forfatter, committer, dato, hash, forældre, refs, signatur og hele beskeden — eller **Ændringer**.
- **Ændringer** viser de berørte filer som et træ og diffen for den valgte fil med linjenumre; et dobbeltklik åbner sammenligningsvinduet.
- Kontekstmenuen kopierer hash eller emne, tilbagefører, cherry-picker, åbner commit'et på nettet og begrænser listen til **Kun den aktuelle gren**.
- Fra samme menu kan et commit tjekkes ud, få en ny gren eller et tag, flettes ind i den aktuelle gren, få den aktuelle gren rebaset på sig eller nulstillet til sig, eller starte en interaktiv rebase.
- Søgefeltet over listen søger i hele historikken — besked, forfatterens navn og e-mail eller en hash og dens første tegn — og viser resultaterne uden grafen.

## Mere i panelet og i Git-menuen

Arbejdskopien, historikken og menuen **Kommandoer ▸ Git** tilbyder mere end at committe:

- En markeret stagede eller ændret fil viser sin diff under listen; markerede linjer eller en hel hunk stages, unstages eller kasseres fra dens kontekstmenu.
- Commitfeltet tager flere linjer — et emne, en tom linje, en brødtekst —, committer med **Cmd+Retur** og tæller emnets tegn; menuknappen ved siden af gemmer dine seneste commitbeskeder.
- **Vis i venstre panel** og **Vis i højre panel** fører et filpanel til en fil fra listen eller fra et commits ændringer, mens Git-panelet bliver, som det er; filer, som Git LFS gemmer, er markeret **LFS**.
- Stashes vises i historikken som små firkanter over det commit, de blev lavet på, med **Anvend stash**, **Anvend og fjern stash** og **Slet stash…** i kontekstmenuen.
- **Reflog…** viser hver flytning af HEAD; et commit, der gik tabt ved en nulstilling eller en slettet gren, kommer tilbage med **Ny gren her…**.
- **Repository-indstillinger…** tilføjer, omdøber, omdirigerer og fjerner remotes, tilføjer, opdaterer og fjerner undermoduler, styrer worktrees og giver alene dette repository et navn og en e-mail til commits.
- **Opret repository her…** og **Klon repository…** arbejder i det aktive panels mappe, og uret ved siden af panelets titel går tilbage til et nyligt repository.

## Når git stopper, og indstillingerne

- **Push** sætter upstream første gang en gren pushes. Har remoten commits, som denne gren mangler, tilbyder den **Pull, derefter push** eller **Gennemtving push**, altid med en lease, der afviser, hvis nogen har pushet siden dit seneste fetch; **Gennemtving push (med lease)…** findes også i genvejsmenuen til **Push**.
- Finder **Pull** ud af, at grenen og dens upstream er gået hver sin vej, spørger den, om der skal merges eller rebases, i stedet for at stoppe ved gits besked.
- En merge, et cherry-pick, et revert, en rebase eller en patchserie, der stopper i en konflikt, viser et banner over historikken med **Fortsæt** og **Afbryd…**; et merge-commit revertes eller cherry-pickes mod sin første forælder.
- Vælg to commits for at sammenligne dem, eller flere for at cherry-picke dem på én gang. **Sammenlign med arbejdskopien** og **Gem som patch…** står i historikkens menu, **Anvend patches…** i Git-menuen.
- Søgefeltet tager også filtre — `author:name`, `path:folder/`, `since:"2 weeks ago"`, `until:2026-10-01` — alene eller sammen med ord.
- **Bisect: markér som dårlig** og **Bisect: markér som god** i historikkens menu starter en bisect; banneret tilbyder så **God**, **Dårlig**, **Spring over** og **Afslut bisect**, indtil git nævner det første dårlige commit.
- At stashe valgte filer eller alle ændringer beder om en besked, og om usporede filer skal med, eller indekset skal blive. Filer i Git LFS kan låses og låses op, og deres filtype kan spores.
- I grenlisten kan en gren omdøbes (**Omdøb…**), få en upstream (**Indstil upstream…**) eller slettes på sin server (**Slet på remoten…**).
- **Indstillinger ▸ Git** fastlægger git-programmet, dit globale navn og din e-mail, hvordan **Pull** arbejder, fetch i baggrunden, hvad historikken viser, og hvordan dens datoer ser ud, signering, sign-off og hooks for commits samt mellemrum og kontekstlinjer for diffs. Forfattere bærer farvede initialer i historikken.

## Filer, fletning, Git flow og pull requests

- **Filer** ved siden af Commit og Ændringer viser hele træet ved det valgte commit; en fil åbner med linjenumre, og dens menu sammenligner den med arbejdskopien, gemmer den et andet sted eller lægger den tilbage i arbejdskopien (**Gendan denne version…**).
- **Flettevindue…** — på en fil med konflikt i panelet, i banneret, i **Løs konflikt…** og i Git-menuen — viser den aktuelle konflikt som vores, basis og deres side om side og hele filen nedenunder, redigerbar. **Tag vores**, **Tag deres**, begge i vilkårlig rækkefølge eller **Tag basis** afgør en konflikt, og **Gem og stage** markerer filen som løst, når der ikke er flere markører.
- Grensymbolet i panelets toplinje er menuen **Git flow**: **Start feature…**, **Start release…** og **Start hotfix…** opretter grenen fra develop eller main, og **Afslut …** fletter den tilbage — en release eller et hotfix ind i main med et tag og derefter ind i develop. At afslutte igen efter en konflikt fortsætter, hvor det stoppede.
- **Pull requests…** i Git-menuen viser de åbne pull requests (merge requests hos GitLab) og issues i det projekt, remotes peger på, med hver enkelts checks; den tjekker en pull request ud i sin egen gren og åbner en ny for den aktuelle gren.
- Det kræver et personligt adgangstoken, der indtastes i vinduet og gemmes i nøgleringen; tokenet sendes kun til tjenestens API. Med et token viser et symbol ved grenen i panelets toplinje, om CI er bestået for det aktuelle commit.
- **Indstillinger ▸ Git** navngiver Git flow-grene og -præfikser og, under **Hosting**, selvhostede GitLab- eller GitHub Enterprise-servere.

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

## At ændre commit-beskeder bagefter

- **Redigér besked…** i historikkens menu åbner ét commits besked til redigering; med flere commits valgt hedder det **Redigér beskeder…**, og **Søg og erstat i beskeder…** — også **Redigér commit-beskeder…** i Git-menuen — gennemsøger beskederne på den aktuelle gren, i de commits, der ikke er pushet endnu, eller på alle grene og tags.
- Listen viser de commits, hvis besked ændres. Det valgtes besked vises, som den er, med træfferne markeret, og som den bliver, og der kan man også skrive; **Lad være som det er** tager et commit ud igen.
- **Find hemmeligheder…** søger efter tokens, nøgler og adgangskoder i de viste beskeder og udfylder søgningen med dem; **Censurér** indsætter `***REDACTED***` som erstatning.
- **Anvend…** spørger først: den viser hver ændring, hvor mange commits der får nye hashes, og hvilke grene og tags der flyttes, og advarer om commits, der allerede er pushet. Commits skrives direkte, så intet tjekkes ud, og intet kan komme i konflikt; filer, forfattere og datoer forbliver, som de var. En signatur fjernes, eller den laves igen, når **Signér commits** er slået til under **Indstillinger ▸ Git**.
- De gamle commits bevares: **Fortryd** sætter grenene tilbage, så længe ingen af dem har flyttet sig siden. En gren, der allerede er pushet, erstattes på sit fjernlager med **Gennemtving push…**, med lease.
- For en hemmelighed sletter **Fjern gamle commits…** sikkerhedskopien og de reflog-poster, som intet når mere, rydder op med prune og fortæller derefter, om et gammelt commit stadig findes. Pushede commits kan stadig være tilgængelige på serveren og i andre kloner, så en hemmelighed, der er pushet, skal også tilbagekaldes.

## At ignorere filer, og adgangsoplysninger

- **Ignorér denne fil…**, **Ignorér denne filtype…** og **Ignorér denne mappe…** skriver det rigtige mønster
  i `.gitignore` — forankret der, hvor det hører hjemme, så *denne* `build`-mappe ignoreres og ikke enhver
  mappe ved navn `build`.
- **Adgangsoplysninger…** fortæller, hvordan dette arkiv godkender sig: SSH eller HTTPS, om en credential
  helper er sat op, om en SSH-agent kører og holder en nøgle. Hvor det hjælper, tilbyder det præcis én
  handling — lade Git gemme adgangsoplysningerne i macOS-nøgleringen. Pluginet spørger aldrig om en
  adgangssætning, viser den ikke og gemmer den ikke.

## Bemærkninger

- Pluginet bruger systemets Git i `/usr/bin/git` eller programmet valgt i **Indstillinger ▸ Git**. Mangler Git, melder kommandoerne, at Git ikke er tilgængeligt. (Xcode Command Line Tools leverer det.)
- Arkivets status læses én gang pr. mappe og gemmes, så det bliver ved med at være hurtigt at rulle gennem et
  stort arkiv; cachen fornyes efter enhver kommando, der ændrer træet, og følger også en commit, der er lavet
  uden for appen.
- Tilknyttede arbejdstræer og undermoduler understøttes: en fil i et undermodul viser *undermodulets* status
  og gren, ikke det overordnede arkivs.
- Hver liste har en højrekliksmenu, **Retur** kører dens hovedhandling og **Cmd+R** genindlæser vinduet.
- Git LFS, `gpg` til signerede commits og credential-hjælpere findes i Homebrews og MacPorts’ mapper, også når appen er åbnet fra Finder.
