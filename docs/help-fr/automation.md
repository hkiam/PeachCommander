---
title: Automatisation (AppleScript et Raccourcis)
slug: automation
section: Outils avancés
order: 98
related: [start-menu, settings]
---

Peach Commander est scriptable, vous pouvez donc le piloter depuis AppleScript et depuis l'app Raccourcis. Une poignée de verbes fondamentaux permet à un script de naviguer dans les panneaux, de sélectionner des fichiers par un masque, de copier ou déplacer la sélection courante et d'exécuter n'importe quelle commande de Peach Commander par son id — en réutilisant exactement les mêmes actions que les menus, de sorte qu'une étape scriptée se comporte comme une étape manuelle. C'est pratique pour les corvées répétitives : classer les téléchargements, préparer la sortie d'une compilation ou insérer une étape de fichier dans un Raccourci plus vaste.

## Voir le dictionnaire

1. Ouvrez **Éditeur de script** (dans `/Applications/Utilitaires`).
2. Choisissez **Fenêtre ▸ Bibliothèque**, puis double-cliquez sur **Peach Commander** (ajoutez-le avec **+** s'il n'est pas listé).
3. Le dictionnaire s'ouvre, listant les commandes et propriétés ci-dessous.

La première fois qu'un script contrôle Peach Commander, macOS vous demande de l'autoriser (**Réglages Système ▸ Confidentialité et sécurité ▸ Automatisation**). Approuvez-le une fois et les scripts ultérieurs s'exécutent sans demande.

## Ce que vous pouvez lire

| Propriété | Signification |
| --- | --- |
| `active folder` | Chemin POSIX du dossier du panneau actif. |
| `inactive folder` | Chemin POSIX du dossier de l'autre panneau. |
| `selection paths` | Les éléments sélectionnés dans le panneau actif (ou l'élément sous le curseur). |

## Les verbes

| Commande | Ce qu'elle fait |
| --- | --- |
| `go to "<chemin>" [in left\|right]` | Ouvrir un dossier dans un panneau (par défaut : le panneau actif). |
| `select "<masque>"` | Sélectionner des éléments dans le panneau actif par un masque à jokers, p. ex. `*.pdf`. |
| `copy items to "<dossier>"` | Copier la sélection du panneau actif vers un dossier. |
| `move items to "<dossier>"` | Déplacer la sélection du panneau actif vers un dossier. |
| `run command "<id>"` | Exécuter n'importe quelle commande par son id, p. ex. `cm_PackFiles`. |

La copie et le déplacement utilisent la même file de transfert en arrière-plan que F5/F6, de sorte que la progression et les invites d'écrasement éventuelles apparaissent exactement comme pour une opération manuelle.

## Exemple

```applescript
tell application "Peach Commander"
    go to "~/Downloads" in left
    select "*.pdf"
    copy items to "~/Documents/PDFs"
    return selection paths
end tell
```

## L'utiliser depuis Raccourcis

Dans l'app **Raccourcis**, ajoutez l'action **Exécuter AppleScript** et collez un script comme celui ci-dessus. Cela vous permet d'insérer une étape de Peach Commander dans un Raccourci plus vaste — par exemple, déclenché par un changement de dossier ou une touche de raccourci.

## Remarques

- L'id de commande que vous passez à `run command` est le même id `cm_*` affiché dans le navigateur de commandes (voir [Le menu Démarrer et les commandes personnalisées](start-menu.md)).
- Le script agit toujours sur le panneau **actif** ; utilisez d'abord `go to … in left` / `in right` si vous avez besoin d'un côté précis.
- Peach Commander est une application à fenêtre unique, les scripts ciblent donc les deux panneaux de cette fenêtre.
