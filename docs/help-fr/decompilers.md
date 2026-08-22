---
title: Décompiler Java et .NET
slug: decompilers
section: Extensions
order: 131
related: [plugins, viewing-files, searching]
---

Appuyez sur **F3** sur un fichier compilé et voyez du code source plutôt que des octets. Deux extensions le font — une pour Java (`.class`, `.jar`, `.apk`, `.dex`) et une pour .NET (`.dll`, `.exe`, `.winmd`, `.netmodule`) — et elles se comportent de la même façon, d’où cette page commune. Chacune peut être désactivée ou supprimée séparément dans **Configuration ▸ Extensions…**.

Une archive apparaît comme une arborescence de ses classes ; une classe seule apparaît comme un fichier. **Décompiler vers les sources** dans le menu Commandes écrit le résultat et le place dans un panneau, pour y chercher, comparer et copier comme dans n’importe quel dossier de sources.

## C’est vous qui installez le moteur

Aucun décompilateur n’est fourni et rien n’est téléchargé pour vous. C’est délibéré, pour deux raisons : JD-Core, le décompilateur Java le plus connu, est sous GPLv3 et ne pouvait pas être livré dans une app Apache-2.0 — et les moteurs progressent, en changer ne devrait donc pas exiger une nouvelle version de Peach Commander.

**Dossier des moteurs…** dans la visionneuse ouvre le dossier auquel ils appartiennent. Le README qui s’y trouve nomme chaque moteur et sa licence.

| | |
| --- | --- |
| Java | CFR, Vineflower, Procyon, jadx (pour les `.dex` et `.apk` Android) et `javap` pour le bytecode brut |
| .NET | ILSpy, et `monodis` pour l’IL |

**Vérifier les moteurs** exécute la commande de version de chaque moteur et distingue trois choses : installé et fonctionnel, non installé, et *installé mais incapable de s’exécuter* — un outil Java sans JDK est présent et ne démarre pas pour autant, ce que seule une exécution réelle révèle.

Un moteur est décrit par des données et non par du code, vous pouvez donc en ajouter un vous-même :

```
[cfr]
kinds  = class, jar
tool   = java
args   = -jar {engine} {input}
engine = ~/Library/Application Support/PeachCommander/decompilers/cfr.jar
output = stdout
```

Quand plusieurs moteurs peuvent traiter un fichier, le premier disponible est utilisé, sauf si vous en choisissez un. Avec deux installés, **Comparer** montre les deux résultats côte à côte — utile lorsqu’un moteur renonce sur une méthode que l’autre traite.

## Chercher dans du code compilé

**Rechercher dans toutes les classes** parcourt le texte décompilé plutôt que les octets : vous pouvez donc trouver une chaîne littérale ou un nom de méthode dans un JAR.

Décompiler pendant une *recherche de contenu* sur de nombreux fichiers est un réglage distinct, désactivé par défaut : produire le texte peut vouloir dire lancer le moteur une fois par classe, ce qui sur une machine lente n’est pas une chose raisonnable à dépenser pour une recherche. La fenêtre de recherche principale pose la question séparément ; ici aussi, c’est refusé.

## Cache et limites

Les résultats sont mis en cache, car décompiler deux fois la même classe n’est que de l’attente. Les réglages contiennent le nombre de jours de conservation et une **limite de taille** pour le cache ; **Vider le cache maintenant** le vide et indique ce qui a été libéré.

Deux délais protègent contre un moteur qui ne finit pas : un pour une seule classe ou un seul type, un pour une archive entière. Tous deux acceptent 0, qui signifie « utiliser la valeur par défaut du moteur ».
