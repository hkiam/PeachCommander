---
title: Assistant IA
slug: ai-assistant
section: Extensions
order: 122
related: [plugins, settings, privacy-and-security]
---

L'assistant IA est une extension facultative et amovible qui vous aide à travailler avec vos fichiers en langage naturel. Il peut résumer ou expliquer un document, suggérer un meilleur nom de fichier, traduire ou relire du texte, transformer des données en tableau et même organiser un dossier — et il peut effectuer des actions sur les fichiers pour vous après vous avoir d'abord montré un plan. Il se compose de deux modules : **AI On-Device** fonctionne avec Apple Intelligence et fournit les actions qui montrent une proposition et l’appliquent, tandis que **AI Assistant** est le chat et nécessite un modèle cloud. Activez l’un, ou les deux. Comme il s'agit d'une extension, vous pouvez la désactiver ou la supprimer entièrement depuis **Configuration ▸ Extensions…**.

## Ouvrir l'assistant

Choisissez **Commandes ▸ Assistant IA** pour afficher l'assistant dans un panneau ancré à droite de la fenêtre. Saisissez une requête et appuyez sur Retour ; l'assistant peut lire des fichiers, chercher des informations et — avec votre confirmation — effectuer des modifications.

![Le chat de l'assistant IA ancré à côté des panneaux de fichiers](screenshots/ai-chat.png)
*(Figure : l'assistant IA, ancré à droite, travaillant sur une requête.)*

## Actions du clic droit (IA ▸)

Le moyen le plus rapide d'utiliser l'assistant est le sous-menu **IA ▸** du menu contextuel :

- **Sur un fichier** — Résumer, Expliquer, Suggérer un nom, Suggérer un commentaire, Traduire en anglais, Relire, Détecter les tâches et Créer un tableau.
- **Sur l'arrière-plan du panneau** — Rechercher par sens, Organiser ce dossier et Trouver les doublons probables.

**Résumer**, **Expliquer**, **Proposer un nom**, **Proposer un commentaire** et **Organiser ce dossier** proviennent du module **AI On-Device** et font leur travail sans ouvrir de chat : ils montrent leur proposition dans une feuille, vous décochez ce que vous voulez laisser tel quel, et rien ne change sur le disque avant votre approbation. Les autres actions appartiennent au module **AI Assistant** et ouvrent leur propre chat nommé, si bien que les tâches restent séparées. Lorsque vous écrivez vous-même dans le champ de saisie, cette demande poursuit le chat en cours.

## Gérer vos chats

- Utilisez le sélecteur de chat en haut du panneau pour passer d'une conversation à l'autre.
- Le menu **Supprimer ▾** propose **Supprimer ce chat** et **Supprimer tous les chats**, pour tout effacer d'un coup quand la liste devient longue. Les chats vides sont nettoyés automatiquement à la fermeture du panneau.

## Les modifications sont d'abord confirmées

Pour tout ce qui modifie des fichiers — déplacer, renommer, écrire, supprimer — l'assistant affiche un **plan et attend votre confirmation** avant d'agir. Vous pouvez changer cela dans les Réglages en augmentant l'autonomie de l'assistant, ou l'abaisser en lecture seule pour qu'il ne modifie jamais rien.

## Réglages

Ouvrez **Configuration ▸ Réglages ▸ IA** pour configurer l'assistant sur une seule page :

- **Modèle préféré** — quel modèle le chat **AI Assistant** utilise. Depuis que les actions sur l’appareil forment un module distinct, cela ne concerne que le chat : *Cloud* et *Automatique* utilisent le point de terminaison ci-dessous, et *Sur l’appareil* indique au chat qu’il n’est pas requis.
- **Point de terminaison cloud, modèle et clé API** — pour utiliser un modèle compatible OpenAI au lieu de celui sur l'appareil. La clé est stockée dans le trousseau macOS, jamais dans vos fichiers de configuration.
- **Autonomie de l'assistant** — lecture seule, confirmer les modifications (par défaut) ou autonome.
- **Invite système personnalisée** — instructions facultatives qui façonnent les réponses de l'assistant.
- **Serveur MCP** — un serveur local facultatif qui permet à un agent externe de piloter l'application ; désactivé par défaut et protégeable par un jeton.

![La page IA des Réglages avec l'autonomie et les options du serveur MCP](screenshots/settings-ai.png)
*(Figure : toutes les options de l'assistant se trouvent sur une seule page IA dans les Réglages.)*

## Confidentialité

- Avec Apple Intelligence, l'assistant fonctionne **sur votre Mac** ; rien ne quitte l'appareil.
- Un modèle cloud n'est utilisé **que si vous en configurez un**, et sa clé API est conservée dans le trousseau.
- Les actions qui modifient des fichiers sont confirmées avant leur exécution, sauf si vous augmentez délibérément le niveau d'autonomie.
