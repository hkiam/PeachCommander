---
title: Il terminale integrato
slug: terminal
section: Plugin
order: 127
related: [plugins, opening-files, macos-integration, keyboard-shortcuts]
---

Peach Commander può eseguire una shell vera dentro la propria finestra, in una striscia in basso chiamata dock. È la vostra shell di login — quella indicata da `$SHELL`, oppure `/bin/zsh` se non è utilizzabile — quindi il vostro `PATH`, i vostri alias e le vostre funzioni ci sono tutti, esattamente come nel Terminale.

Non è la stessa cosa di **Apri Terminale qui**, che avvia l’app Terminale di Apple nella cartella corrente e vi lascia con due finestre. Quello integrato resta dove sono i vostri file, e li conosce.

È un plugin: se non lo volete, disattivatelo o rimuovetelo in **Configurazione ▸ Plugin…**, e il dock se ne va con lui.

## Aprirlo e spostarsi

Premete **Ctrl** insieme al tasto a sinistra dell’«1» per spostare la tastiera fra il pannello dei file e il terminale. Quella scorciatoia è legata alla *posizione* del tasto, non al suo carattere: è quindi lo stesso tasto fisico comunque lo chiami la vostra disposizione: l’accento grave su una tastiera US, `^` su una tedesca, `@` su una francese.

Tutto il resto è nel menu **Terminale**:

| Azione | Che cosa fa |
| --- | --- |
| Mostra il terminale | Lo richiude e lo riapre; le schede e ciò che vi gira restano come sono |
| Passa dal pannello al terminale | Sposta il fuoco della tastiera, senza cambiare altro |
| Nuova scheda del terminale | Un’altra shell, nella stessa cartella |
| Chiudi la scheda del terminale | La chiude — e chiede prima se qualcosa è ancora in esecuzione |
| Dividi il terminale | Due shell affiancate nella stessa scheda |
| Vai alla cartella del pannello | Porta il terminale con `cd` dove si trova il pannello attivo |
| Inserisci i nomi dei file selezionati | Scrive i nomi selezionati al prompt, fra virgolette |
| Esegui la riga di comando nel terminale | Manda alla shell quello che avete scritto nella riga di comando, invece di eseguirlo invisibilmente |

Finché il terminale ha il fuoco, i **tasti funzione vanno lì**, non al pannello dei file: F5 in un editor di testo dentro il terminale deve raggiungere l’editor. La barra dei tasti funzione lo dice, invece di mostrare tasti che non faranno nulla.

## Il ponte di ritorno al pannello

**Cmd-clic su un percorso** nell’output del terminale e il pannello ci va. Un file da `ls`, un percorso in un errore del compilatore, un nome da `git status`: un clic e lo state guardando.

Agisce solo quando la parola sotto il puntatore corrisponde davvero a qualcosa che esiste. Un Cmd-clic sul testo normale non fa nulla, invece di navigare da qualche parte a caso, e un clic semplice seleziona il testo come ha sempre fatto.

**Trascinate dei file sul terminale** e i loro percorsi arrivano al prompt, fra virgolette, pronti per un comando che state scrivendo a metà.

## Lasciare che il pannello segua la shell

Disattivo per impostazione predefinita: quando fate `cd` nel terminale, il pannello resta dov’è. Attivate **Lascia che il pannello attivo segua il terminale** nella pagina delle impostazioni del terminale e lo seguirà.

Serve l’aiuto della vostra shell, perché una shell non annuncia dove è andata. La pagina delle impostazioni mostra un breve frammento da aggiungere al vostro `~/.zshrc` e un pulsante per copiarlo; fa sì che zsh riporti la sua cartella di lavoro (la sequenza di escape OSC 7) prima di ogni prompt. Senza il frammento l’impostazione è attiva e non segue niente, ed è per questo che il frammento sta lì accanto.

## Ricerca e scorrimento

**Cmd+F** cerca in ciò che il terminale ha stampato.

Un terminale conserva **5.000 righe** di scorrimento all’indietro per impostazione predefinita — abbastanza per ripercorrere una compilazione. Si cambia nella pagina delle impostazioni. I valori molto grandi vengono limitati, perché uno scorrimento di cinquanta milioni di righe è un problema di memoria la cui causa è impossibile da vedere dall’esterno.

## Dove sta

Il terminale si apre nel dock in basso, perché è la forma che gli serve: una shell ha bisogno di larghezza, e il pannello laterale, ai suoi 300 punti predefiniti, contiene circa 44 colonne là dove il fondo di una finestra da 1200 punti ne contiene 176.

Potete comunque spostarlo. Trascinatelo nel pannello laterale se vi va meglio, o usate i controlli di posizionamento descritti in [Plugin](plugins.md); spostarlo **riaggancia la stessa shell** invece di avviarne una nuova, quindi quello che è in esecuzione continua. I comandi del menu **Terminale** lo seguono: lo mostrano dov’è, invece di aprire il dock.

Le schede tornano al riavvio dell’app, nelle cartelle in cui erano. Quello che vi *girava* dentro no: un riavvio termina quei processi, come in qualsiasi terminale. Torna anche il fatto che fosse aperto quando avete chiuso l’app.

## Quando uscite

Chiudere l’app chiude le shell. Quello che vi sta ancora girando viene terminato, come chiudere una finestra del Terminale termina ciò che contiene. Per questo chiudere una scheda con qualcosa in esecuzione chiede prima conferma.
