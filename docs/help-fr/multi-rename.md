---
title: Renommer plusieurs fichiers
slug: multi-rename
section: Outils avancés
order: 92
related: [moving-and-renaming]
---

L'outil de renommage multiple renomme tout un lot de fichiers en une seule passe. Au lieu de modifier les noms un par un, vous décrivez la modification une seule fois — un motif de nommage, un rechercher-remplacer, un schéma de numérotation ou un changement de casse — et Peach Commander l'applique à chaque fichier sélectionné. Un aperçu en direct montre exactement le nom que portera chaque fichier avant que quoi que ce soit ne se produise, et une seule action Annuler rétablit les noms d'origine si le résultat ne vous convient pas.

## Renommer un lot de fichiers

1. Sélectionnez les fichiers que vous souhaitez renommer (voir *Sélectionner des fichiers*). Seuls les éléments sélectionnés sont concernés.
2. Choisissez **Commandes > Outil de renommage multiple…**, ou appuyez sur Ctrl+M.
3. Construisez votre règle de renommage à l'aide des champs décrits ci-dessous. La grille d'aperçu se met à jour au fur et à mesure que vous saisissez, affichant chaque **Ancien nom** à côté de son **Nouveau nom**.
4. Vérifiez l'aperçu. Une ligne affichée dans une couleur de mise en évidence signale un nom qui ne peut pas être utilisé (par exemple, un doublon ou un nom interdit) afin que vous puissiez ajuster la règle.
5. Lorsque l'aperçu vous convient, cliquez sur **Démarrer**. Si vous changez d'avis, cliquez sur **Annuler** pour restaurer les noms d'origine.

![La fenêtre de renommage multiple avec les champs de masque, les options et la grille d'aperçu ancien-vers-nouveau](screenshots/multi-rename.png)
*(Figure : la grille d'aperçu se met à jour en direct au fur et à mesure que vous modifiez la règle de renommage ; rien n'est modifié sur le disque tant que vous n'avez pas cliqué sur Démarrer.)*

## Construire la règle de renommage

- **Masque de renommage** et **Extension** — des motifs qui construisent le nouveau nom et la nouvelle extension. Utilisez les boutons d'insertion rapide, ou saisissez directement les marqueurs : `[N]` pour le nom d'origine, `[N1-9]` pour une plage de caractères de celui-ci, `[C]` pour le compteur, `[d]` pour des éléments de date et d'heure, et `[P]` pour le nom du dossier parent.
- **Rechercher / Remplacer par** — remplace du texte à l'intérieur des noms. Activez **Regex** pour la correspondance par motif, **Sensible à la casse** pour respecter la casse exacte, et **Répéter** pour remplacer chaque occurrence.
- **Casse** — convertit les noms en minuscules, MAJUSCULES, Première lettre en majuscule, ou Chaque Mot En Majuscule.
- **Compteur** — définissez le numéro de **Départ**, le **Pas** entre les fichiers, et le nombre de **Chiffres** de remplissage (par exemple, 001, 002, 003) partout où `[C]` apparaît.

## Raccourcis

| Action | Raccourci |
| --- | --- |
| Ouvrir l'outil de renommage multiple | Ctrl+M |
| Appliquer le renommage | Return |
| Fermer la fenêtre | Esc |

## Astuces

- Rien n'est écrit sur le disque tant que vous n'avez pas cliqué sur **Démarrer** : vous pouvez donc expérimenter librement avec la règle et observer l'aperçu.
- Après une exécution, **Annuler** inverse le renommage en une seule étape.
- Enregistrez une règle que vous utilisez souvent en tant que **Préréglage**, puis choisissez-la dans le menu des préréglages la prochaine fois pour remplir tous les champs d'un coup.
- Pour renommer un seul fichier, ou pour renommer des fichiers au moment où vous les déplacez, utilisez plutôt le renommage sur place ou la boîte de dialogue de déplacement (voir *Déplacer et renommer*).
