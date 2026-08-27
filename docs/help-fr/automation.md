---
title: Automatisation (AppleScript et Raccourcis)
slug: automation
section: Outils avancés
order: 98
related: [start-menu, settings, macros]
---

L’automatisation fonctionne ici dans les deux sens.

**Vers l’extérieur :** Peach Commander est scriptable : vous pouvez le piloter depuis AppleScript et depuis l’app Raccourcis. Quelques verbes de base permettent à un script de naviguer dans les panneaux, de sélectionner des fichiers par masque, de copier ou déplacer la sélection courante et d’exécuter n’importe quelle commande de Peach Commander par son id — en réutilisant exactement les actions des menus, si bien qu’une étape scriptée se comporte comme une étape manuelle. C’est l’objet du reste de cette page.

**Vers l’intérieur :** Peach Commander peut aussi *exécuter* un script à vous — AppleScript ou JavaScript — et le placer sur un menu, un bouton ou une touche. Cela nécessite le module **Scripting**, livré désactivé ; voir [Exécuter vos propres scripts](#executer-vos-propres-scripts) plus bas.

Pour répéter une *suite* d’actions sur les fichiers plutôt qu’une seule, voir [Macros](macros.md).

## Voir le dictionnaire

1. Ouvrez **Éditeur de script** (dans `/Applications/Utilities` — « Utilitaires » dans le Finder).
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

## Exécuter vos propres scripts

L’autre sens : un script à vous, exécuté par Peach Commander.

C’est un module, et il est livré **désactivé**, parce qu’exécuter un programme de votre choix peut faire tout ce que fait le reste de l’application, et plusieurs choses qu’elle ne couvre pas. Deux interrupteurs, tous deux éteints jusqu’à ce que vous les activiez :

1. **Configuration ▸ Modules…** — activez **Scripting**.
2. **Réglages ▸ IA** — activez **Autoriser l’exécution de scripts**. C’est sur cette page parce qu’il s’agit du même genre d’autorisation que le shell de l’assistant, et que les deux vont ensemble.

Placez ensuite un script dans `scripts/` à l’intérieur de votre dossier de configuration — **Commandes ▸ Ouvrir le dossier des scripts** vous y conduit et y laisse un exemple la première fois. Un fichier `.applescript`, `.scpt` ou `.jxa` dans ce dossier *est* un script ; il n’y a rien à déclarer.

### Ce qu’un script reçoit

L’état des panneaux arrive dans l’environnement, si bien que le cas ordinaire ne demande aucun Apple event et aucune demande d’autorisation :

| Variable | Signifie |
| --- | --- |
| `PC_ACTIVE_DIR` | Le dossier du panneau actif |
| `PC_TARGET_DIR` | Le dossier de l’autre panneau |
| `PC_CURSOR_NAME` | Le fichier sous le curseur |
| `PC_SELECTION_COUNT` | Combien d’éléments sont sélectionnés |
| `PC_SELECTION_FILE` | Un fichier texte avec un chemin sélectionné par ligne (absent si rien n’est sélectionné) |

```applescript
set here to system attribute "PC_ACTIVE_DIR"
return "The active panel is showing " & here
```

Tout ce qui dépasse cela passe par l’application elle-même, avec les verbes ci-dessus — les deux moitiés se complètent donc.

### Mettre un script sur un bouton ou une touche

Chaque script devient une commande nommée `plugin.script.run.<nom>`, où `<nom>` est le nom du fichier sans son extension (les espaces et les points deviennent des tirets). Cet id fonctionne partout où fonctionne un id `cm_*` : dans la barre de boutons, dans `usercmd.ini`, dans un fichier `.mnu` et dans **Configuration ▸ Modifier les raccourcis…**.

### Comment un script s’exécute, et le délai

Par défaut un script s’exécute comme un processus séparé, ce qui permet de lui donner une limite de temps et de l’arrêter s’il la dépasse — trente secondes sauf indication contraire. Un script peut choisir de s’exécuter *à l’intérieur* de l’application, ce qui lui permet de renvoyer une valeur structurée et le laisse compilé entre les exécutions, mais il n’y a alors plus de limite de temps : un script qui boucle bloque l’application. Indiquez le choix dans `scripts.json`, à côté de vos scripts :

```json
[
  { "id": "Tidy", "fileName": "Tidy.applescript", "title": "Tidy Downloads",
    "language": "AppleScript", "mode": "subprocess", "timeoutSeconds": 60 }
]
```

Seul ce qui diffère des valeurs par défaut nécessite une entrée ; un fichier sans entrée prend son propre nom comme titre, s’exécute comme processus séparé et s’arrête au bout de trente secondes.

### Pour l’assistant

Avec le module activé et le réglage en place, l’assistant gagne `run_applescript`, `run_jxa` et `check_script`. Chacun vous montre le script exact et attend votre approbation avant que quoi que ce soit ne s’exécute, et aucun n’est jamais proposé à un agent externe via MCP.

## Remarques

- L'id de commande que vous passez à `run command` est le même id `cm_*` affiché dans le navigateur de commandes (voir [Le menu Démarrer et les commandes personnalisées](start-menu.md)).
- Le script agit toujours sur le panneau **actif** ; utilisez d'abord `go to … in left` / `in right` si vous avez besoin d'un côté précis.
- Peach Commander est une application à fenêtre unique, les scripts ciblent donc les deux panneaux de cette fenêtre.
