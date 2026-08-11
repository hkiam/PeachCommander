---
title: La visionneuse de journaux
slug: log-viewer
section: Plugins
order: 128
related: [plugins, viewing-files, searching]
---

Placez le curseur sur un fichier journal et choisissez **Afficher comme journal…** pour l’ouvrir dans une fenêtre conçue pour les journaux plutôt que pour du texte : une ligne par ligne, le niveau de chacune reconnu et coloré, un filtre, et un suivi qui tient le rythme pendant que le fichier s’écrit encore.

C’est une extension : vous pouvez la désactiver ou la supprimer dans **Configuration ▸ Extensions…**. Sans elle, F3 affiche un journal comme n’importe quel autre fichier texte.

## Pourquoi elle s’ouvre instantanément

Le fichier est mappé en mémoire et seul un index du début de chaque ligne est construit, en arrière-plan. Rien n’est chargé sous forme de texte avant d’être à l’écran, et seules les lignes réellement visibles sont décodées. Un journal de plusieurs gigaoctets s’ouvre aussi vite qu’un petit, et aller à la fin ne lit pas le milieu.

## Niveaux et couleur

Chaque ligne est classée — **Erreur**, **Avertissement**, **Info**, **Débogage**, **Trace**, ou **Inconnu** quand le format ne dit rien — et colorée en conséquence. Les couleurs par défaut suivent l’apparence claire ou sombre ; définissez les vôtres dans les réglages de l’extension et ce sont elles qui servent.

La colonne **Niveau** montre d’un coup d’œil où sont les erreurs, et le champ de filtre restreint la liste à ce que vous cherchez. Activez **Regex** pour filtrer avec une expression régulière plutôt qu’avec du texte brut.

## Suivre un fichier qui grossit encore

Activez **En direct (défilement auto)** et la fenêtre suit la fin du fichier à mesure que les lignes arrivent : l’index est étendu sur les octets ajoutés plutôt que reconstruit, ce qui reste peu coûteux quelle que soit la longueur du fichier. Remontez et vous lisez l’historique ; le suivi continue en dessous.

## S’y retrouver

| | |
| --- | --- |
| **Rechercher…** | Cherche dans les messages ; **Rechercher (marquer et aller)…** marque chaque occurrence pour passer de l’une à l’autre |
| **Aller à la ligne…** | Saute à un numéro de ligne physique |
| **Aller à la date/heure…** | Saute à la première ligne à partir d’un horodatage, p. ex. `2024-01-15 10:23:45` |

La copie sait ce qu’est une ligne de journal : **Copier la ligne** prend la ligne sous le curseur, **Copier l’entrée (toutes les lignes)** prend l’entrée entière lorsqu’elle s’étend sur plusieurs lignes — une trace d’appels, par exemple — et **Copier les lignes sélectionnées** prend exactement ce que vous avez sélectionné.

## Formats

**log4j**, **log4net** et **CSV** sont intégrés, et le format est détecté automatiquement ; la fenêtre indique celui qu’elle a retenu. Si vos journaux ne sont aucun de ceux-là, ajoutez le vôtre sous **Formats de journal** dans les réglages : une expression régulière avec des groupes nommés pour les parties qui comptent.

```
(?<time>…)   (?<level>…)   (?<msg>…)
```

Une ligne que l’expression ne reconnaît pas apparaît quand même — elle est simplement classée Inconnu plutôt qu’écartée, car un journal qu’on ne peut pas lire est pire qu’un journal sans couleurs.

## Affichage

**Afficher les numéros de ligne** et **Renvoyer à la ligne** sont dans les réglages. La zone de détail sous la liste montre toujours le texte complet de l’entrée sélectionnée, avec retour à la ligne, quoi que fasse la liste.
