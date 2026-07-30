---
title: Git
slug: git
section: Plugin
order: 123
related: [plugins, view-modes-and-sorting]
---

Il plugin Git mostra lo stato di un repository Git direttamente nel pannello dei file — senza un'app separata, senza terminale. Aggiunge due colonne che indicano lo stato dell'albero di lavoro di ciascun file e il ramo corrente, un sottomenu **Git** per i comandi di tutti i giorni (status, stage, commit, pull, push), ed esegue il `git` già installato sul vostro Mac. Trattandosi di un plugin, potete disattivarlo o rimuoverlo da **Configurazione ▸ Plugin…**.

## Cosa aggiunge

- **Due colonne nell'elenco dei file** — *Git Status* e *Branch*. In un repository, ogni file mostra una breve parola di stato (Modificato, Aggiunto, Eliminato, Non tracciato, Rinominato, Copiato, Conflitto, Ignorato o Cambiato) e il pannello mostra il ramo corrente. Attivate le colonne da **Configurazione ▸ Colonne…** (vedi [Modalità di visualizzazione e ordinamento](view-modes-and-sorting.md)).
- **Un menu Git** — sotto **Comandi ▸ Git**, e nel menu del clic destro di un file, con: **Git Status…**, **Git Add (stage)**, **Git Commit…**, **Git Pull** e **Git Push**.

![La finestra Git Status che mostra il ramo corrente e i file modificati nel repository](screenshots/git-status.png)
*(Figura: Git Status riporta il ramo e ogni modifica nell'albero di lavoro.)*

## Controllare lo stato

1. Posizionate il cursore su un file o una cartella all'interno di un repository Git.
2. Scegliete **Comandi ▸ Git ▸ Git Status…** (oppure clic destro ▸ **Git ▸ Git Status…**).
3. Compare un riepilogo: il ramo corrente (o *(detached)*), poi *Working tree clean.* oppure un elenco di modifiche, dove ogni riga mostra lo stato e il percorso del file.

Se il cursore non si trova all'interno di un repository, il plugin dice semplicemente *Not a Git repository.*

## Stage, commit, pull, push

- **Git Add (stage)** prepara (stage) il file sotto il cursore (`git add`).
- **Git Commit…** richiede un messaggio di commit, poi esegue il commit di tutte le modifiche (`git commit -a`). L'output combinato viene mostrato così potete vedere esattamente cosa è successo.
- **Git Pull** esegue un pull solo in fast-forward (`git pull --ff-only`).
- **Git Push** invia il ramo corrente (`git push`).

Dopo un comando che modifica il repository, il pannello attivo si aggiorna così le colonne di stato restano correnti.

## Note

- Il plugin usa il Git di sistema in `/usr/bin/git`. Se Git non è installato, i comandi segnalano che Git non è disponibile. (L'installazione degli Strumenti da riga di comando di Xcode lo fornisce.)
- Lo stato del repository viene letto una volta per cartella e messo in cache, così lo scorrimento di un repository grande resta veloce; la cache si aggiorna dopo qualsiasi comando che modifica l'albero.
- Il commit usa `git commit -a`, che esegue il commit delle modifiche tracciate; i file nuovi di zecca richiedono comunque prima **Git Add (stage)**.
- Le intestazioni delle colonne *Git Status* e *Branch* al momento compaiono in inglese anche nelle altre lingue dell'interfaccia; i valori e le finestre di dialogo sono localizzati.
