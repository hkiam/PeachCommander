---
title: Git
slug: git
section: Plugin
order: 123
related: [plugins, view-modes-and-sorting]
---

Il plugin Git porta lo stato di un repository Git direttamente nel pannello dei file — nessuna applicazione a
parte, nessun terminale. Aggiunge due colonne, un sottomenu **Git**, un pannello agganciato per preparare e
committare, e finestre per la cronologia, il blame, i branch, i conflitti e il rebase. Usa il `git` già
installato sul tuo Mac. È un plugin, quindi puoi disattivarlo o rimuoverlo in **Configurazione ▸ Plugin…**.

## Che cosa aggiunge

- **Due colonne nell’elenco** — *Stato Git* e *Branch*. Ogni file mostra un’icona e una parola di stato breve
  (Modificato, Aggiunto, Eliminato, Non tracciato, Rinominato, Copiato, Conflitto, Ignorato, Tipo cambiato),
  con *(preparato)* quando la modifica è già nell’indice; la colonna *Branch* indica il branch su cui si
  trova il repository di quel file. Attiva le colonne in **Configurazione ▸ Colonne…** (vedi
  [Modalità di vista e ordinamento](view-modes-and-sorting.md)).
- **Un menu Git** — sotto **Comandi ▸ Git**, e nel menu contestuale di un file.

![La finestra Stato Git con il branch corrente e i file modificati del repository](screenshots/git-status.png)
*(Figura: Stato Git riporta il branch e ogni modifica nell’albero di lavoro.)*

## Il pannello: preparare, committare, sincronizzare

**Comandi ▸ Git ▸ Pannello** aggancia una vista che raggruppa l’albero di lavoro in *preparato*, *modificato*
e *non tracciato*. Seleziona dei file e usa **Prepara**, **Togli dalla preparazione** o **Scarta…**, scrivi
un messaggio e premi **Commit** — con **Amend** per ripiegare la modifica nel commit precedente. **Pull** e
**Push** stanno lì accanto, dove il commit avviene comunque; entrambi mostrano l’avanzamento e si possono
annullare.

Si committa l’*indice*, non `git commit -a`: quello che hai preparato è quello che viene committato.

## Cronologia, blame e il web

- **Cronologia…** elenca i commit con un grafo a corsie, i riferimenti che puntano a ciascuno (`● main`,
  `↗ origin/main`, `⚑ v1.0`) e i file che ogni commit ha toccato. Invio o un doppio clic apre la versione di
  quel file contro il suo predecessore nella finestra di confronto. **Revert del commit** e **Cherry-pick**
  sono lì, ed entrambi rifiutano in partenza se l’albero di lavoro non è pulito.
- **Cronologia del file…** è la stessa finestra per un singolo file.
- **Blame (elenco)…** mostra ogni riga con il suo commit, autore e data. **Blame nell’editor** mette la
  stessa informazione nel margine dell’editor, accanto ai numeri di riga: passa su una riga per il messaggio
  del commit, fai clic per aprirlo contro il suo predecessore.
- **Apri sul web** apre il file, il commit o il branch su GitHub, GitLab, Bitbucket o Azure DevOps, costruito
  dall’URL del remoto — nessun account, nessun token. Per un host di cui non conosce la forma dei link,
  propone la pagina del repository anziché tirare a indovinare.

## Branch, stash e tag

**Branch, stash e tag…** elenca tutti e tre. Cambiare branch, crearne uno, farne il merge o eliminarlo;
pushare, poppare o scartare uno stash; creare, eliminare o pushare un tag, oppure passarci sopra — un tag non
è un branch, quindi viene detto in partenza che HEAD resterà staccato. Fetch, Pull e Push sono nella stessa
finestra e si possono annullare mentre girano.

Pushare un tag è un’azione a sé per scelta: `git push` non porta con sé i tag.

## Conflitti

**Risolvi conflitto…** elenca le regioni in conflitto del file sotto il cursore e prende una decisione per
ciascuna: *le nostre*, *le loro*, *entrambe*, o lasciarla aperta. Poi **Scrivi file** oppure **Scrivi e
prepara**. Rifiuta di preparare finché una regione resta aperta — Git committerebbe volentieri dei marcatori
`<<<<<<<` — e rifiuta di toccare un file di cui non sa leggere i marcatori anziché indovinarli. Per una
regione che va intrecciata a mano da entrambi i lati, **Apri nell’editor** è a un pulsante di distanza.

## Rebase

**Rebase…** elenca i commit avanti rispetto all’upstream — quelli che nessun altro ha ancora — e ti lascia
fare squash, fixup, scartarli, riordinarli o riscriverne il messaggio prima di riscrivere il branch. Se un
rebase si ferma su un conflitto, la stessa finestra diventa **Continua** / **Salta commit** / **Annulla
rebase**, così un rebase lasciato a metà non deve essere finito in un terminale.

## Ignorare file, e le credenziali

- **Ignora questo file…**, **Ignora questo tipo di file…** e **Ignora questa cartella…** aggiungono il
  modello giusto a `.gitignore` — ancorato dove serve, così che ignorare *questa* cartella `build` non
  ignori ogni cartella chiamata `build`.
- **Credenziali…** riferisce come si autentica questo repository: SSH o HTTPS, se è configurato un credential
  helper, se un agente SSH è in esecuzione e tiene una chiave. Dove è utile, offre una sola azione: lasciare
  che Git conservi le credenziali nel portachiavi di macOS. Il plugin non chiede mai una passphrase, non la
  mostra e non la conserva.

## Note

- Il plugin usa il Git di sistema in `/usr/bin/git`. Se Git non è installato, i comandi segnalano che non è
  disponibile. (Gli Xcode Command Line Tools lo forniscono.)
- Lo stato del repository viene letto una volta per cartella e messo in cache, così scorrere un repository
  grande resta veloce; la cache si aggiorna dopo ogni comando che cambia l’albero, e segue anche un commit
  fatto fuori dall’applicazione.
- I worktree collegati e i sottomoduli sono supportati: un file dentro un sottomodulo mostra lo stato e il
  branch *del sottomodulo*, non quelli del repository padre.
- Ogni elenco ha un menu contestuale, **Invio** esegue l’azione principale e **Cmd+R** ricarica la finestra.
