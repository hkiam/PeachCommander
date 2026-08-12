---
title: Task Manager
slug: task-manager
section: Plugin
order: 125
related: [plugins, viewing-files, deleting-files]
---

Il plugin Task Manager trasforma i processi in esecuzione sul vostro Mac in una cartella che potete sfogliare. Compare come un'unità **TaskManager** nella barra dei dischi; apritela e ogni processo è una riga che potete ordinare, esaminare come un file o terminare — usando gli stessi tasti che già usate per i file. Trattandosi di un plugin, potete disattivarlo o rimuoverlo da **Configurazione ▸ Plugin…**.

## Aprirlo

1. Fate clic sulla voce **📊 TaskManager** nella barra dei dischi (si trova subito dopo il vostro disco di avvio).
2. Il pannello si riempie con una riga per ogni processo in esecuzione. Il nome di ciascuna riga è il nome del processo seguito dal suo PID, per esempio `Finder (462)`.
3. Il pulsante **TaskManager** resta selezionato finché siete dentro e la scheda prende il nome del disco. Passate a un'altra scheda e tornate indietro — oppure chiudete e riaprite l'app — e la scheda torna all'elenco dei processi. Per uscirne, salite di un livello o fate clic su un altro volume nella barra dei dischi.

![Task Manager che elenca i processi in esecuzione con le colonne PID, CPU, memoria e comando](screenshots/task-manager.png)
*(Figura: i processi in esecuzione mostrati come un elenco di file che potete ordinare e su cui potete agire.)*

## Cosa significa ogni colonna

Accanto alla colonna Data (ora di avvio), Task Manager aggiunge colonne di processo. La Dimensione di una riga di processo mostra `DIR`, perché un processo è una cartella che puoi aprire (vedi sotto): la memoria ha colonne proprie:

| Colonna | Significato |
| --- | --- |
| **PID** | Id del processo |
| **CPU %** | Uso recente del processore (serve un secondo aggiornamento perché compaia) |
| **Memory** | Impronta di memoria — ciò di cui questo processo risponde (il numero mostrato da Monitoraggio Attività) |
| **Resident** | Dimensione residente, pagine condivise incluse; compilata per ogni processo |
| **Threads** | Numero di thread |
| **State** | R in esecuzione · S in attesa · T fermato · Z zombie · I inattivo, più i suffissi aggiunti da `ps` (s = leader di sessione, + = primo piano, N = priorità bassa) |
| **User** | Proprietario |
| **PPID** | Id del processo padre |
| **Read** | Byte letti dal disco da quando il processo è partito |
| **Written** | Byte scritti sul disco da quando il processo è partito |
| **Wakeups** | Risvegli da interrupt da quando il processo è partito |
| **Signed** | Chi ha firmato il programma: Apple, un team con Developer ID, ad-hoc o non firmato |
| **Command** | Riga di comando completa |

Ordinate per qualsiasi colonna (per esempio CPU % o Dimensione/memoria) proprio come fareste in una cartella normale.

## Esaminare o terminare un processo

- **Visualizza (F3)** mostra un rapporto *Process Information*: nome, PID, padre, utente, stato, thread, memoria, CPU, ora di avvio, percorso dell'eseguibile e la riga di comando completa.
- **Elimina (F8)** termina il processo. La prima eliminazione invia una **chiusura** garbata (SIGTERM); eliminando una seconda volta un processo ancora in esecuzione si passa a una **chiusura forzata** (SIGKILL). Il plugin non prende mai di mira il PID 1.

## Trovare i processi che usano un file

Fai clic con il tasto destro su una riga qualsiasi e scegli **Trova processi per file…**, poi inserisci il percorso di un file. Ogni processo che ha quel file aperto in quel momento viene evidenziato e il cursore salta al primo che può modificarlo:

- **Blu** — il processo si limita a leggere il file.
- **Arancione** — il processo si limita a scriverci.
- **Viola** — il processo fa entrambe le cose.

Il percorso è precompilato dal cursore dell’altro pannello, così puoi indicare lì un file e porre la domanda senza digitare. **Trova processo per porta…**, nello stesso menu, risponde alla domanda gemella: quale processo è in ascolto su una porta TCP/UDP. Scegli **Rimuovi evidenziazione file** per togliere i colori; anche uscire dall’elenco dei processi li toglie.

## Apri un processo per vedere i suoi file

Premi Invio su un processo — o fai doppio clic — e il pannello elenca i file che quel processo ha aperti in quel momento, come normali righe di file con dimensione e data reali. Da lì:

- **Visualizza (F3)** apre il file stesso.
- **Vai al file** lo mostra nell'altro pannello, dove puoi lavorarci.
- **Mostra nel Finder** lo consegna al Finder.

Contano solo i file aperti: una libreria che il processo ha soltanto mappato in memoria, e la sua directory di lavoro, non sono file aperti. Il processo di un altro utente mostra una cartella vuota.

## Note

- I dati di base (PID, padre, utente, stato, firma) sono leggibili per ogni processo. L'impronta di memoria, i thread, l'I/O su disco e l'elenco dei file aperti sono leggibili per i **tuoi** processi, che su un Mac normale sono la maggior parte dell'elenco. Per i processi di altri utenti, CPU e Resident vengono compilati da `ps` — una media sull'intera vita del processo invece della differenza fra due misure che portano le altre righe — mentre thread e impronta restano vuoti.
- CPU % è una variazione tra due campionamenti, quindi è vuota finché il pannello non si aggiorna una seconda volta (il pannello si aggiorna all'incirca ogni due secondi).
- L'elenco è di sola lettura a parte la terminazione di un processo — non potete copiarvi dentro dei file.
- I colori dell’evidenziazione seguono il tema colori: la palette Norton usa invece verde, rosso e magenta.
- Vengono trovati solo i descrittori che il tuo account può ispezionare, il che in pratica significa i tuoi processi. Una libreria che un processo ha soltanto mappato in memoria, o la sua directory di lavoro, non è un descrittore aperto e non viene segnalata.
- La colonna **Signed** si riempie nei primi secondi: leggere una firma richiede circa un millisecondo e i programmi distinti sono centinaia, quindi ne vengono letti alcuni per aggiornamento e poi ricordati. Una cella vuota significa «non ancora letta», non «non firmato».
- **Signed** dice chi ha firmato il programma, non se è autenticato: verificare l'autenticazione significa calcolare l'hash dell'intero programma, e servirebbero secondi per ciascuno.
- Qui il filtro rapido (Ctrl+S) corrisponde anche alle colonne e non solo al nome, e un termine può nominare la colonna a cui si applica: `user:root state:R` chiede che cosa sta eseguendo root in questo momento. I termini sono separati da spazi e devono corrispondere tutti; il testo che non nomina alcuna colonna resta un'unica sottostringa, spazi inclusi.
