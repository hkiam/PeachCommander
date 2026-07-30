---
title: Plugin
slug: plugins
section: Plugin
order: 120
related: [disk-map, ai-assistant, git, system-monitor, task-manager, uninstaller, archives, ftp-and-sftp]
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
- **[Uninstaller](uninstaller.md)** — rimuove un'applicazione **e** i file di supporto, le cache e le preferenze che lascia dietro di sé, dopo averti mostrato esattamente cosa verrà rimosso.

I restanti plugin integrati sono più piccoli e non necessitano di una pagina propria:

- **WebDAV** — connettiti a un server WebDAV (**Rete ▸ Connetti a WebDAV…**) e sfoglia, carica, scarica, rinomina ed elimina su di esso come se fosse una cartella. Le password sono conservate nel Portachiavi di macOS.
- **iCloud Drive** — aggiunge una voce *iCloud Drive* alla barra dei dischi che salta direttamente alla tua cartella locale iCloud Drive. Compare solo quando iCloud Drive è configurato sul tuo Mac.
- **Notes** — tieni una nota accanto a qualsiasi file o cartella. Un piccolo badge **●** contrassegna gli elementi che ne hanno una; modifica le note in una barra laterale **Notes** agganciata o in un editor di testo formattato completo (**Comandi ▸ Modifica nota…**), e sfogliale tutte con **Panoramica note…**.
- **Log Viewer** — apri un file come un log colorato, classificato per livello e seguito in tempo reale (**File ▸ Visualizza come log…**), con filtri per livello, ricerca e supporto per i formati di log comuni oltre ai tuoi formati regex personalizzati. Gestisce log di più gigabyte all'istante.
- **AI Column** — aggiunge una colonna *AI Language* che rileva la lingua dominante di ogni file di testo sul dispositivo (usando il framework NaturalLanguage di Apple — non un modello cloud).
- **Formati di archivio** — insegnano all'app a sfogliare ed estrarre altri tipi di archivio (7z, la famiglia tar, gzip/bzip2/xz/zstd e RAR dove è installato uno strumento ausiliario), che poi si aprono come cartelle.

## Attiva o disattiva i plugin

1. Scegli Configurazione ▸ Plugin… per aprire la finestra dei plugin.
2. Ogni plugin installato compare nell'elenco con nome, tipo e una casella "Abilitato".
3. Seleziona o deseleziona la casella per abilitare o disabilitare un plugin. Le modifiche hanno effetto subito — i plugin abilitati aggiungono i loro menu, colonne e funzioni; quelli disabilitati restano da parte.

![La finestra dei plugin che elenca i plugin installati con caselle di selezione e i pulsanti Installa e Rimuovi](screenshots/plugins-window.png)
*(Figura: la finestra dei plugin, dove abiliti, disabiliti, installi o rimuovi i plugin.)*

## Installa un nuovo plugin

1. Scegli Configurazione ▸ Plugin….
2. Fai clic su **Installa da cartella…**.
3. Scegli un pacchetto di plugin o un `.zip` che ne contiene uno, e conferma. Il plugin viene aggiunto all'elenco e abilitato.

## Rimuovi un plugin

1. Nella finestra dei plugin, seleziona il plugin nell'elenco.
2. Fai clic su **Rimuovi**. Le funzioni integrate non sono interessate; viene rimosso solo il plugin selezionato.

## Note

- L'elenco dei plugin mostra il tipo e la versione dell'interfaccia di ciascun plugin accanto al nome e alla posizione, così puoi confermare cosa è installato.
- Se non è installato alcun plugin, la finestra mostra un breve invito che ti indirizza verso **Installa da cartella…**.
- Alcuni plugin aggiungono le proprie colonne, voci di menu o luoghi del pannello solo mentre sono abilitati. Se una funzione che ti aspettavi manca, controlla che il plugin sia attivato qui.
