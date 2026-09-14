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
druk op **Commit** — met **Amend** om de wijziging in de vorige commit te vouwen. **Pull** en **Push** staan
ernaast, waar de commit toch al plaatsvindt; beide tonen voortgang en kunnen worden afgebroken.

Er wordt de *index* gecommit, niet `git commit -a`: wat u hebt gestaged, is wat er wordt gecommit.

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

- De plug-in gebruikt de Git van het systeem op `/usr/bin/git`. Ontbreekt Git, dan melden de opdrachten dat
  Git niet beschikbaar is. (De Xcode Command Line Tools leveren hem mee.)
- De status van een repository wordt één keer per map gelezen en bewaard, zodat het bladeren door een grote
  repository snel blijft; de cache ververst na elke opdracht die de boom verandert, en volgt ook een commit
  die buiten de app is gemaakt.
- Gekoppelde worktrees en submodules worden ondersteund: een bestand in een submodule toont de status en de
  branch *van de submodule*, niet die van de bovenliggende repository.
- Elke lijst heeft een contextmenu, **Return** voert de hoofdactie uit en **Cmd+R** laadt het venster opnieuw.
