---
title: Plugin
slug: plugins
section: Plugin
order: 120
related: [disk-map, ai-assistant, git, system-monitor, task-manager, uninstaller, filesystem-images, archives, ftp-and-sftp]
---

I plugin estendono Peach Commander con strumenti, formati di file e luoghi da sfogliare aggiuntivi. Una dozzina di plugin sono integrati, così puoi iniziare a usarli subito, e puoi attivare o disattivare singoli plugin — o installarne di nuovi — da un'unica finestra. Usa i plugin quando vuoi capacità oltre la copia e la navigazione quotidiane: visualizzare cosa riempie un disco, connetterti a un server WebDAV, controllare lo stato di un repository Git, osservare l'attività del sistema e altro.

I plugin si presentano in alcune varianti: alcuni aggiungono un **pannello o una barra laterale** (una vista), alcuni aggiungono **colonne** all'elenco dei file, alcuni aggiungono un **luogo in cui navigare** come un'unità, e alcuni insegnano all'app un nuovo **formato di archivio**. Ciascuno viene abilitato in modo indipendente.

## Cosa aggiungono i plugin integrati

Diversi plugin hanno un proprio argomento della guida dettagliato — segui il link per la storia completa:

- **[Disk Map](disk-map.md)** — visualizza cosa riempie una cartella o un volume come mappa ad albero o a raggiera, riconciliato con lo spazio libero, eliminabile e nascosto, con un raccoglitore per la pulizia.
- **[Assistente IA](ai-assistant.md)** — un assistente opzionale e rimovibile che riassume, rinomina, traduce, tabella e organizza i file in linguaggio naturale, sul dispositivo o tramite un modello cloud.
- **[Git](git.md)** — mostra lo stato dell'albero di lavoro di ciascun file e il ramo corrente come colonne del pannello, e aggiunge un menu **Git** per status, stage, commit, pull e push.
- **[System Monitor](system-monitor.md)** — una lettura in tempo reale di processore, memoria, disco, rete (e, dove disponibili, GPU, batteria, sensori) nella barra del titolo della finestra, con grafici di dettaglio raggiungibili con un clic.
- **[Task Manager](task-manager.md)** — monta i tuoi processi in esecuzione come un'unità **TaskManager** sfogliabile; ordinali, esaminali come file o terminali con Elimina.
- **[Immagini di file system](filesystem-images.md)** — apre un'immagine di file system (SquashFS, ext, Btrfs, JFFS2, UBIFS, cramfs, initramfs, FAT, exFAT, NTFS) come un archivio, comprese le immagini disco con più partizioni. Sola lettura, e disattivato finché non lo attivate.
- **[Uninstaller](uninstaller.md)** — rimuove un'applicazione **e** i file di supporto, le cache e le preferenze che lascia dietro di sé, dopo averti mostrato esattamente cosa verrà rimosso.

I restanti plugin integrati sono più piccoli e non necessitano di una pagina propria:

- **Amazon S3** — connettiti ad Amazon S3 o a storage compatibili con S3 (**Rete ▸ Connetti ad Amazon S3…**) ed esplora i bucket come cartelle, con lettura, scrittura, rinomina ed eliminazione. Le chiavi segrete sono conservate nel Portachiavi di macOS.
- **WebDAV** — connettiti a un server WebDAV (**Rete ▸ Connetti a WebDAV…**) e sfoglia, carica, scarica, rinomina ed elimina su di esso come se fosse una cartella. Le password sono conservate nel Portachiavi di macOS.
- **iCloud Drive** — aggiunge una voce *iCloud Drive* alla barra dei dischi che salta direttamente alla tua cartella locale iCloud Drive. Compare solo quando iCloud Drive è configurato sul tuo Mac.
- **Notes** — tieni una nota accanto a qualsiasi file o cartella. Un piccolo badge **●** contrassegna gli elementi che ne hanno una; modifica le note in una barra laterale **Notes** agganciata o in un editor di testo formattato completo (**Comandi ▸ Modifica nota…**), e sfogliale tutte con **Panoramica note…**.
- **Log Viewer** — apri un file come un log colorato, classificato per livello e seguito in tempo reale (**File ▸ Visualizza come log…**), con filtri per livello, ricerca e supporto per i formati di log comuni oltre ai tuoi formati regex personalizzati. Gestisce log di più gigabyte all'istante.
- **Markdown and HTML** — premi F3 su un file `.md` o `.html` e leggilo formattato invece che come sorgente, con i diagrammi ` ```mermaid ` disegnati e la matematica `$…$` composta sul tuo Mac. Non viene scaricato nulla e nessuna parte del documento viene inviata da nessuna parte.
- **CSV Lister** — premete F3 su un file `.csv` o `.tsv` e si apre come una vera tabella con colonne ordinabili invece che come testo grezzo. Il separatore viene rilevato automaticamente, quindi anche le esportazioni separate da punto e virgola si allineano, e la ricerca del visualizzatore trova i valori cella per cella.
- **AI Column** — aggiunge una colonna *AI Language* che rileva la lingua dominante di ogni file di testo sul dispositivo (usando il framework NaturalLanguage di Apple — non un modello cloud).
- **Formati di archivio** — insegnano all'app a sfogliare ed estrarre altri tipi di archivio (7z, la famiglia tar, gzip/bzip2/xz/zstd e RAR dove è installato uno strumento ausiliario), che poi si aprono come cartelle.

## Attiva o disattiva i plugin

1. Scegli Configurazione ▸ Plugin… per aprire la finestra dei plugin.
2. Ogni plugin installato compare nell'elenco con nome, tipo e una casella "Abilitato".
3. Seleziona o deseleziona la casella per abilitare o disabilitare un plugin. Le modifiche hanno effetto subito — i plugin abilitati aggiungono i loro menu, colonne e funzioni; quelli disabilitati restano da parte.

![La finestra dei plugin che elenca i plugin installati con caselle di selezione e i pulsanti Installa e Rimuovi](screenshots/plugins-window.png)
*(Figura: la finestra dei plugin, dove abiliti, disabiliti, installi o rimuovi i plugin.)*

## Installare un nuovo plugin

Un plugin scaricato arriva come **pacchetto di plugin**: un file con estensione `.pcplug`. Ci sono quattro modi per installarlo, e tutti finiscono alla stessa conferma:

- **Fai doppio clic** nel Finder. Peach Commander si apre e chiede.
- **Premi Invio** su di esso in un pannello. Peach Commander è un gestore di file: di solito il file è già lì.
- **Trascinalo sulla finestra dei plugin** (Configurazione ▸ Plugin…).
- Scegli **Configurazione ▸ Plugin… ▸ Installa…** e seleziona il pacchetto, un `.zip` che contiene un plugin, oppure un bundle di plugin già estratto.

Prima che venga caricato qualsiasi cosa, una finestra indica nome, versione, identificatore e tipo del plugin, e quali tipi di file prenderà in carico: un plugin che rivendica `.iso`, per esempio, diventa il lettore dell'app per quei file. Non viene installato nulla finché non fai clic su **Installa**.

Se è già installato un plugin con lo stesso identificatore, la finestra lo dice e mostra entrambe le versioni: un aggiornamento si legge come tale («1.0.0 → 1.1.0») e un passo indietro viene segnalato.

## Prima di installarne uno

Un plugin è un programma che gira dentro Peach Commander, con lo stesso accesso ai tuoi file che ha Peach Commander. Non c'è alcuna sandbox intorno. Installa plugin solo da fonti di cui ti fidi, come faresti con qualsiasi altra applicazione.

I plugin scaricati da Internet arrivano in quarantena da macOS. Installarne uno dice a macOS di consentirne il caricamento — per questo la finestra di conferma lo dice, e per questo è una decisione che prendi tu e non qualcosa che avviene in silenzio.

## Rimuovere un plugin

1. Nella finestra dei plugin, seleziona il plugin nell'elenco.
2. Fai clic su **Rimuovi**. Le funzioni integrate non vengono toccate; viene rimosso solo il plugin selezionato.

Un plugin fornito con l'app non può essere cancellato: «Rimuovi» lo disattiva.

## Note

- L'elenco mostra versione, tipo e versione dell'interfaccia di ogni plugin accanto al nome e al percorso, così puoi verificare che cosa è installato.
- Se un plugin richiede una versione di Peach Commander più recente della tua, viene rifiutato con un messaggio che lo dice, invece di fallire in modo incomprensibile. Vale anche il contrario: un plugin creato per un'interfaccia più vecchia continua a funzionare finché quell'interfaccia è supportata.
- Alcuni plugin aggiungono colonne, voci di menu o luoghi nel pannello solo mentre sono attivi. Se manca una funzione che ti aspettavi, controlla qui che il suo plugin sia acceso.
- Scrivere o pubblicare un proprio plugin è trattato nella documentazione per sviluppatori, non qui.
