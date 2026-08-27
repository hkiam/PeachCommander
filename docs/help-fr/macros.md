---
title: Macros
slug: macros
section: Outils avancés
order: 99
related: [automation, toolbar, start-menu, keyboard-shortcuts]
---

Une macro est une suite nommée d’actions sur les fichiers — créer un dossier, y déplacer la sélection, étiqueter ce qui reste — que vous pouvez relancer d’un clic. Ce n’est pas un langage de script : il n’y a ni conditions ni boucles, et c’est délibéré. Une macro est une liste que vous pouvez lire, et savoir la lire est ce qu’il faut avant de l’approuver.

Tout ce que fait une macro passe par les mêmes mécanismes que l’assistant : une macro ne peut donc rien faire que vous n’ayez autorisé, chacune de ses étapes figure dans le journal des actions, et une étape qui peut être annulée l’est toujours.

## Le plus rapide : à partir de ce que vous venez de faire

Vous n’avez pas à écrire une macro de zéro.

1. Faites la chose une fois — via l’assistant, ou en exécutant une macro existante.
2. Choisissez **Configuration ▸ Macro depuis les actions récentes…**.
3. Cochez les étapes que la macro doit répéter, donnez-lui un nom et laissez **Ajouter aussi un bouton correspondant** activé.

**Enregistrer la macro**, et le bouton est dans la barre. C’est toute la boucle.

> **Ce qui n’est pas enregistré.** La liste est construite à partir des actions passées par l’assistant ou par une autre macro. Copier, déplacer ou renommer *à la main* dans les panneaux — F5, F6, F7 — n’est pas enregistré et ne peut donc pas devenir une macro par ce chemin. Utilisez l’éditeur ci-dessous pour cela.

## Modifier les macros à la main

**Configuration ▸ Modifier les macros…** ouvre `macros.json` dans votre dossier de configuration, en y plaçant un exemple commenté la première fois. Une macro est une liste d’étapes, et chaque étape nomme un outil et ses arguments :

```json
[
  {
    "id": "stage-by-month",
    "title": "File the selection into a dated folder",
    "icon": "calendar",
    "steps": [
      { "tool": "set_selection", "arguments": { "mask": "*.pdf" } },
      { "tool": "make_directory", "arguments": { "path": "%T/%{date:yyyy-MM}" } },
      { "tool": "move", "arguments": { "sources": "%S", "destination": "%T/%{date:yyyy-MM}" } }
    ]
  }
]
```

L’enregistrement recharge les macros immédiatement. Pour savoir quels outils existent et ce qu’ils prennent, demandez `list_macros` à l’assistant, ou lisez l’exemple placé dans le fichier.

### Paramètres substituables

Les lettres seules sont celles que la barre de boutons et le menu Démarrer utilisent déjà : si vous avez fait un bouton, il n’y a rien de nouveau à apprendre.

| Paramètre | Signifie |
| --- | --- |
| `%P` | Le dossier du panneau actif |
| `%T` | Le dossier de l’autre panneau |
| `%N` | Le fichier sous le curseur |
| `%S` | Les fichiers sélectionnés — une **liste**, ce que prennent précisément `copy`, `move` et `move_to_trash` |
| `%{date:yyyy-MM}` | La date de démarrage de la macro, dans ce format |
| `%{1}` | Le résultat de l’étape 1, lorsque celle-ci a produit un chemin ou une liste de chemins |

Les accolades servent aux ajouts parce que les lettres sont déjà prises : `%M` signifie « le nom sous le curseur dans l’autre panneau » partout ailleurs dans le programme, un mois ne pouvait donc pas s’écrire ainsi.

`%S` est le seul point où une macro diffère d’un bouton : sur un bouton la sélection devient une liste de mots pour une ligne de commande, ici elle devient la liste des chemins complets que prennent les outils de fichiers.

Une étape dont le `%S` ou le `%{1}` ressort **vide arrête la macro** au lieu de s’exécuter sans rien. Un `move` sans fichiers n’est pas un `move` plus petit — c’est une demande qui ne dit plus rien, et signaler une réussite serait un mensonge.

## Exécuter une macro

Chaque macro devient une commande nommée `mc_<id>`, et apparaît donc d’elle-même dans :

- **Configuration ▸ Explorateur de commandes…**
- **Configuration ▸ Modifier les raccourcis… — placez-la sur une touche**
- Le sélecteur de commandes de l’éditeur de la barre de boutons
- Votre fichier de menu `.mnu` et `usercmd.ini`, si vous les utilisez
- L’assistant, qui peut l’exécuter par son nom

Avant qu’une macro qui modifie quelque chose ne s’exécute, elle vous montre ses étapes sous forme de liste et attend. Vous pouvez rayer une étape dont vous ne voulez pas ; ce qui reste est ce qui s’exécute. Une macro qui ne fait que lire s’exécute sans demander.

Si une étape échoue, la macro **s’arrête là** au lieu de continuer — l’étape deux suppose en général que l’étape un a eu lieu, et déplacer des fichiers dans un dossier qui n’a pas été créé n’est pas une réussite partielle. Le rapport nomme l’étape et dit ce qui n’a pas marché ; les étapes qui se sont exécutées sont dans le journal des actions.

## Ce qu’une macro est autorisée à faire

Une macro est jugée à ce qu’elle contient de plus exigeant. Une macro dont les étapes ne font que lire est traitée comme une lecture ; une qui se termine par une suppression définitive est encadrée comme une suppression définitive — avant que quoi que ce soit ne s’exécute, pas quatre étapes plus tard.

Ne rien accorder de plus est la règle par défaut. Si une macro contient une étape que vos autorisations n’admettent pas — une commande shell, un script — la macro entière est refusée avec sa raison, et rien ne se produit.

## Annuler

Chaque étape est journalisée séparément : **annuler** après une macro reprend donc sa *dernière* étape, et non la macro entière. Il n’y a pas d’annulation de macro complète, car plusieurs outils n’ont aucun inverse et un bouton qui la proposerait mentirait à leur sujet.

## Où tout est enregistré

- Vos macros sont dans `macros.json` du dossier de configuration — un fichier simple, que vous pouvez comparer et garder avec vos dotfiles.
- Les boutons ajoutés par une macro sont des entrées ordinaires de la barre de boutons dans `default.bar` : en supprimer un revient à supprimer n’importe quel bouton.

## Pour aller plus loin

- [Automatisation (AppleScript et Raccourcis)](automation.md) — Piloter Peach Commander depuis un script, et exécuter vos propres scripts comme étape de macro.
- [La barre de boutons](toolbar.md) — Où aboutit le bouton ajouté par une macro.
- [Clavier et raccourcis](keyboard-shortcuts.md) — Placer une macro sur une touche.
