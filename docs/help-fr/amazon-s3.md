---
title: Amazon S3 et stockages compatibles S3
slug: amazon-s3
section: Extensions
order: 135
related: [plugins, webdav, ftp-and-sftp, copying-files]
---

Un bucket S3 peut être parcouru dans un panneau comme n’importe quel dossier. Choisissez **Se connecter à Amazon S3…** dans le menu Réseau, renseignez le point d’accès et vos clés, et le stockage apparaît dans le panneau actif — avec la **liste des buckets comme niveau supérieur**, chaque bucket étant un répertoire ordinaire en dessous.

Cela fonctionne avec Amazon S3 et avec tout ce qui parle le même protocole : MinIO, Ceph/RADOS Gateway, Cloudflare R2, Wasabi, Backblaze B2 et DigitalOcean Spaces sont tous accessibles.

C’est une extension : vous pouvez la désactiver ou la retirer dans **Configuration ▸ Extensions…**.

## Se connecter

Le menu **Service** renseigne les deux réglages qui ne se devinent pas — utiliser HTTPS et savoir si le point d’accès exige l’adressage par chemin — et laisse le point d’accès lui-même, car il dépend généralement de votre compte. Ces deux réglages échouent d’une manière qui ressemble à autre chose : l’adressage par nom d’hôte virtuel contre une adresse IP nue est une erreur de résolution de nom, et l’adressage par chemin contre Amazon est un « bucket inexistant » qui se lit comme un bucket manquant.

La **clé d’accès secrète** est confiée au **trousseau** par l’application hôte, jamais à un fichier de configuration. Laissez le champ vide lors d’une connexion ultérieure et la clé enregistrée est utilisée.

**Mémoriser cette connexion** conserve le point d’accès, la région, l’ID de clé et le mode d’adressage — jamais le secret — dans `~/Library/Application Support/PeachCommander/s3/profiles.json`. Une connexion mémorisée devient aussi une vignette dans la barre des volumes, et un clic dessus s’y connecte directement au lieu de rouvrir cette fenêtre.

### Les profils que vous avez déjà

Si vous utilisez la ligne de commande AWS, ses profils sont proposés dans le menu **Nom** avec la mention *(AWS CLI)*, lus depuis `~/.aws/credentials` et `~/.aws/config` — y compris la région, un jeton de session et `s3.addressing_style`. Rien n’y est réécrit, et un tel profil n’est **pas** mémorisé par défaut : garder une deuxième copie d’un secret est une chose que l’on demande, pas une chose qui arrive parce qu’on a choisi un nom dans un menu.

### Buckets publics

**Se connecter anonymement** n’envoie aucune signature, ce qu’attend un bucket lisible publiquement. Si le bucket n’est pas public, on vous le dit — et non que votre clé a été refusée. Il n’y avait pas de clé.

## Ce que vous pouvez faire

Lister, lire, écrire, créer des dossiers et des buckets, supprimer, renommer et déplacer fonctionnent tous. Les copies et les déplacements ont lieu **sur le serveur** : les octets ne passent pas par votre Mac.

Un dossier n’existe pas vraiment dans S3 — c’est soit un préfixe commun aux clés qu’il contient, soit un objet de zéro octet dont le nom se termine par `/`. Les deux sont présentés comme des dossiers. En créer un écrit ce marqueur ; en supprimer un supprime tous les objets en dessous, car il n’y a rien d’autre à supprimer.

Au niveau supérieur, **Nouveau dossier crée un bucket** — ce niveau *est* la liste des buckets, cela ne pourrait rien signifier d’autre.

**Classe de stockage** et **ETag** sont disponibles comme colonnes du panneau (clic droit sur l’en-tête). Toutes deux proviennent de la liste déjà obtenue et ne coûtent donc rien.

## À quoi vous attendre

**Un bucket ne peut pas être renommé.** S3 n’a pas cette opération, et l’alternative — copier chaque objet dans un nouveau bucket puis supprimer l’ancien — n’est pas ce qu’une fenêtre de renommage a demandé. C’est refusé plutôt que simulé.

**Les transferts portent sur des fichiers entiers.** Un fichier est récupéré ou envoyé d’un seul tenant ; un transfert interrompu recommence au lieu de reprendre. Les envois volumineux sont découpés automatiquement ; si une partie échoue, les parties sont nettoyées plutôt que laissées à facturer.

**Renommer un dossier n’est pas atomique.** Cela copie et supprime objet par objet, et s’arrête à la première erreur au lieu de continuer vers un état à moitié déplacé.

**Les objets archivés ne se lisent pas directement.** Un objet dans Glacier ou Deep Archive doit d’abord être restauré, dans la console AWS ou avec la CLI. Le panneau le dit, au lieu d’échouer comme si l’objet était endommagé.

**Lister un très grand dossier prend le temps que met le serveur.** Les objets arrivent par milliers et le panneau se remplit quand la dernière page est arrivée.

**Chaque requête coûte de l’argent sur un service payant.** L’extension est écrite pour demander le moins possible — les colonnes viennent de la liste déjà obtenue, la région d’un bucket est apprise une fois et retenue — mais parcourir un bucket n’est pas gratuit comme parcourir un disque.
