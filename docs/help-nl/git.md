---
title: Git
slug: git
section: Plug-ins
order: 123
related: [plugins, view-modes-and-sorting]
---

De Git-plug-in laat de toestand van een Git-repository rechtstreeks in het bestandspaneel zien — geen aparte
app, geen terminal. Hij voegt twee kolommen toe, een submenu **Git**, een vastgezet paneel om te stagen en te
committen, en vensters voor geschiedenis, blame, branches, conflicten en rebasen. Hij gebruikt de `git` die al
op uw Mac staat. Het is een plug-in, dus u kunt hem uitschakelen of verwijderen in **Configuratie ▸
Plug-ins…**.

## Wat hij toevoegt

- **Twee kolommen in de bestandslijst** — *Git-status* en *Branch*. Elk bestand toont een pictogram en een
  kort statuswoord (Gewijzigd, Toegevoegd, Verwijderd, Niet gevolgd, Hernoemd, Gekopieerd, Conflict,
  Genegeerd, Type gewijzigd), met *(gestaged)* als de wijziging al in de index zit; de kolom *Branch* toont de
  branch waarop de repository van dat bestand staat. Zet de kolommen aan in **Configuratie ▸ Kolommen…** (zie
  [Weergavemodi & sorteren](view-modes-and-sorting.md)).
- **Een Git-menu** — onder **Opdrachten ▸ Git**, en in het contextmenu van een bestand.

![Het venster Git-status met de huidige branch en de gewijzigde bestanden in de repository](screenshots/git-status.png)
*(Afbeelding: Git-status noemt de branch en elke wijziging in de werkmap.)*

## Het paneel: stagen, committen, synchroniseren

**Opdrachten ▸ Git ▸ Paneel** zet een weergave vast die de werkmap groepeert in *gestaged*, *gewijzigd* en
*niet gevolgd*. Selecteer bestanden en gebruik **Stage**, **Unstage** of **Weggooien…**, typ een bericht en
druk op **Commit** — met **Amend** om de wijziging in de vorige commit te vouwen. **Fetch**, **Pull** en **Push** staan
ernaast, waar de commit toch al plaatsvindt; alle drie tonen voortgang en kunnen worden afgebroken.

Er wordt de *index* gecommit, niet `git commit -a`: wat u hebt gestaged, is wat er wordt gecommit.

## Geschiedenis in het paneel

Onder de knoppen toont het paneel de geschiedenis van alle branches, remote branches en tags als getekende graaf, met de werkkopie als eerste rij. Het gebied eronder volgt de selectie:

![Het Git-paneel met de branchgraaf, de geselecteerde merge-commit en het gewijzigde bestand met inline diff](screenshots/git-panel.png)

- **Lokale wijzigingen** toont de gestagede, gewijzigde en niet-gevolgde bestanden en het commitvak hierboven.
- Een commit toont **Commit** — auteur, committer, datum, hash, ouders, refs, handtekening en volledig bericht — of **Wijzigingen**.
- **Wijzigingen** toont de geraakte bestanden als boom en de diff van het gekozen bestand met regelnummers; dubbelklikken opent het vergelijkvenster.
- Het contextmenu kopieert hash of onderwerp, draait terug, cherry-pickt, opent de commit op het web en beperkt de lijst tot **Alleen de huidige branch**.
- Vanuit hetzelfde menu kan een commit worden uitgecheckt, een nieuwe branch of tag krijgen, in de huidige branch worden samengevoegd, de huidige branch erop laten rebasen of herstellen, of een interactieve rebase starten.
- Het zoekveld boven de lijst doorzoekt de hele geschiedenis — bericht, naam en e-mail van de auteur, of een hash en de eerste tekens ervan — en toont de treffers zonder graaf.

## Meer in het paneel en in het Git-menu

De werkkopie, de geschiedenis en het menu **Commando’s ▸ Git** bieden meer dan committen:

- Een geselecteerd gestaged of gewijzigd bestand toont zijn diff onder de lijst; geselecteerde regels of een hele hunk worden via het contextmenu gestaged, ge-unstaged of verworpen.
- Het commitveld neemt meerdere regels — een onderwerp, een lege regel, een tekst —, commit met **Cmd+Return** en telt de tekens van het onderwerp; de menuknop ernaast bewaart je laatste commitberichten.
- **Tonen in het linkerpaneel** en **Tonen in het rechterpaneel** brengen een bestandspaneel naar een bestand uit de lijst of uit de wijzigingen van een commit, terwijl het Git-paneel blijft zoals het is; bestanden die Git LFS bewaart, zijn gemarkeerd met **LFS**.
- Stashes verschijnen in de geschiedenis als kleine vierkantjes boven de commit waarop ze zijn gemaakt, met **Stash toepassen**, **Stash toepassen en verwijderen** en **Stash verwijderen…** in het contextmenu.
- **Reflog…** toont elke verplaatsing van HEAD; een commit die verloren ging door een reset of een verwijderde branch komt terug met **Nieuwe branch hier…**.
- **Repository-instellingen…** voegt remotes toe, hernoemt ze, wijst ze om en verwijdert ze, voegt submodules toe, werkt ze bij en verwijdert ze, beheert worktrees en geeft alleen deze repository een naam en e-mail voor commits.
- **Repository hier aanmaken…** en **Repository klonen…** werken in de map van het actieve paneel, en de klok naast de titel van het paneel gaat terug naar een recente repository.

## Als git stopt, en de instellingen

- **Push** stelt de upstream in bij de eerste push van een branch. Heeft de remote commits die deze branch mist, dan biedt het **Pullen, dan pushen** of **Geforceerd pushen** aan, altijd met een lease die weigert als iemand sinds je laatste fetch heeft gepusht; **Geforceerd pushen (met lease)…** staat ook in het contextmenu van **Push**.
- Merkt **Pull** dat de branch en zijn upstream uiteengelopen zijn, dan vraagt het of er gemerged of gerebased moet worden in plaats van te stoppen bij de melding van git.
- Een merge, cherry-pick, revert, rebase of patchreeks die in een conflict stopt, toont boven de geschiedenis een banner met **Doorgaan** en **Afbreken…**; een mergecommit wordt teruggedraaid of gecherry-pickt tegen zijn eerste ouder.
- Selecteer twee commits om ze te vergelijken, of meerdere om ze in één keer te cherry-picken. **Vergelijken met de werkkopie** en **Opslaan als patch…** staan in het menu van de geschiedenis, **Patches toepassen…** in het Git-menu.
- Het zoekveld neemt ook filters — `author:name`, `path:folder/`, `since:"2 weeks ago"`, `until:2026-10-01` — los of samen met woorden.
- **Bisect: als slecht markeren** en **Bisect: als goed markeren** in het menu van de geschiedenis starten een bisect; de banner biedt dan **Goed**, **Slecht**, **Overslaan** en **Bisect beëindigen** tot git de eerste slechte commit noemt.
- Geselecteerde bestanden of alle wijzigingen stashen vraagt om een bericht en of niet-gevolgde bestanden meegaan of de index blijft. Bestanden in Git LFS kunnen worden vergrendeld en ontgrendeld, en hun bestandstype gevolgd.
- In de branchlijst kan een branch worden hernoemd (**Hernoemen…**), een upstream krijgen (**Upstream instellen…**) of op zijn server worden verwijderd (**Op de remote verwijderen…**).
- **Instellingen ▸ Git** bepaalt het git-programma, je globale naam en e-mail, hoe **Pull** werkt, fetchen op de achtergrond, wat de geschiedenis toont en hoe de datums eruitzien, ondertekenen, sign-off en hooks voor commits, en witruimte en contextregels voor diffs. Auteurs dragen gekleurde initialen in de geschiedenis.

## Bestanden, samenvoegen, Git flow en pull requests

- **Bestanden** naast Commit en Wijzigingen toont de hele boom bij de gekozen commit; een bestand opent met regelnummers, en het menu ervan vergelijkt het met de werkkopie, slaat het elders op of zet het terug in de werkkopie (**Deze versie herstellen…**).
- **Merge-editor…** — bij een bestand met een conflict in het paneel, in de banner, in **Conflict oplossen…** en in het Git-menu — toont het huidige conflict als ons, basis en hun naast elkaar en daaronder het hele bestand, bewerkbaar. **Onze nemen**, **Hun nemen**, beide in een van beide volgordes of **Basis nemen** beslissen een conflict, en **Opslaan en stagen** markeert het bestand als opgelost zodra er geen markeringen meer zijn.
- Het branchsymbool in de kop van het paneel is het menu **Git flow**: **Feature beginnen…**, **Release beginnen…** en **Hotfix beginnen…** maken de branch vanaf develop of main, en **… afronden** voegt hem terug — een release of hotfix in main met een tag, daarna in develop. Opnieuw afronden na een conflict gaat verder waar het stopte.
- **Pull requests…** in het Git-menu toont de open pull requests (merge requests bij GitLab) en issues van het project waar de remotes naar wijzen, met de checks van elk; het checkt een pull request uit in een eigen branch en opent een nieuwe voor de huidige branch.
- Daarvoor is een persoonlijk toegangstoken nodig, ingevoerd in dat venster en bewaard in de sleutelhanger; het token gaat alleen naar de API van de dienst. Met een token laat een symbool naast de branch in de kop van het paneel zien of de CI voor de huidige commit is geslaagd.
- **Instellingen ▸ Git** benoemt de branches en voorvoegsels van Git flow en, onder **Hosting**, zelf gehoste GitLab- of GitHub Enterprise-servers.

## Geschiedenis, blame en het web

- **Geschiedenis…** toont de commits met een banengrafiek, de refs die naar elk daarvan wijzen (`● main`,
  `↗ origin/main`, `⚑ v1.0`), en de bestanden die elke commit heeft geraakt. Return of een dubbelklik opent de
  versie van dat bestand tegenover zijn voorganger in het vergelijkvenster. **Commit terugdraaien** en
  **Cherry-pick** staan er, en beide weigeren vooraf als de werkmap niet schoon is.
- **Bestandsgeschiedenis…** is hetzelfde venster voor één bestand.
- **Blame (lijst)…** toont elke regel met commit, auteur en datum. **Blame in de editor** zet dezelfde
  informatie in de kantlijn van de editor, naast de regelnummers: wijs een regel aan voor het commitbericht,
  klik erop om die commit tegenover zijn voorganger te openen.
- **Openen op het web** opent het bestand, de commit of de branch op GitHub, GitLab, Bitbucket of Azure
  DevOps, opgebouwd uit de URL van de remote — geen account, geen token. Bij een host waarvan hij de vorm van
  de links niet kent, biedt hij de repositorypagina aan in plaats van te gokken.

## Branches, stashes en tags

**Branches, stashes & tags…** toont alle drie. Een branch wisselen, aanmaken, samenvoegen of verwijderen; een
stash pushen, poppen of weggooien; een tag aanmaken, verwijderen of pushen, of ernaartoe wisselen — een tag is
geen branch, dus wordt vooraf gezegd dat HEAD daarna losgekoppeld is. Fetch, Pull en Push staan in hetzelfde
venster en kunnen tijdens het lopen worden afgebroken.

Een tag pushen is met opzet een aparte actie: `git push` neemt tags niet mee.

## Conflicten

**Conflict oplossen…** toont de conflicterende gebieden van het bestand onder de cursor en neemt voor elk een
beslissing: *de onze*, *de hunne*, *beide*, of open laten. Daarna **Bestand schrijven** of **Schrijven en
stagen**. Hij weigert te stagen zolang een gebied open staat — Git commit `<<<<<<<`-markeringen zonder morren
— en hij raakt een bestand waarvan hij de markeringen niet kan lezen niet aan in plaats van ernaar te raden.
Voor een gebied waarin beide kanten met de hand verweven moeten worden, is **In editor openen** één knop ver.

## Rebasen

**Rebasen…** toont de commits die vóór de upstream liggen — die nog niemand anders heeft — en laat u ze
squashen, als fixup toevoegen, weggooien, herordenen of hernoemen voordat de branch wordt herschreven. Loopt
een rebase vast op een conflict, dan wordt hetzelfde venster **Doorgaan** / **Commit overslaan** / **Rebase
afbreken**, zodat een half afgemaakte rebase niet in een terminal hoeft te worden voltooid.

## Bestanden negeren, en inloggegevens

- **Dit bestand negeren…**, **Dit bestandstype negeren…** en **Deze map negeren…** zetten het juiste patroon
  in `.gitignore` — verankerd waar het hoort, zodat het negeren van *deze* map `build` niet elke map met de
  naam `build` negeert.
- **Inloggegevens…** meldt hoe deze repository zich authenticeert: SSH of HTTPS, of er een credential helper
  is ingesteld, of er een SSH-agent draait die een sleutel vasthoudt. Waar het helpt, biedt hij precies één
  actie aan — Git de inloggegevens in de macOS-sleutelhanger laten bewaren. De plug-in vraagt nooit om een
  wachtwoordzin, toont die niet en bewaart die niet.

## Opmerkingen

- De plug-in gebruikt de Git van het systeem op `/usr/bin/git`, of het programma dat in **Instellingen ▸ Git** is gekozen. Ontbreekt Git, dan melden de opdrachten dat Git niet beschikbaar is. (De Xcode Command Line Tools leveren het mee.)
- De status van een repository wordt één keer per map gelezen en bewaard, zodat het bladeren door een grote
  repository snel blijft; de cache ververst na elke opdracht die de boom verandert, en volgt ook een commit
  die buiten de app is gemaakt.
- Gekoppelde worktrees en submodules worden ondersteund: een bestand in een submodule toont de status en de
  branch *van de submodule*, niet die van de bovenliggende repository.
- Elke lijst heeft een contextmenu, **Return** voert de hoofdactie uit en **Cmd+R** laadt het venster opnieuw.
- Git LFS, `gpg` voor ondertekende commits en credential-helpers worden in de mappen van Homebrew en MacPorts gevonden, ook als de app vanuit de Finder is geopend.
