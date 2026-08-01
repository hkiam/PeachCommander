---
title: Afficher des fichiers
slug: viewing-files
section: Affichage et édition
order: 70
related: [editing-files, searching]
---

Peach Commander dispose d'un lecteur intégré qui vous permet de regarder à l'intérieur d'un fichier sans ouvrir une autre application ni modifier le fichier. Appuyez sur F3 sur l'élément sous le curseur et le lecteur s'ouvre instantanément, même pour de très gros fichiers. Il choisit automatiquement la meilleure façon d'afficher le contenu : texte lisible, code coloré, vidage hexadécimal brut, ou image en taille réelle. Vous pouvez aussi prévisualiser un fichier directement dans la fenêtre avec l'Aperçu rapide, ou le confier à Coup d'œil de macOS.

## Afficher un fichier

1. Placez le curseur sur un fichier dans le panneau actif.
2. Appuyez sur F3 (ou choisissez Afficher dans le menu Fichier). Le lecteur s'ouvre dans sa propre fenêtre.
3. Utilisez la barre d'outils pour changer la façon dont le contenu est affiché : Texte, Code, Hexa, Image ou Rendu. Laissez-la sur le réglage automatique pour laisser Peach Commander décider.
4. Faites défiler avec les flèches, Page préc./Page suiv. et la barre de défilement. Pour un long texte, activez le bouton minicarte pour voir et parcourir tout le fichier d'un coup d'œil.
5. Appuyez sur N pour sauter au fichier sélectionné suivant, ou fermez la fenêtre avec Échap.

![Le lecteur intégré affichant un fichier texte avec la minicarte à droite](screenshots/lister-text.png)
*(Figure : affichage d'un fichier texte, avec le sélecteur de représentation et la minicarte dans la barre d'outils.)*

## Rechercher du texte et changer l'encodage

- Appuyez sur Ctrl+F pour rechercher dans le fichier. Appuyez sur F3 pour sauter à la correspondance suivante et Maj+F3 pour la précédente.
- Si le texte semble déformé, cliquez sur Encodage dans la barre d'outils (ou appuyez sur E) pour faire défiler les encodages jusqu'à ce qu'il se lise correctement ; le réglage automatique est généralement juste.
- Appuyez sur W pour basculer le retour à la ligne pour les lignes longues.

## Aperçu rapide et Coup d'œil

L'Aperçu rapide affiche un aperçu en direct dans le panneau que vous n'utilisez *pas*, de sorte que vous pouvez continuer à naviguer d'un côté tout en prévisualisant de l'autre.

1. Appuyez sur Ctrl+Q. Le panneau inactif devient une zone d'aperçu.
2. Déplacez le curseur sur différents fichiers dans le panneau actif pour prévisualiser chacun.
3. Appuyez de nouveau sur Ctrl+Q, ou sur Échap, pour rendre au panneau une liste de fichiers normale.

Pour un aperçu plein écran rapide géré par macOS lui-même, appuyez sur Cmd+Y (Coup d'œil). Appuyez de nouveau sur Cmd+Y ou Espace pour le fermer.

## La page Infos du panneau latéral

Le panneau latéral (**Présentation > Panneau d’aperçu**, ou Cmd+Maj+P) comporte une page **Infos** qui présente l’élément sous le curseur comme le fait la barre latérale d’informations du Finder.

- L’aperçu occupe toute la largeur du panneau : élargissez le panneau et l’aperçu grandit avec lui. Faites glisser le bord gauche du panneau pour l’élargir ou le rétrécir ; la largeur est mémorisée.
- C’est un véritable aperçu macOS, pas une petite vignette : tous les formats que Coup d’œil sait afficher fonctionnent ici, et un document de plusieurs pages se parcourt page par page dans l’aperçu.
- En dessous figurent le nom, le type et la taille, puis les dates de création et de modification et le dossier où se trouve l’élément.

Lorsque le curseur se déplace, le nom et les informations se mettent à jour immédiatement ; l’aperçu suit un instant plus tard, afin qu’une flèche maintenue à travers un long dossier ne lance pas un aperçu pour chaque ligne traversée.

## Décompiler des fichiers .class Java

Avec le module **Java Decompiler** activé, F3 sur un fichier `.class` affiche du code lisible au lieu de données binaires — y compris pour les classes situées dans un JAR ou un ZIP, dans lequel vous pouvez entrer et lire sans le décompresser.

Le module ne contient aucun décompilateur. Il pilote un moteur que vous installez, et vous pouvez en changer à tout moment :

- **CFR** (licence MIT) et **Vineflower** (Apache 2.0) produisent du source Java. Placez `cfr.jar` ou `vineflower.jar` dans le dossier des moteurs.
- **Procyon** (Apache 2.0) est un troisième décompilateur vers le source.
- **javap** ne demande aucun téléchargement : il accompagne tout JDK et montre du bytecode plutôt que du source Java.

Rien n’est téléchargé à votre place : ce sont des programmes tiers sous leurs propres licences, et Peach Commander ne les récupère ni ne les met à jour. Le bouton **Dossier des moteurs…** de la visionneuse ouvre le dossier auquel ils sont destinés et y dépose une note nommant chaque moteur et son adresse de téléchargement. Tous sauf javap exigent Java.

Changez de moteur avec le menu en haut de la visionneuse ; celui que vous choisissez est utilisé immédiatement et le résultat est conservé, si bien que comparer deux moteurs sur le même fichier est instantané.

Le source est coloré syntaxiquement, et deux boutons vont plus loin : **Enregistrer sous…** l’écrit dans un fichier, et **Ouvrir dans l’éditeur** le confie à ce qui ouvre les `.java` sur votre Mac. Un résultat très volumineux s’affiche sans coloration afin de paraître immédiatement plutôt qu’après une pause ; la ligne d’état l’indique.

Les résultats sont mis en cache sur le disque : réouvrir un fichier déjà consulté est immédiat. La clé comprend la taille et la date du fichier ainsi que les arguments du moteur, si bien qu’une classe recompilée ou une option modifiée est décompilée à nouveau. Le moteur choisi est mémorisé par type de fichier. Un profil peut hériter d’un moteur intégré avec `extends = cfr` et ne redéfinir que les options — utile si vous gardez deux préréglages du même moteur.

Android est également couvert : F3 sur un fichier `.dex` utilise **jadx** (Apache 2.0, `brew install jadx`), qui reconvertit le bytecode Dalvik en Java. Il a suffi d’une description de moteur — même mécanisme, autre format.

Le module est **désactivé tant que vous ne l’activez pas**, dans Réglages ▸ Modules — la plupart des gens n’ouvrent jamais de fichier .class, et sans moteur il ne sert à rien.

Pour ajouter votre propre moteur, créez `decompilers.ini` dans le dossier des moteurs :

```ini
[myengine]
name   = My Decompiler
kinds  = class
tool   = java
args    = -jar {engine} {input}
engine  = my-decompiler.jar   ; a bare name is looked up in this folder
output  = stdout
timeout = 30                  ; seconds before the engine is stopped
```

`{input}`, `{engine}` et `{outdir}` sont remplacés à l’exécution. Vos entrées ont priorité sur celles fournies, et réutiliser un nom intégré (`cfr`, `vineflower`, `procyon`, `javap`) le remplace au lieu d’ajouter une seconde entrée.

## Raccourcis

| Action | Raccourci |
| --- | --- |
| Afficher le fichier sous le curseur | F3 |
| Afficher seulement le fichier sous le curseur (ignorer les fichiers marqués) | Maj+F3 |
| Ouvrir dans un lecteur externe | Option+F3 |
| Rechercher dans le lecteur | Ctrl+F |
| Correspondance suivante / précédente | F3 / Maj+F3 |
| Aperçu rapide dans l'autre panneau | Ctrl+Q |
| Coup d'œil (aperçu macOS) | Cmd+Y |
| Fermer le lecteur ou l'Aperçu rapide | Échap |

## Remarques

- Le lecteur est en lecture seule. Pour modifier un fichier, utilisez plutôt l'éditeur (voir Modifier des fichiers).
- Les très gros fichiers s'ouvrent sans délai : le texte ouvre une vue rapide et défilable, et la vue hexa est diffusée directement depuis le disque quelle que soit la taille.
- Appuyez sur F3 sur un dossier pour voir un résumé de son contenu et sa taille totale au lieu des octets d'un fichier.
- Le mode Rendu affiche du contenu formaté tel que des pages web ; le mode hexa montre les octets bruts côte à côte avec leurs caractères, ce qui est pratique pour inspecter des fichiers binaires.
- En mode Rendu, vous pouvez sélectionner et copier du texte, et Rechercher explore la page rendue. Les boutons inapplicables à une page rendue — Formater, Encodage, Tout sélectionner, Sélections et Aller à — sont grisés plutôt que sans effet.
- Le bouton Formater réindente les fichiers structurés (JSON, XML, HTML, INI, YAML, et d’autres si l’outil en ligne de commande correspondant est installé). Il est décrit en détail sous [Modifier des fichiers](editing-files.md#formatting-a-file) et fonctionne ici de la même façon.
