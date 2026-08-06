---
title: Attributi e permessi
slug: attributes-and-permissions
section: Strumenti avanzati
order: 96
related: [file-utilities]
---

Peach Commander vi permette di ispezionare e modificare i metadati di basso livello di file e cartelle che il Finder tiene per lo più fuori portata: i permessi POSIX di lettura/scrittura/esecuzione, il proprietario e il gruppo, le date di modifica e di creazione, i flag di macOS come nascosto e bloccato, e gli attributi estesi. Potete anche modificare l'elenco di controllo degli accessi (ACL) di un file per regole granulari per singolo utente o gruppo, creare collegamenti e alias che puntano ad altri elementi e allegare i vostri commenti. Questi strumenti sono rivolti agli utenti esperti che hanno bisogno di un controllo preciso sul comportamento degli elementi e su chi può intervenirvi.

## Modificare gli attributi

1. Selezionate uno o più elementi nel pannello attivo.
2. Scegliete **File > Modifica attributi…**.
3. Impostate ciò che vi serve: attivate le caselle di lettura/scrittura/esecuzione per proprietario, gruppo e tutti (oppure digitate direttamente un valore ottale), cambiate il proprietario o il gruppo, invertite i flag nascosto o bloccato e impostate la data di modifica o di creazione. Usate **Usa data corrente** per l'ora attuale, oppure copiate una data da un altro file.
4. Per applicare la stessa modifica a tutto il contenuto di una cartella, attivate l'opzione ricorsiva e scegliete se agire su file, cartelle o entrambi.
5. Fate clic su OK per eseguire la modifica. Le modifiche ricorsive vengono eseguite come attività in background con una barra di avanzamento.

![La finestra Modifica attributi che mostra la griglia dei permessi, i flag e i campi delle date](screenshots/attributes-dialog.png)
*(Figura: la finestra Modifica attributi. I valori misti in una selezione di più file appaiono come un trattino finché non li impostate.)*

## Modificare un ACL

Per regole che vanno oltre il modello base proprietario/gruppo/tutti, modificate l'elenco di controllo degli accessi dell'elemento.

1. Aprite **File > Modifica attributi…** e aprite da lì l'editor degli ACL.
2. Ogni riga è una regola: l'utente o il gruppo a cui si applica, se consente o nega e quali permessi (lettura, scrittura, eliminazione e così via) concede.
3. Aggiungete, rimuovete o modificate le righe, poi salvate per riscrivere l'elenco nell'elemento.

## Creare collegamenti, alias e commenti

- **File > Crea collegamento simbolico…** crea un collegamento simbolico (symlink) che punta tramite percorso all'elemento sotto il cursore.
- **File > Crea collegamento fisico…** crea un collegamento fisico agli stessi dati del file. I collegamenti fisici funzionano solo per i file sullo stesso volume.
- **File > Crea alias…** crea un alias di macOS che anche il Finder può seguire.
- **File > Modifica commento…** (Ctrl+Z) apre un editor di testo per un commento per singolo file. I commenti possono essere mostrati in una colonna propria e nei suggerimenti di stato.

## Scorciatoie

| Azione | Scorciatoia |
| --- | --- |
| Modifica commento | Ctrl+Z |

## Note

- Cambiare il proprietario o il gruppo di solito richiede privilegi che come utente normale non avete; quando ciò accade la modifica viene segnalata come non riuscita anziché applicata, e le vostre restanti modifiche vengono comunque eseguite.
- I commenti sono archiviati in un file `descript.ion` accanto ai vostri elementi e possono anche essere mantenuti come commenti del Finder, a seconda delle vostre impostazioni. Entrambi vengono letti quando si visualizza un commento. Il formato è quello usato da Total Commander e da diversi altri gestori di file, quindi un commento scritto qui è leggibile là.
- I commenti con **interruzioni di riga** e quelli in **UTF-16** vengono letti e scritti come fa Total Commander: un'interruzione di riga è memorizzata come `\n` seguito dai due byte di marcatura che TC ha fatto registrare, e un file che era UTF-16 resta UTF-16 quando modificate un commento al suo interno. Senza quella marcatura, un `\n` nel commento di qualcuno è due caratteri che ha digitato, e viene lasciato così.
- **Un commento segue il file.** Copiare, spostare o rinominare lo porta con sé: nel `descript.ion` della cartella di destinazione per uno spostamento o una copia, e sul nuovo nome per una rinomina, anche quando annullate la rinomina. L'eccezione è l'aggiunta di un file alla fine di un altro: il file che resta mantiene il proprio commento, perché resta quel file.
- Se il plugin Note è attivo, la sua barra laterale mostra e modifica lo stesso commento sopra il testo della nota, così non ci sono due posti per la stessa cosa.
- Un collegamento simbolico e un alias puntano entrambi a una destinazione, ma un collegamento simbolico memorizza un semplice percorso mentre un alias memorizza un riferimento di macOS che continua a funzionare se la destinazione viene spostata o rinominata. Un collegamento fisico è un secondo nome per gli stessi dati del file, non un puntatore.
