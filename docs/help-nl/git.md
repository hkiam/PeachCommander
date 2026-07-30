---
title: Git
slug: git
section: Plug-ins
order: 123
related: [plugins, view-modes-and-sorting]
---

De Git-plug-in toont de status van een Git-repository rechtstreeks in het bestandspaneel — geen aparte app, geen terminal. Hij voegt twee kolommen toe die per bestand de status in de werkboom en de huidige branch tonen, een **Git**-submenu voor de alledaagse opdrachten (status, stagen, committen, pullen, pushen), en gebruikt de `git` die al op je Mac is geïnstalleerd. Het is een plug-in, dus je kunt hem uitschakelen of verwijderen via **Configuratie ▸ Plug-ins…**.

## Wat het toevoegt

- **Twee kolommen in de bestandslijst** — *Git Status* en *Branch*. In een repository toont elk bestand een kort statuswoord (Gewijzigd, Toegevoegd, Verwijderd, Niet gevolgd, Hernoemd, Gekopieerd, Conflict, Genegeerd of Veranderd) en toont het paneel de huidige branch. Zet de kolommen aan via **Configuratie ▸ Kolommen…** (zie [Weergavemodi & sorteren](view-modes-and-sorting.md)).
- **Een Git-menu** — onder **Opdrachten ▸ Git** en in het rechtsklikmenu van een bestand, met: **Git Status…**, **Git Add (stage)**, **Git Commit…**, **Git Pull** en **Git Push**.

![Het dialoogvenster Git Status met de huidige branch en de gewijzigde bestanden in de repository](screenshots/git-status.png)
*(Afbeelding: Git Status meldt de branch en elke wijziging in de werkboom.)*

## De status controleren

1. Zet de cursor op een bestand of map binnen een Git-repository.
2. Kies **Opdrachten ▸ Git ▸ Git Status…** (of rechtsklik ▸ **Git ▸ Git Status…**).
3. Er verschijnt een samenvatting: de huidige branch (of *(losgekoppeld)*), gevolgd door ofwel *Werkboom schoon.* ofwel een lijst met wijzigingen, waarbij elke regel de status en het bestandspad toont.

Als de cursor niet in een repository staat, meldt de plug-in simpelweg *Geen Git-repository.*

## Stagen, committen, pullen, pushen

- **Git Add (stage)** zet het bestand onder de cursor klaar (`git add`).
- **Git Commit…** vraagt om een commitbericht en legt vervolgens alle wijzigingen vast (`git commit -a`). De gecombineerde uitvoer wordt getoond, zodat je precies ziet wat er is gebeurd.
- **Git Pull** doet een pull met alleen fast-forward (`git pull --ff-only`).
- **Git Push** pusht de huidige branch (`git push`).

Na een opdracht die de repository wijzigt, wordt het actieve paneel vernieuwd zodat de statuskolommen actueel blijven.

## Opmerkingen

- De plug-in gebruikt de systeem-Git op `/usr/bin/git`. Als Git niet is geïnstalleerd, melden de opdrachten dat Git niet beschikbaar is. (Installatie van de Xcode Command Line Tools levert het.)
- De repositorystatus wordt één keer per map gelezen en in de cache bewaard, zodat het scrollen door een grote repo snel blijft; de cache wordt vernieuwd na elke opdracht die de boom wijzigt.
- Commit gebruikt `git commit -a`, wat gevolgde wijzigingen vastlegt; gloednieuwe bestanden moeten eerst nog via **Git Add (stage)**.
- De kolomkoppen *Git Status* en *Branch* worden momenteel in het Engels weergegeven, ook in andere interfacetalen; de waarden en dialoogvensters zijn gelokaliseerd.
