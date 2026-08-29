---
title: Macros
slug: macros
section: Outils avancés
order: 99
related: [automation, toolbar, start-menu, keyboard-shortcuts]
---

Une macro est une suite nommée d’actions sur les fichiers — créer un dossier, y déplacer la sélection, étiqueter ce qui reste — que vous pouvez relancer d’un clic. Ce n’est pas un langage de script : il n’y a ni conditions ni boucles, et c’est délibéré. Une macro est une liste que vous pouvez lire, et savoir la lire est ce qu’il faut avant de l’approuver.

Tout ce que fait une macro passe par les mêmes mécanismes que l’assistant : une macro ne peut donc rien faire que vous n’ayez autorisé, chacune de ses étapes figure dans le journal des actions, et une étape qui peut être annulée l’est toujours.

## Une seule fenêtre : Configuration ▸ Macros…

Tout ce qui concerne les macros est derrière cette entrée unique : leur liste, les deux façons d’en créer une, et l’accès au fichier. Il n’y a rien d’autre à choisir dans le menu.

## Le plus rapide : en enregistrer une

Vous n’avez pas à écrire une macro de zéro, et vous n’avez pas non plus à déterminer après coup où elle a commencé.

1. **Configuration ▸ Macros… ▸ Enregistrer une macro…**. La fenêtre s’efface et un petit panneau apparaît, indiquant qu’un enregistrement est en cours et comptant les étapes au fur et à mesure.
2. Faites le travail une fois — copier, déplacer, renommer, supprimer, créer des dossiers et des fichiers. Travaillez normalement ; l’enregistreur ne gêne pas.
3. **Arrêter et enregistrer…**.
4. Les étapes reviennent déjà cochées. Décochez tout ce qui ne servait qu’à préparer, donnez un nom à la macro et laissez **Ajouter aussi un bouton correspondant** activé.
5. Cochez **Suivre les panneaux plutôt que ces fichiers précis** si la macro doit travailler la prochaine fois sur ce qui sera sélectionné. Les lignes changent quand vous cochez, vous voyez donc ce que vous allez enregistrer.

**Enregistrer la macro**, et le bouton est dans la barre. C’est toute la boucle.

**Abandonner l’enregistrement** jette l’enregistrement et n’enregistre rien. Rien n’est capté avant que vous n’appuyiez sur Enregistrer, ni après l’arrêt — c’est tout l’intérêt d’avoir les deux extrémités.

Un enregistrement survit à un redémarrage. Si Peach Commander s’arrête pendant qu’il tourne — vous quittez, ou il plante — il revient avec, le dit, et vous continuez ou l’abandonnez.

Si vous préférez l’avoir sur une touche ou un bouton, la commande s’appelle `cm_MacroRecord` : elle démarre un enregistrement et arrête celui qui tourne.

## L’autre voie : à partir de ce qui s’est déjà passé

**Depuis les actions récentes…**, dans la même fenêtre, construit une macro à partir des dernières choses qui se sont passées au lieu d’en enregistrer de nouvelles — utile quand vous *venez* de faire le travail et n’y pensez qu’après.

![La feuille « Macro à partir des actions récentes », listant ce qui vient d’être fait comme étapes à cocher](screenshots/macro-recorder.png)
*Ce qui s’est déjà passé, proposé comme les étapes d’une nouvelle macro.*

La liste contient les deux : ce que vous avez fait dans les panneaux (F5, F6, F7, F8 et un renommage) et ce qu’a fait l’assistant ou une autre macro. Chaque ligne dit lequel des deux — car après une session mêlant les deux, les mêmes fichiers peuvent apparaître dans chacune. Ici les lignes commencent décochées : « tout ce que j’ai fait dans la dernière demi-heure » est rarement la macro que l’on veut.

> **Cette voie a besoin de l’historique.** Ce que vous faites à la main est relu depuis l’historique global ; si vous l’avez désactivé (Réglages ▸ Divers ▸ **Enregistrer un historique global**), cette liste ne contient rien de vous — et elle le dit. **Enregistrer une macro…** n’en dépend pas.

> **Ce qui n’est pas proposé.** Créer une archive, et tout ce que l’application ne retient que par son nom, ne peut pas devenir une étape — il n’y a pas de forme pour cela. Ces lignes apparaissent grisées avec leur raison plutôt que d’être omises, pour qu’une liste de cinq qui en propose trois ne donne pas l’impression d’en avoir manqué deux. Et sauf demande contraire, les chemins sont ceux qui ont réellement servi : une macro enregistrée répète *cette* copie-là, pas « une copie du même genre ». Ouvrez-la dans l’éditeur et mettez `%S` ou `%T` là où elle doit suivre les panneaux.

**Suivre les panneaux**, c’est ainsi que l’on demande le contraire. Des fichiers venus tous d’un même dossier deviennent la sélection ; un dossier qui est l’un des deux panneaux devient ce panneau, et un dossier situé à l’intérieur garde sa fin — un « déplacer ces quatre factures vers Documents/2026-08 » enregistré devient « déplacer ce qui est sélectionné vers *2026-08* de l’autre côté », et cela marche demain dans deux autres dossiers. Ce qui ne se trouve sous aucun des deux panneaux reste le chemin qu’il est : il n’y a rien où le replier. L’option n’est proposée que si elle change quelque chose.

## Les exemples fournis

La première fois que vous ouvrez **Modifier le fichier…**, le fichier est créé avec huit exemples complets. Ce sont des macros ordinaires — modifiez-les, ou supprimez celles dont vous ne voulez pas — et chacune porte un commentaire disant ce qu'elle fait et ce qu'on peut y changer :

| Macro | Ce qu'elle fait |
| --- | --- |
| **Open today's folder** | Crée le dossier du jour dans le panneau actif et y entre. À relancer demain. |
| **File the selection into a dated folder** | Sélectionne tous les PDF, crée un dossier année-mois en face et les y déplace. |
| **Copy the selection to a dated backup folder** | Copie ce que *vous* avez sélectionné dans un dossier daté, de l'autre côté. |
| **Move the pictures into an Images subfolder** | Un masque, un sous-dossier, dans le dossier où vous êtes déjà. |
| **Merge the CSV files into one and open it** | Montre comment une étape utilise ce qu'une étape précédente a produit. |
| **File the selection into a folder you name** | Vous demande le dossier au moment de s’exécuter. |
| **Mark the file under the cursor as reviewed** | L'étiquette et date son commentaire — un fichier, pas la sélection. |
| **Put the temporary files in the Trash** | Une macro qui supprime, et celle sur laquelle essayer la demande d'autorisation. |

Chacune devient une commande : vous pouvez donc en mettre n'importe laquelle sur un bouton ou une touche sans rien écrire.

## Les gérer

**Configuration ▸ Macros…** est la liste : le nom de chaque macro, le nom de sa commande, son nombre d’étapes et ce que la barrière d’autorisation demandera — « celle-ci supprime » est donc visible avant de la mettre sur une touche. De là vous pouvez exécuter, renommer, dupliquer, réordonner, supprimer, exporter et importer. Survoler une ligne montre ses étapes.

**Exécuter** est la façon d’essayer celle que vous venez d’enregistrer, sans d’abord fermer la fenêtre pour aller chercher la commande. Cela passe par le même plan et la même confirmation que toute autre exécution — cette fenêtre n’a aucun privilège propre.

**Exporter…** écrit la macro sélectionnée dans un fichier à elle, et **Importer…** ajoute des macros depuis des fichiers qu’on vous a envoyés — c’est à cela que sert un fichier par macro. Un import ne remplace jamais : une macro dont l’identifiant est déjà pris en reçoit un libre (un `backup` qui arrive à côté du vôtre devient `backup-2`), et on vous dit sous quels identifiants les nouvelles ont atterri, car le bouton que vous créerez doit nommer la bonne.

![La fenêtre « Gérer les macros », avec le nom de commande, le nombre d’étapes et l’autorisation de chacune](screenshots/macro-manager.png)
*Le nom de chaque macro, ce sous quoi elle s’exécute, et ce pour quoi elle demandera l’autorisation.*

L’ordre n’est pas décoratif : l’ordre du fichier est celui dans lequel le Navigateur de commandes et le sélecteur de la barre de boutons les listent.

**La suppression propose d’emporter les boutons**, et cela vaut d’être su même si vous n’ouvrez jamais cette fenêtre : une macro retirée à la main laisse derrière elle son bouton et sa touche, et l’un comme l’autre ne font alors rien — l’application dit désormais que la macro a disparu au lieu de se taire, mais le bouton reste à votre charge. Une touche ou une entrée de menu doit être retirée là où elle a été définie.

Les *étapes* ne se modifient pas ici. **Modifier le fichier…** passe la main à l’éditeur pour cela, pour la même raison qu’il n’y a pas de formulaire : une étape est un nom d’outil et ses arguments, ce qui est exactement du JSON.

## Modifier les macros à la main

**Modifier le fichier…** ouvre le fichier propre à la macro sélectionnée — `macros/<id>.json` dans votre dossier de configuration, créé la première fois avec les exemples ci-dessus. Sans sélection, c’est le dossier lui-même qui est montré dans le panneau, où F3 en lit une et F4 en modifie une. Une macro est une liste d’étapes, et chaque étape nomme un outil et ses arguments :

```json
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
```

L'enregistrement recharge les macros immédiatement — et vous prévient si quelque chose ne va pas : un nom d'outil mal orthographié, un argument obligatoire oublié, deux macros partageant un identifiant. Une macro comportant une erreur n'est pas exécutée et ne va sur aucun bouton ; on vous dit laquelle et ce qui ne va pas, pendant que l'éditeur est encore ouvert.

Pour savoir quels outils existent et ce qu'ils prennent, utilisez **Configuration ▸ Navigateur de commandes…**, ou demandez `list_macros` à l'assistant.

### Paramètres substituables

Les lettres seules sont celles que la barre de boutons et le menu Démarrer utilisent déjà : si vous avez fait un bouton, il n’y a rien de nouveau à apprendre.

| Paramètre | Signifie |
| --- | --- |
| `%P` | Le dossier du panneau actif |
| `%T` | Le dossier de l’autre panneau |
| `%N` | Le fichier sous le curseur |
| `%S` | Les fichiers sélectionnés — une **liste**, ce que prennent précisément `copy`, `move` et `move_to_trash` |
| `%{date:yyyy-MM}` | La date de démarrage de la macro, dans ce format |
| `%{1.destination}` | Une valeur nommée du résultat de l'étape 1 — ici le fichier que `merge_files` a écrit |
| `%{1}` | Tout le résultat de l'étape 1, lorsque cette étape a produit directement un chemin ou une liste de chemins |
| `%{ask:Folder name}` | Vous demande quand la macro s’exécute. `%{ask:Folder name=Archive}` pré-remplit le champ avec *Archive* |

Les accolades servent aux ajouts parce que les lettres sont déjà prises : `%M` signifie « le nom sous le curseur dans l’autre panneau » partout ailleurs dans le programme, un mois ne pouvait donc pas s’écrire ainsi.

Pour les résultats d'étape, utilisez la forme **nommée**. La plupart des outils rendent plusieurs valeurs plutôt qu'une seule — `merge_files` indique où il a écrit, combien de fichiers il a fusionnés et combien de lignes en sont sorties — d'où `%{2.destination}` comme écriture habituelle ; un `%{2}` nu ne fonctionne que pour un outil qui renvoie un seul chemin. Un nom absent, ou qui n'est pas un chemin, arrête la macro au lieu d'être deviné.

Un `%` dans un nom de fichier est un `%`. Rien de ce qu'une étape produit, et aucun nom venu d'un panneau, n'est relu comme un paramètre — un fichier nommé `50%Netto.pdf` traverse donc les macros sans changer. Pour un `%` littéral dans un modèle que *vous* écrivez, doublez-le : `%%`.

### Demander une valeur

`%{ask:…}` est la façon dont une macro reçoit ce qu’elle ne peut pas savoir d’avance — la macro la plus courante qui soit est « déplacer la sélection dans un dossier que je nomme », et sans cela le dossier devrait être figé dans le fichier.

On vous demande **avant** que le plan apparaisse, et les réponses y figurent déjà : les lignes disent « Déplacer la sélection vers “Factures” », et non « vers ce que vous allez taper ». Annuler la question annule la macro ; rien n’a été proposé, encore moins exécuté.

La même question écrite deux fois n’est posée qu’une fois et sert aux deux endroits, de sorte que deux étapes nommant le même dossier ne peuvent pas diverger. Ce qui suit le premier `=` est ce que contient le champ au départ. La formulation est la vôtre : elle est affichée telle que vous l’avez écrite, dans la langue où vous l’avez écrite.

Une réponse est une valeur, jamais un modèle : taper `50%Netto` donne un dossier nommé `50%Netto`.

Une macro qui pose une question ne peut pas être exécutée par un agent externe via MCP — il n’y a personne à qui demander, et prendre les valeurs par défaut en silence reviendrait à répondre à votre place. Elle est refusée, et le dit.


`%S` est le seul point où une macro diffère d’un bouton : sur un bouton la sélection devient une liste de mots pour une ligne de commande, ici elle devient la liste des chemins complets que prennent les outils de fichiers.

Une étape dont le `%S` ou le `%{1}` ressort **vide arrête la macro** au lieu de s’exécuter sans rien. Un `move` sans fichiers n’est pas un `move` plus petit — c’est une demande qui ne dit plus rien, et signaler une réussite serait un mensonge.

## Exécuter une macro

Chaque macro devient une commande nommée `mc_<id>`, et apparaît donc d’elle-même dans :

- **Configuration ▸ Explorateur de commandes…**
- **Configuration ▸ Modifier les raccourcis… — placez-la sur une touche**
- Le sélecteur de commandes de l’éditeur de la barre de boutons
- Votre fichier de menu `.mnu` et `usercmd.ini`, si vous les utilisez
- L’assistant, qui peut l’exécuter par son nom

Avant qu’une macro qui modifie quelque chose ne s’exécute, elle vous montre ses étapes sous forme de liste et attend. Vous pouvez rayer une étape dont vous ne voulez pas ; ce qui reste est ce qui s’exécute. Une macro qui ne fait que lire s’exécute sans demander. **Rayer une étape emporte celles qui en dépendent** — une macro est une séquence, et l’étape qui remplit le dossier ne peut pas s’exécuter sans celle qui le crée : ces lignes se décochent d’elles-mêmes et se grisent. Remettez l’étape et elles reviennent — sauf celles que vous aviez rayées vous-même, qui restent rayées.

![Le dialogue de confirmation d’une macro, chaque étape une case à cocher nommant les fichiers concernés](screenshots/macro-confirm.png)
*Les étapes, résolues sur vos panneaux — chacune peut être rayée.*

Tout ce qui peut être reconnu comme faux avant le départ — un outil qui n'existe pas, un argument manquant, une étape qui exécuterait une autre macro — arrête la macro avant la première étape, et non après la troisième. Si une étape échoue en cours de route, la macro **s'arrête là** au lieu de continuer : l'étape deux suppose généralement que l'étape un a eu lieu, et déplacer des fichiers dans un dossier qui n'a pas été créé n'est pas un succès partiel. Le compte rendu nomme l'étape, dit ce qui s'est passé et combien d'étapes avaient déjà été exécutées ; chacune figure dans le journal des actions, avec son retour en arrière lorsqu'il existe.
## Ce qu’une macro est autorisée à faire

Une macro est jugée à ce qu’elle contient de plus exigeant. Une macro dont les étapes ne font que lire est traitée comme une lecture ; une qui se termine par une suppression définitive est encadrée comme une suppression définitive — avant que quoi que ce soit ne s’exécute, pas quatre étapes plus tard.

Une étape qui exécute une *commande* est jugée sur ce que fait cette commande, et non sur le fait que c'est une commande — une macro qui exécute `cm_DeleteReal` est donc une macro qui supprime, et vous est présentée comme telle. Une macro ne peut pas en exécuter une autre, quelle que soit l'écriture.

Ne rien accorder de plus est la règle par défaut. Si une macro contient une étape que vos autorisations n’admettent pas — une commande shell, un script — la macro entière est refusée avec sa raison, et rien ne se produit.

## Annuler

Chaque étape est journalisée séparément : **annuler** après une macro reprend donc sa *dernière* étape, et non la macro entière. Il n’y a pas d’annulation de macro complète, car plusieurs outils n’ont aucun inverse et un bouton qui la proposerait mentirait à leur sujet.

## Où tout est enregistré

- Vos macros sont dans `macros/` du dossier de configuration, une par `<id>.json` — des fichiers simples, que vous pouvez comparer, garder avec vos dotfiles et envoyer à quelqu’un. Un `macros.json` d’une version antérieure est repris au premier lancement et renommé `macros.json.migrated` ; plus rien ne le lit ensuite.
- Les boutons ajoutés par une macro sont des entrées ordinaires de la barre de boutons dans `default.bar` : en supprimer un revient à supprimer n’importe quel bouton.

## Pour aller plus loin

- [Automatisation (AppleScript et Raccourcis)](automation.md) — Piloter Peach Commander depuis un script, et exécuter vos propres scripts comme étape de macro.
- [La barre de boutons](toolbar.md) — Où aboutit le bouton ajouté par une macro.
- [Clavier et raccourcis](keyboard-shortcuts.md) — Placer une macro sur une touche.
