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

![Task Manager che elenca i processi in esecuzione con le colonne PID, CPU, memoria e comando](screenshots/task-manager.png)
*(Figura: i processi in esecuzione mostrati come un elenco di file che potete ordinare e su cui potete agire.)*

## Cosa significa ogni colonna

Accanto alle solite colonne Dimensione (memoria) e Data (ora di avvio), Task Manager aggiunge colonne di processo:

| Colonna | Significato |
| --- | --- |
| **PID** | Id del processo |
| **CPU %** | Uso recente del processore (serve un secondo aggiornamento perché compaia) |
| **Threads** | Numero di thread |
| **State** | R in esecuzione · S in attesa · T fermato · Z zombie · I inattivo |
| **User** | Proprietario |
| **PPID** | Id del processo padre |
| **Command** | Riga di comando completa |

Ordinate per qualsiasi colonna (per esempio CPU % o Dimensione/memoria) proprio come fareste in una cartella normale.

## Esaminare o terminare un processo

- **Visualizza (F3)** mostra un rapporto *Process Information*: nome, PID, padre, utente, stato, thread, memoria, CPU, ora di avvio, percorso dell'eseguibile e la riga di comando completa.
- **Elimina (F8)** termina il processo. La prima eliminazione invia una **chiusura** garbata (SIGTERM); eliminando una seconda volta un processo ancora in esecuzione si passa a una **chiusura forzata** (SIGKILL). Il plugin non prende mai di mira il PID 1.

## Note

- I dettagli di base (PID, padre, utente, stato) sono leggibili per ogni processo, come `ps`. Memoria, thread e CPU possono essere letti solo per i **vostri** processi; gli altri processi mostrano quelle colonne vuote (richiedono privilegi elevati, un'aggiunta successiva).
- CPU % è una variazione tra due campionamenti, quindi è vuota finché il pannello non si aggiorna una seconda volta (il pannello si aggiorna all'incirca ogni due secondi).
- L'elenco è di sola lettura a parte la terminazione di un processo — non potete copiarvi dentro dei file.
