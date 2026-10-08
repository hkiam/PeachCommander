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
un messaggio e premi **Commit** — con **Amend** per ripiegare la modifica nel commit precedente. **Fetch**, **Pull** e
**Push** stanno lì accanto, dove il commit avviene comunque; tutti e tre mostrano l’avanzamento e si possono
annullare.

Si committa l’*indice*, non `git commit -a`: quello che hai preparato è quello che viene committato.

## Cronologia nel pannello

Sotto i pulsanti il pannello mostra la cronologia di tutti i rami, rami remoti e tag come grafo disegnato, con la copia di lavoro come prima riga. L’area sottostante segue la selezione:

![Il pannello Git con il grafo dei rami, il commit di merge selezionato e il suo file modificato con il diff in linea](screenshots/git-panel.png)

- **Modifiche locali** mostra i file in stage, modificati e non tracciati e la casella di commit descritta sopra.
- Un commit mostra **Commit** — autore, committer, data, hash, genitori, ref, firma e messaggio completo — oppure **Modifiche**.
- **Modifiche** elenca i file toccati come albero e il diff del file scelto con i numeri di riga; un doppio clic apre la finestra di confronto.
- Il menu contestuale copia hash o oggetto, annulla, fa cherry-pick, apre il commit sul web e limita l’elenco a **Solo il ramo corrente**.
- Dallo stesso menu un commit può essere estratto, ricevere un nuovo ramo o tag, essere unito al ramo corrente, fare da base per il rebase o il ripristino del ramo corrente, o avviare un rebase interattivo.
- Il campo di ricerca sopra l’elenco cerca in tutta la cronologia — messaggio, nome ed e-mail dell’autore, o un hash e i suoi primi caratteri — ed elenca i risultati senza il grafo.

## Altro nel pannello e nel menu Git

La copia di lavoro, la cronologia e il menu **Comandi ▸ Git** offrono più del solo commit:

- Un file in stage o modificato selezionato mostra il suo diff sotto l’elenco; righe selezionate o un intero blocco si mettono in stage, si tolgono dallo stage o si scartano dal suo menu contestuale.
- Il campo del commit accetta più righe — un oggetto, una riga vuota, un testo —, esegue il commit con **Cmd+Invio** e conta i caratteri dell’oggetto; il pulsante menu accanto conserva i tuoi ultimi messaggi di commit.
- **Mostra nel pannello sinistro** e **Mostra nel pannello destro** portano un pannello file su un file dell’elenco o delle modifiche di un commit, mentre il pannello Git resta com’è; i file memorizzati da Git LFS sono contrassegnati **LFS**.
- Gli stash compaiono nella cronologia come piccoli quadrati sopra il commit su cui sono stati creati, con **Applica stash**, **Applica e rimuovi stash** ed **Elimina stash…** nel menu contestuale.
- **Reflog…** elenca ogni spostamento di HEAD; un commit perso con un reset o un ramo eliminato torna con **Nuovo ramo qui…**.
- **Impostazioni del repository…** aggiunge, rinomina, reindirizza e rimuove remoti, aggiunge, aggiorna e rimuove sottomoduli, gestisce i worktree e dà solo a questo repository un nome e un’e-mail per i commit.
- **Crea repository qui…** e **Clona repository…** lavorano nella cartella del pannello attivo, e l’orologio accanto al titolo del pannello riporta a un repository recente.

## Quando git si ferma, e le impostazioni

- **Push** imposta l’upstream al primo push di un ramo. Se il remoto ha commit che mancano a questo ramo, offre **Pull, poi push** o **Push forzato**, sempre con un lease che rifiuta se qualcuno ha fatto push dal tuo ultimo fetch; **Push forzato (con lease)…** è anche nel menu contestuale di **Push**.
- Se **Pull** trova che il ramo e il suo upstream si sono separati, chiede se fare merge o rebase invece di fermarsi sul messaggio di git.
- Un merge, un cherry-pick, un revert, un rebase o una serie di patch che si ferma su un conflitto mostra sopra la cronologia un banner con **Continua** e **Interrompi…**; un commit di merge viene annullato o applicato rispetto al suo primo genitore.
- Seleziona due commit per confrontarli, o più commit per applicarli in un colpo con cherry-pick. **Confronta con la copia di lavoro** e **Salva come patch…** sono nel menu della cronologia, **Applica patch…** nel menu Git.
- Il campo di ricerca accetta anche filtri — `author:name`, `path:folder/`, `since:"2 weeks ago"`, `until:2026-10-01` — da soli o insieme a parole.
- **Bisect: segna come cattivo** e **Bisect: segna come buono** nel menu della cronologia avviano un bisect; il banner offre poi **Buono**, **Cattivo**, **Salta** e **Termina bisect** finché git non indica il primo commit cattivo.
- Mettere nello stash file scelti o tutte le modifiche chiede un messaggio e se includere i file non tracciati o mantenere l’indice. I file in Git LFS si possono bloccare e sbloccare, e tracciarne il tipo di file.
- Nell’elenco dei rami un ramo si può rinominare (**Rinomina…**), collegare a un upstream (**Imposta upstream…**) o eliminare sul suo server (**Elimina sul remoto…**).
- **Impostazioni ▸ Git** stabilisce il programma git, il tuo nome e la tua e-mail globali, come lavora **Pull**, il fetch in background, cosa mostra la cronologia e come appaiono le sue date, firma, sign-off e hook dei commit, e spazi e righe di contesto dei diff. Gli autori portano iniziali colorate nella cronologia.

## File, merge, Git flow e pull request

- **File**, accanto a Commit e Modifiche, mostra l’intero albero al commit selezionato; un file si apre con i numeri di riga, e il suo menu lo confronta con la copia di lavoro, lo salva altrove o lo rimette nella copia di lavoro (**Ripristina questa versione…**).
- **Editor di merge…** — su un file in conflitto nel pannello, nel banner, in **Risolvi conflitto…** e nel menu Git — mostra il conflitto corrente come nostra, base e loro affiancate e sotto l’intero file, modificabile. **Prendi il nostro**, **Prendi il loro**, entrambi in un ordine o nell’altro o **Prendi la base** decidono un conflitto, e **Salva e prepara** segna il file come risolto quando non restano marcatori.
- Il simbolo del ramo nell’intestazione del pannello è il menu **Git flow**: **Inizia funzionalità…**, **Inizia release…** e **Inizia hotfix…** creano il ramo da develop o main, e **Concludi …** lo riunisce — una release o un hotfix in main con un tag, poi in develop. Concludere di nuovo dopo un conflitto riprende da dove si era fermato.
- **Pull request…** nel menu Git elenca le pull request aperte (merge request su GitLab) e le issue del progetto a cui puntano i remoti, con i controlli di ciascuna; estrae una pull request in un ramo proprio e ne apre una nuova per il ramo corrente.
- Serve un token di accesso personale, inserito in quella finestra e conservato nel portachiavi; il token viene inviato solo all’API del servizio. Con un token, un simbolo accanto al ramo nell’intestazione del pannello mostra se la CI è passata per il commit corrente.
- **Impostazioni ▸ Git** dà i nomi ai rami e ai prefissi di Git flow e, in **Hosting**, ai server GitLab o GitHub Enterprise self-hosted.

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

## Cambiare i messaggi di commit in seguito

- **Modifica messaggio…** nel menu della cronologia apre il messaggio di un commit per modificarlo; con più commit selezionati diventa **Modifica messaggi…**, e **Trova e sostituisci nei messaggi…** — anche **Modifica messaggi di commit…** nel menu Git — cerca nei messaggi del ramo attuale, dei commit non ancora inviati o di tutti i rami e i tag.
- L’elenco mostra i commit il cui messaggio cambia. Il messaggio di quello selezionato appare com’è, con le corrispondenze evidenziate, e come sarà, e lì si può anche scrivere; **Lascia com’è** toglie di nuovo un commit.
- **Trova segreti…** cerca token, chiavi e password nei messaggi elencati e li inserisce nella ricerca; **Oscura** mette `***REDACTED***` come sostituzione.
- **Applica…** chiede prima: elenca ogni modifica, quanti commit ricevono nuovi hash e quali rami e tag vengono spostati, e avvisa dei commit già inviati. I commit vengono scritti direttamente, quindi non viene fatto alcun checkout e nulla può andare in conflitto; file, autori e date restano come erano. Una firma viene rimossa, o rifatta se **Firma i commit** è attivo in **Impostazioni ▸ Git**.
- I vecchi commit vengono conservati: **Ripristina** riporta indietro i rami finché nessuno di essi si è spostato da allora. Un ramo già inviato viene sostituito sul suo remoto con **Push forzato…**, con lease.
- Per un segreto, **Rimuovi vecchi commit…** elimina il backup e le voci del reflog che nulla raggiunge più, esegue il prune e poi dice se c’è ancora un vecchio commit. I commit inviati possono essere ancora raggiungibili sul server e in altri cloni, quindi un segreto inviato deve anche essere revocato.

## Ignorare file, e le credenziali

- **Ignora questo file…**, **Ignora questo tipo di file…** e **Ignora questa cartella…** aggiungono il
  modello giusto a `.gitignore` — ancorato dove serve, così che ignorare *questa* cartella `build` non
  ignori ogni cartella chiamata `build`.
- **Credenziali…** riferisce come si autentica questo repository: SSH o HTTPS, se è configurato un credential
  helper, se un agente SSH è in esecuzione e tiene una chiave. Dove è utile, offre una sola azione: lasciare
  che Git conservi le credenziali nel portachiavi di macOS. Il plugin non chiede mai una passphrase, non la
  mostra e non la conserva.

## Note

- Il plugin usa il Git di sistema in `/usr/bin/git`, o il programma scelto in **Impostazioni ▸ Git**. Se Git non è installato, i comandi segnalano che non è disponibile. (Gli strumenti da riga di comando di Xcode lo forniscono.)
- Lo stato del repository viene letto una volta per cartella e messo in cache, così scorrere un repository
  grande resta veloce; la cache si aggiorna dopo ogni comando che cambia l’albero, e segue anche un commit
  fatto fuori dall’applicazione.
- I worktree collegati e i sottomoduli sono supportati: un file dentro un sottomodulo mostra lo stato e il
  branch *del sottomodulo*, non quelli del repository padre.
- Ogni elenco ha un menu contestuale, **Invio** esegue l’azione principale e **Cmd+R** ricarica la finestra.
- Git LFS, `gpg` per i commit firmati e gli helper delle credenziali vengono trovati nelle cartelle di Homebrew e MacPorts anche se l’app è stata aperta dal Finder.
