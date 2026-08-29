---
title: Il menu Avvio e i comandi personalizzati
slug: start-menu
section: Personalizzazione
order: 111
related: [toolbar, keyboard-shortcuts, macros]
---

Il menu **Avvio** è il tuo menu personale, situato nella barra dei menu accanto a File, Modifica e agli altri. Contiene comandi che definisci tu stesso, così le azioni a cui ricorri più spesso sono sempre a un clic di distanza. Nella tradizione dei classici gestori di file a due pannelli, ogni voce può eseguire un comando integrato, avviare un programma o un'app esterna, o saltare direttamente a una cartella. Peach Commander viene fornito con il menu Avvio vuoto e pronto perché tu lo riempia.

## Come aggiungere i tuoi comandi

1. Scegli **Avvio > Modifica menu Avvio…**. Peach Commander apre il tuo file dei comandi utente (creandolo con un esempio commentato la prima volta).
2. Aggiungi una sezione per comando. Ogni sezione inizia con un nome tra parentesi quadre, poi alcune chiavi semplici:
   - **cmd** — cosa eseguire: un percorso di programma, un'app, un comando integrato `cm_`, o un altro dei tuoi comandi.
   - **param** — parametri passati a un programma. I segnaposto vengono riempiti quando il comando viene eseguito: `%P` (cartella di origine), `%N` (file corrente), `%T` (cartella dell'altro pannello), `%M` (file dell'altro pannello), `%S` (file selezionati).
   - **path** — la cartella in cui iniziare (predefinita è la cartella corrente).
   - **menu** — il titolo mostrato nel menu Avvio.
   - **key** — una scorciatoia opzionale, per esempio `C+S+B`.
3. Salva il file. Il menu Avvio si aggiorna da solo la volta successiva che Peach Commander diventa attivo, così le tue nuove voci compaiono subito.

## Suggerimenti

- Per aprire la cartella corrente nel Terminale, imposta **cmd** su `open`, **param** su `-a Terminal %P`, e **menu** su `Apri Terminale qui`.
- Punta **cmd** su un comando `cm_` per dare a un'azione integrata la sua voce di menu Avvio e la sua scorciatoia.
- L'ordine nel file è l'ordine nel menu, quindi metti i comandi che usi di più in cima.

## Note

- Puoi anche sostituire l'intera barra dei menu con la tua. Scegli **Configurazione > Modifica file di menu…** per aprire un file di menu inizializzato dal menu integrato corrente, completamente localizzato; modificalo liberamente e le tue modifiche si applicano la volta successiva che l'app viene attivata. Elimina il file per ripristinare la barra dei menu standard.
