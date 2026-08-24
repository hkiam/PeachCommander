---
title: Markdown et HTML dans la visionneuse
slug: markdown-viewer
section: Plugins
order: 136
related: [plugins, viewing-files, privacy-and-security]
---

Appuyez sur F3 sur un fichier `.md` ou `.html` et il apparaît mis en forme plutôt qu'en source : titres, listes, tableaux, liens, listes de tâches et blocs de code colorés selon le langage. Les diagrammes écrits comme blocs ` ```mermaid ` sont dessinés, et les mathématiques écrites entre signes dollar sont composées.

C'est un plugin. Tout ce qui est décrit ici vient de **Markdown and HTML**, que vous pouvez désactiver dans **Configuration ▸ Plugins…** — voyez plus bas ce qui change alors.

## Où apparaît la vue mise en forme

- **La visionneuse (F3).** La page mise en forme. Le menu **Affichage** propose toujours Texte, Code et Hex, la source est donc à un clic, et le nom du plugin figure aussi dans cette liste.
- **Quick View (Ctrl+Q) et la page d'informations** du panneau latéral montrent le même rendu, si bien qu'un aperçu et une vue complète d'un même fichier ne se contredisent jamais.
- **La galerie** montre une petite image du début d'un fichier Markdown au lieu d'une icône de document générique.
- **Quick Look (Cmd+Y)** est l'aperçu de macOS lui-même et n'est *pas* concerné — ce panneau appartient au système, et aucun plugin ne peut y dessiner.

## Le plan des symboles

Appuyez sur **Symboles** dans la visionneuse pour obtenir les titres du document, imbriqués tels qu'ils sont écrits, et cliquez sur l'un d'eux pour y sauter dans la page. Cela fonctionne sur la vue mise en forme comme sur la source, et les deux s'accordent sur l'emplacement d'un titre.

## Diagrammes et mathématiques

Un bloc de code dont le langage est `mermaid` devient un diagramme ; `$…$` et `$$…$$` deviennent des mathématiques composées. Les deux sont dessinés **sur votre Mac**, par des moteurs livrés dans le plugin — rien n'est téléchargé, et aucune partie de votre document n'est envoyée où que ce soit. Un signe dollar dans un bloc de code ou du code en ligne reste un signe dollar.

Un document sans diagramme ni formule ne charge aucun des deux moteurs : un README ordinaire ne coûte donc rien de plus. Un diagramme illisible affiche l'erreur là où le bloc se trouvait, avec le texte du bloc en dessous, au lieu de disparaître.

Les deux peuvent être désactivés séparément dans **Configuration ▸ Réglages ▸ Markdown**, où l'on voit aussi quelle version est utilisée et d'où elle vient.

## Votre propre version

Si vous avez besoin d'une version plus récente ou différente de Mermaid ou de KaTeX, placez-la dans le dossier qu'ouvre le bouton **Engine Folder…** et elle sera utilisée à la place de celle fournie. Les noms de fichiers sont `mermaid.min.js`, `katex.min.js`, `katex.min.css` et `auto-render.min.js`. Rien n'est jamais récupéré sur Internet pour vous.

## Ce que la page mise en forme ne fera pas

La page mise en forme est délibérément isolée, car un fichier Markdown est un contenu venu d'ailleurs :

- **Elle ne charge rien par le réseau.** Une image dont l'adresse commence par `http` reste vide à dessein : la récupérer indiquerait à ce serveur quand vous avez ouvert le fichier, et depuis quelle adresse. Une image posée à côté du document sur le disque se charge normalement.
- **Les scripts et le HTML du document ne s'exécutent jamais.** Le HTML écrit dans un fichier Markdown est montré comme du texte, et un fichier `.html` est affiché avec les scripts désactivés.

## Le désactiver

Désactivez le plugin dans **Configuration ▸ Plugins…**, et les fichiers `.md` et `.html` s'ouvrent en texte. Le plan continue de fonctionner, la coloration syntaxique aussi, et rien d'autre ne change — la vue mise en forme n'est simplement plus proposée. Il en va de même si vous ne désactivez que la vue mise en forme sur la page de réglages du plugin.

## Limites

- Les fichiers dépassant une taille limite (8 Mo par défaut, sur la page de réglages) s'ouvrent en texte. Transformer un très gros document généré en page mise en forme est lent, et la visionneuse de texte l'ouvre immédiatement.
- La page mise en forme ne peut pas être modifiée. Utilisez F4 pour cela, ou la vue Texte pour **Formater**, **Encodage** et **Aller à**, qui s'appliquent à la source et non à une page rendue.
