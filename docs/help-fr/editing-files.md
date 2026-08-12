---
title: Modifier des fichiers
slug: editing-files
section: Affichage et édition
order: 72
related: [viewing-files]
---

Quand vous avez besoin de modifier un fichier plutôt que de simplement le consulter, Peach Commander l'ouvre dans un éditeur intégré. Les fichiers texte et code s'ouvrent dans un éditeur complet avec coloration syntaxique, recherche et remplacement, un plan des symboles de votre code et une minicarte pour une navigation rapide. Les fichiers binaires peuvent s'ouvrir dans un éditeur hexadécimal distinct, où vous pouvez inspecter et modifier des octets individuels. Vous n'avez jamais à quitter l'application pour une modification rapide.

## Modifier un fichier texte ou code

1. Dans l'un ou l'autre panneau, placez le curseur sur le fichier à modifier.
2. Appuyez sur F4, ou choisissez Fichier ▸ Modifier. Le fichier s'ouvre dans la fenêtre de l'éditeur.
3. Effectuez vos modifications. Si le fichier est un format de programmation ou de données reconnu, les mots-clés, chaînes et commentaires sont colorés automatiquement.
4. Appuyez sur Cmd+S (ou cliquez sur Enregistrer) pour écrire vos modifications. L'enregistrement remplace le fichier ; si vous voulez conserver le contenu précédent à côté de lui, activez les sauvegardes dans Réglages ▸ Modifier/Afficher.

Pour créer un tout nouveau fichier texte à l'emplacement courant, appuyez sur Maj+F4.

![L'éditeur de texte intégré montrant la coloration syntaxique, le plan des symboles et la minicarte](screenshots/editor.png)
*(Figure : l'éditeur avec la coloration syntaxique, le plan des symboles à gauche et la minicarte à droite.)*

Si le fichier appartient à `root` — une entrée dans `/etc`, un plist launchd, la configuration d’un serveur web —, l’enregistrement propose de le faire **en tant qu’administrateur** : macOS demande une autorisation comme d’habitude, le contenu passe par un fichier temporaire privé plutôt que par une ligne de commande, et le fichier conserve son propriétaire et ses permissions au lieu de devenir discrètement le vôtre.

Si le fichier ne peut pas être écrit, vous l’apprenez à l’ouverture et non au moment d’enregistrer : le titre porte un cadenas et la barre d’état nomme l’obstacle — appartenant à un autre utilisateur, des permissions qui interdisent l’écriture, un fichier verrouillé, un volume en lecture seule ou une protection par le système. Seul le premier cas se règle en autorisant l’enregistrement, et c’est le seul où il est proposé ; pour les autres, la demande coûterait un mot de passe et échouerait quand même.

La gouttière affiche les numéros de ligne, celle du curseur plus claire que les autres ; le bouton à côté du menu d’encodage la masque. Une ligne repliée est numérotée une fois : le numéro désigne toujours la même ligne qu’une erreur de compilation ou une remarque de relecture.

## Rechercher, remplacer et naviguer

- Appuyez sur Cmd+F pour ouvrir la barre de recherche. Pour remplacer du texte, ouvrez la barre de recherche et basculez-la vers la vue de remplacement, ou cliquez sur Rechercher/Remplacer dans la barre d'outils.
- Cliquez sur Formater JSON/XML pour réindenter un document JSON ou XML en une mise en page propre et lisible.
- Cliquez sur Symboles (ou appuyez sur Cmd+Maj+O) pour afficher une barre latérale listant les classes, fonctions et méthodes de votre code — ou, pour un fichier JSON, YAML ou XML, ses clés et ses éléments. Cliquez sur une entrée pour y sauter directement. Voir [Travailler avec JSON, YAML et XML](#travailler-avec-json-yaml-et-xml) pour ce que cette structure permet d'autre.
- Appuyez sur Cmd+L pour sauter à une ligne précise.
- Appuyez sur Cmd+\ pour sauter entre une parenthèse et son homologue correspondant.
- Cliquez sur le bouton carte pour afficher ou masquer la minicarte, un aperçu à l'échelle de tout le fichier sur lequel vous pouvez cliquer pour faire défiler.
- Utilisez le menu Encodage de la barre d'outils si le fichier a été enregistré avec un encodage autre que celui par défaut.

## Travailler avec JSON, YAML et XML

Ces trois formats bénéficient d'un traitement à part, car un fichier de configuration se parcourt par sa structure et non par ses numéros de ligne.

La barre latérale **Symboles** liste les clés d'un fichier JSON ou YAML et les éléments d'un fichier XML, imbriqués comme l'est le document. Un élément est nommé d'après son attribut `id`, `name` ou `key` lorsqu'il en a un, de sorte que vingt entrées `<server>` se distinguent. Une liste affiche ses entrées sous la forme `[0]`, `[1]`, et lorsqu'une entrée commence par une clé, celle-ci est indiquée aussi — `[0] name`. Le champ de filtre au-dessus de la liste retrouve une clé par son nom dans un fichier de n'importe quelle taille, et la barre d'état affiche toujours le chemin de ce qui contient le curseur.

Un fichier cassé reçoit tout de même un plan jusqu'à l'endroit où il casse — le moment où l'on en a le plus besoin.

Le menu **Structure** — dans la barre des menus tant que l'éditeur est au premier plan — vous déplace dans cette structure :

- **Aller au nœud englobant** (Ctrl+Cmd+Haut) sort vers le bloc qui contient le curseur : de `image:` au service auquel il appartient.
- **Aller au premier enfant** (Ctrl+Cmd+Bas) entre.
- **Aller au frère précédent / suivant** (Ctrl+Cmd+Gauche / Droite) passe d'une entrée à l'autre au même niveau en enjambant tout le bloc intermédiaire — d'un serveur au suivant sans défiler devant quarante lignes de réglages.
- **Sélectionner le nœud englobant** (Ctrl+Cmd+A) sélectionne le bloc où se trouve le curseur. Appuyez à nouveau et la sélection s'étend au bloc qui l'entoure, ce qui permet de sélectionner exactement un service, ou exactement un élément, sans faire glisser la souris.
- **Copier le chemin structurel** (Ctrl+Cmd+C) copie la position du curseur sous la forme d'une expression que les outils du format acceptent : `.services.web.ports[0]` pour JSON et YAML, ce qu'attendent `jq` et `yq`, et `//server[@id='web-1']/port` pour XML, c'est-à-dire un XPath. Les clés qui ne sont pas de simples mots sont mises entre guillemets pour vous — `."content-type"` et non `.content-type`, qui en `jq` signifie tout autre chose.
- **Valider le document** (Ctrl+Cmd+V) vérifie le fichier et place le curseur **sur le problème**, la raison apparaissant dans le titre de la fenêtre. Il signale ce qu'aucun autre outil de la chaîne ne signalera : une clé en double, que tout analyseur JSON accepte en silence en écartant l'une des deux valeurs, et une virgule finale, que l'analyseur d'Apple accepte alors que Python, Go et `jq` la refusent.

Les fichiers longs se lisent en repliant ce sur quoi on ne travaille pas. **Replier le nœud** (Option+Cmd+Gauche) replie le bloc où se trouve le curseur — le plus proche qui ait un corps, de sorte qu'un appui sur une ligne unique replie la table qui l'entoure —, **Déplier le nœud** (Option+Cmd+Droite) le rouvre, **Replier le niveau supérieur** (Option+Cmd+Haut) replie tout au niveau le plus externe pour une vue d'ensemble, et **Tout déplier** (Option+Cmd+Bas) rétablit l'affichage. La ligne portant la clé ou la balise reste visible et est marquée, si bien qu'un bloc replié se voit comme tel ; les numéros de ligne sautent ce qui est caché. Rien n'est retiré du document — le texte n'est simplement pas dessiné, donc l'enregistrement, l'annulation et la recherche ne changent pas, et la recherche trouve toujours le texte à l'intérieur d'un bloc replié. Placer le curseur dans un repli l'ouvre, et toute modification ouvre tout : un repli est une paire de positions, et insérer du texte les déplace.

Le même menu porte les transformations, qui réécrivent tout le document — ou, si du texte est sélectionné, seulement celui-là — en une seule étape annulable : **Compacter (une ligne)** pour un corps JSON qui doit tenir dans une commande `curl`, **Trier les clés récursivement** pour que deux exports des mêmes réglages ne montrent plus aucune différence, **Échapper en chaîne JSON** et **Déséchapper la chaîne JSON** pour la corvée quotidienne consistant à mettre un certificat, un script ou un document JSON entier *dans* un champ JSON, et **Convertir JSON en YAML**. Le compactage conserve l'ordre des clés et l'écriture exacte de chaque nombre, car `1.0` et `1` ne sont pas la même version ; le tri ne le fait pas, délibérément, puisque trier est un réordonnancement. L'échappement s'applique à n'importe quel fichier, pas seulement à JSON. Il n'y a pas de YAML vers JSON, et c'est un choix : il faudrait un analyseur YAML que le système n'a pas, et une mauvaise supposition sur une ancre ou un `true` entre guillemets transforme un fichier de configuration en un autre.

Pour JSON et XML, le fichier est vérifié par un véritable analyseur. Pour YAML, il n'y en a aucun sur le système : la vérification couvre donc les erreurs repérables sans analyseur — une tabulation utilisée pour indenter, ce que YAML interdit formellement, une indentation qui ne correspond à rien, une clé en double, un guillemet non fermé — et le dit, au lieu d'affirmer que le fichier est valide.

## Filtrer par une commande shell

Cliquez sur **Filtrer…** (ou appuyez sur Shift+Cmd+\) pour envoyer le texte sélectionné dans une commande et le remplacer par ce que la commande affiche. Si rien n’est sélectionné, tout le document y passe. Les outils que vous connaissez déjà deviennent ainsi des commandes de l’éditeur : `sort -u` supprime les lignes en double, `jq .` rend une réponse JSON lisible, `column -t` aligne un tableau, `base64 -d` décode un bloc, `openssl x509 -noout -text` affiche un certificat en clair.

La commande s’exécute dans votre shell de connexion : votre `PATH`, vos alias et vos fonctions agissent exactement comme dans le Terminal, et les tubes et les guillemets ont le sens attendu. Le répertoire de travail est celui du fichier en cours d’édition, si bien que les chemins relatifs se résolvent là où vous l’attendez. Les commandes utilisées sont mémorisées et proposées dans la liste déroulante la fois suivante.

Si la commande échoue, votre texte reste intact et le message d’erreur de la commande apparaît dans la barre d’état : une erreur de syntaxe `jq` ne se retrouve jamais collée dans votre fichier. Une commande qui n’affiche rien vide la sélection — c’est exactement à cela que sert un filtrage avec `grep` — et Cmd+Z la restitue. Une commande qui ne se termine pas est arrêtée au bout de vingt secondes.

## Trier, dédupliquer et nettoyer des lignes

Le menu **Lignes** — dans la barre d’outils, et dans la barre des menus quand l’éditeur est au premier plan — applique les modifications qui reviennent sans cesse, sans commande à taper et sans outil à installer :

- Trier A→Z ou Z→A, en comparant les nombres par leur valeur, de sorte que `file9` précède `file10`.
- Inverser l’ordre des lignes.
- Supprimer les lignes en double, en gardant la première de chacune et en laissant les autres dans leur ordre.
- Supprimer les lignes vides, y compris celles qui ne semblent vides que parce qu’elles contiennent des espaces.
- Supprimer les espaces en fin de ligne — la différence invisible qui rend un diff illisible.
- Ne garder que les lignes contenant un texte que vous saisissez, ou les supprimer.

Si du texte est sélectionné, chacune de ces opérations agit sur les lignes sélectionnées ; la sélection est d’abord étendue aux lignes entières, car trier une demi-ligne n’a aucun sens. Sans sélection, elles agissent sur tout le document. Chacune est une seule étape d’annulation : Cmd+Z revient sur l’opération entière.

Les fins de ligne se trouvent à côté du menu Encodage : **LF** pour Unix et macOS, **CRLF** pour Windows, **CR** pour l’ancien Mac OS, et *(mixed)* lorsqu’un fichier en contient plusieurs sortes — souvent la raison d’une erreur incompréhensible. Choisissez-en une autre pour convertir tout le fichier en une étape annulable. Les opérations sur les lignes ne changent jamais la fin de ligne d’elles-mêmes : un fichier CRLF trié reste en CRLF.

## Formater un fichier

Cliquez sur **Formater** dans l’éditeur (la même commande existe dans la visionneuse) pour réindenter le fichier. Peach Commander choisit un formateur d’après l’extension et indique dans la barre d’état lequel a servi, par exemple *formatted (jq)* — vous savez donc toujours ce qui a façonné le résultat.

**Sans rien installer** : JSON, XML, SVG, plists, HTML, configuration de type INI et YAML. YAML est un cas à part : il est nettoyé plutôt que réindenté, car en YAML l’indentation *est* la structure, et la réécrire sans un vrai analyseur YAML pourrait changer le sens du fichier. Les espaces en fin de ligne disparaissent, les tabulations égarées dans l’indentation deviennent des espaces, les suites de lignes vides se réduisent — et tout ce qui est dans un scalaire de bloc (`|` ou `>`) reste tel quel, car là l’espace est du contenu.

**Les meilleurs formateurs prennent le relais automatiquement.** Si l’un d’eux est installé, Peach Commander l’utilise : un outil dédié correspond généralement à ce qu’attend l’écosystème — et pour les formats de configuration, il préserve vos commentaires :

| Installez | et vous obtenez |
| --- | --- |
| `yq` ou `prettier` | formatage YAML complet, commentaires préservés |
| `taplo` | TOML |
| `sqlformat` ou `sql-formatter` | SQL |
| `prettier` | Markdown |
| `jq` | JSON, dans le style habituel |
| `xmllint` | XML et SVG |

Si un type de fichier n’a pas de formateur, le bouton est grisé et l’entrée de menu désactivée. Essayer quand même vous dit pourquoi — *« taplo n’est pas installé »* ne se lit pas comme *« JSON invalide »*.

### Utiliser votre propre formateur

Pour formater un type que Peach Commander ne connaît pas, ou pour employer un autre outil, créez `formatters.ini` dans le dossier de configuration — une section par extension :

```ini
[swift]
tool = swiftformat
args = --quiet stdin

[sql]
tool = /opt/homebrew/bin/sqlfluff
args = format -
```

`tool` est un nom d’exécutable (recherché comme le ferait votre shell) ou un chemin absolu ; `args` sont passés tels quels. Le texte du fichier entre par l’entrée standard et le texte formaté est relu sur la sortie standard, donc tout formateur en ligne de commande bien élevé fonctionne. Vos entrées l’emportent sur tout le reste. Un modèle commenté est créé au premier lancement : ouvrez le fichier et complétez-le.

Les plugins peuvent aussi fournir des formateurs — voir [Plugins](plugins.md).

## Modifier un fichier octet par octet

1. Sélectionnez le fichier dans un panneau.
2. Choisissez Fichier ▸ Modifier en hexadécimal (ou cliquez droit sur le fichier et choisissez Modifier en hexadécimal).
3. Saisissez des chiffres hexadécimaux pour écraser des octets, ou utilisez les flèches pour parcourir le fichier. Retour arrière et Suppr retirent des octets.
4. Appuyez sur Cmd+S pour enregistrer. Comme dans l'éditeur de texte, le contenu précédent n'est conservé que si vous avez activé les sauvegardes.

## Raccourcis

| Action | Raccourci |
|---|---|
| Modifier le fichier | F4 |
| Créer et modifier un nouveau fichier texte | Maj+F4 |
| Enregistrer | Cmd+S |
| Rechercher | Cmd+F |
| Afficher/masquer le plan des symboles | Cmd+Maj+O |
| Aller à la ligne | Cmd+L |
| Sauter à la parenthèse correspondante | Cmd+\ |
| Aller au nœud englobant (JSON/YAML/XML) | Ctrl+Cmd+Haut |
| Aller au premier enfant | Ctrl+Cmd+Bas |
| Aller au frère précédent / suivant | Ctrl+Cmd+Gauche / Droite |
| Sélectionner le nœud englobant | Ctrl+Cmd+A |
| Copier le chemin structurel | Ctrl+Cmd+C |
| Valider le document | Ctrl+Cmd+V |
| Replier / déplier le nœud | Option+Cmd+Gauche / Droite |
| Replier le niveau supérieur / tout déplier | Option+Cmd+Haut / Bas |
| Annuler / rétablir (éditeur hexa) | Cmd+Z / Cmd+Maj+Z |
| Filtrer la sélection par une commande | Shift+Cmd+\ |

## Remarques

- La coloration syntaxique couvre JSON, C, C#, Java, JavaScript, TypeScript, Python et Rust. Les autres types de fichiers s'ouvrent et se modifient normalement avec une coloration basique, mais la coloration détaillée n'est disponible que pour les langages pris en charge.
- Le plan couvre les langages de programmation pris en charge ainsi que JSON, YAML et XML — y compris les formats fondés sur XML comme `.plist`, `.svg`, `.csproj` et `.storyboard`. Les commandes de navigation structurelle, de chemin et de validation s'appliquent à JSON, YAML et XML.
- Le plan des symboles et Aller à la ligne s'appliquent à l'éditeur de texte. L'éditeur hexadécimal est destiné à l'inspection binaire et aux modifications au niveau de l'octet, pas au texte.
- Aucun des deux éditeurs ne conserve de sauvegarde sans que vous la demandiez. Activez « Conserver une copie de sauvegarde (.bak) du contenu précédent lors de l’enregistrement » dans Réglages ▸ Modifier/Afficher : le premier enregistrement écrit alors l'original à côté du fichier sous le nom `name.bak`, et une modification accidentelle est facile à annuler.
