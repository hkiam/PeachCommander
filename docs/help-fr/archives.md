---
title: Utiliser les archives
slug: archives
section: Archives
order: 80
related: [copying-files]
---

Peach Commander traite les archives comme des dossiers. Vous pouvez entrer dans une archive ZIP, TAR ou autre format pris en charge, parcourir son contenu et en copier des fichiers — le tout sans décompresser sur le disque au préalable. Quand vous voulez créer une archive, la commande Compresser regroupe votre sélection dans un format ZIP, 7z, TAR ou autre, avec chiffrement facultatif et volumes fractionnés. C'est pratique pour regrouper des fichiers à envoyer, réduire un dossier pour le stockage ou jeter un œil dans un téléchargement avant de vous engager à l'extraire.

## Parcourir une archive comme un dossier

1. Dans un panneau, placez le curseur sur un fichier d'archive (par exemple un `.zip` ou un `.tar.gz`).
2. Appuyez sur Entrée ou Ctrl+PageDown pour y entrer, comme vous ouvririez un dossier.
3. Naviguez normalement dans le contenu. Appuyez sur Retour arrière ou Ctrl+PageUp pour remonter et quitter l'archive.
4. Pour en extraire des fichiers, sélectionnez-les et copiez (F5) vers l'autre panneau.

![Parcours de l'intérieur d'une archive comme s'il s'agissait d'un dossier](screenshots/archive-browse.png)
*(Figure : une archive ouverte affichée comme une liste de dossier ordinaire, avec ses fichiers prêts à être copiés.)*

ZIP, TAR et TAR compressé en gzip sont lus directement. D'autres formats tels que CPIO, ISO, CAB, LZH, XAR et PAX sont lus via les outils système intégrés. Les archives ZIP chiffrées (classiques et AES) peuvent être ouvertes lorsque vous fournissez le mot de passe.

## Compresser des fichiers dans une nouvelle archive

1. Sélectionnez les fichiers et dossiers à inclure dans le panneau actif.
2. Choisissez Fichier ▸ Compresser… ou appuyez sur Alt+F5. (Pour compresser puis supprimer les originaux, utilisez Alt+Maj+F5.)
3. Dans le dialogue, choisissez le format d'archive (ZIP, 7z, TAR, tar.gz, bzip2, xz ou RAR), le niveau de compression et l'emplacement d'enregistrement.
4. Facultativement, activez le chiffrement AES-256 et définissez un mot de passe, ou fractionnez l'archive en volumes de taille fixe.
5. Confirmez pour créer l'archive.

![Le dialogue Compresser montrant le format, la compression, le chiffrement et les options de fractionnement](screenshots/pack-dialog.png)
*(Figure : le dialogue Compresser, où vous choisissez le format et réglez le chiffrement et le fractionnement en volumes.)*

## Décompresser ou tester une archive

1. Placez l'archive à extraire dans le panneau actif et le dossier de destination dans l'autre panneau.
2. Choisissez Fichier ▸ Décompresser… ou appuyez sur Alt+F9, puis confirmez la destination.
3. Pour vérifier qu'une archive n'est pas endommagée sans l'extraire, choisissez Fichier ▸ Tester l'archive.

## Modifier un ZIP sur place

Vous pouvez ajouter ou retirer des fichiers dans un ZIP existant sans le décompresser. Ouvrez le ZIP comme un dossier, puis copiez-y des fichiers ou supprimez-en comme d'habitude — la modification est réécrite directement dans l'archive.

## Raccourcis

| Action | Raccourci |
| --- | --- |
| Entrer dans l'archive sous le curseur | Entrée ou Ctrl+PageDown |
| Quitter l'archive (remonter) | Retour arrière ou Ctrl+PageUp |
| Compresser | Alt+F5 |
| Compresser et supprimer les originaux | Alt+Maj+F5 |
| Décompresser | Alt+F9 |

## Remarques

- La compression en 7z, xz, bzip2 et RAR repose sur des outils externes. RAR en particulier nécessite l'installation du programme propriétaire RAR ; sans lui, ce format est indisponible.
- Modifier un ZIP sur place réécrit toute l'archive, de sorte que les dates de modification des fichiers à l'intérieur ne sont pas préservées.
- Les membres individuels très volumineux sont plafonnés à 512 Mio lors de l'extraction. L'extraction peut être annulée pendant son exécution.
- Les archives ZIP64 s’ouvrent comme les autres : une archive de plus de 65 535 éléments ou de plus de 4 Go se parcourt normalement ; la limite par membre extrait ci-dessus s’applique toujours.
