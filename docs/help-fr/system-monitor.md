---
title: System Monitor
slug: system-monitor
section: Extensions
order: 124
related: [plugins, settings]
---

L'extension System Monitor place un relevé en temps réel de l'activité de votre Mac directement dans la barre de titre de la fenêtre : de petites pastilles pour le processeur, la mémoire, le disque, le réseau et — là où le matériel les expose — le GPU, la batterie et les capteurs. Chaque pastille se met à jour une fois par seconde ; cliquez sur l'une d'elles pour une fenêtre surgissante avec un graphique d'historique et un détail complet. C'est une extension, vous pouvez donc l'activer, la configurer ou la retirer dans **Configuration ▸ Extensions…**.

## Les pastilles de la barre de titre

Lorsque l'extension est active, une rangée de pastilles compactes se trouve dans la barre de titre. Chaque pastille est un point coloré, une courte étiquette et une valeur en temps réel (certaines avec une courbe sparkline en ligne) :

| Pastille | Affiche |
| --- | --- |
| **CPU** | Charge du processeur, avec le détail par cœur |
| **RAM** | Mémoire utilisée / totale (plus câblée, compressée, swap) |
| **HDD** | Espace du volume de démarrage et débit de lecture/écriture |
| **Net** | Débits de téléchargement / téléversement et totaux |
| **GPU** · **Batt** · **Sens** | Utilisation du GPU · charge et état de la batterie · vitesses de ventilateur et températures |

Cliquez sur une pastille pour ouvrir une fenêtre surgissante avec la grande valeur courante, une courbe **HISTORIQUE**, une liste clé/valeur **DÉTAILS** et — pour le CPU — une liste **CHARGE DES CŒURS** de barres par cœur.

## La configurer

Choisissez **Commandes ▸ System Monitor…** (ou ouvrez **Configuration ▸ Réglages ▸ System Monitor**) pour configurer le relevé :

- **Afficher le moniteur système dans la barre de titre** — l'interrupteur principal des pastilles.
- **Profil** — préréglages *Minimal*, *Moyen* ou *Maximal* qui choisissent un ensemble de modules judicieux.
- **Le tableau des modules** — activez ou désactivez chaque module (CPU, GPU, RAM, HDD, Net, Batt, Sens), choisissez sa couleur, et faites glisser les lignes pour définir l'ordre dans lequel ils apparaissent dans la barre de titre. Les modules que votre matériel ne peut pas rapporter s'affichent comme *(n/d)*.

![Les réglages de System Monitor avec son tableau des modules, les profils et les couleurs par module](screenshots/system-monitor.png)
*(Figure : choisissez quels modules apparaissent, leurs couleurs et leur ordre.)*

## Remarques

- Tout est mesuré, jamais inventé : les modules dont le matériel n'expose pas les données (souvent le GPU ou les capteurs sur certains Macs) restent indisponibles plutôt que d'afficher des chiffres fabriqués. La batterie est indisponible sur les ordinateurs de bureau.
- L'échantillonnage s'exécute sur une minuterie en arrière-plan uniquement lorsque le relevé est visible, et conserve environ 30 minutes d'historique pour les graphiques.
- Vos choix de modules, couleurs et ordre sont enregistrés avec la configuration de l'application.
