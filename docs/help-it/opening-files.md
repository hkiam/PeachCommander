---
title: Apertura di file e cartelle
slug: opening-files
section: File e cartelle
order: 20
related: [viewing-files, selecting-files]
---

Peach Commander apre file e cartelle direttamente da entrambi i pannelli, usando le stesse app e funzioni di sistema su cui fai già affidamento nel Finder. Premi un tasto per aprire l'elemento sotto il cursore nella sua app predefinita, o fai clic destro per raggiungere un menu completo di azioni — apri con un'altra app, mostra l'elemento nel Finder, condividilo o apri una finestra del Terminale proprio dove ti trovi.

## Apri un elemento

1. Fai clic su un file o una cartella in un pannello per posizionarvi il cursore (la riga evidenziata).
2. Premi Invio (o fai doppio clic).
   - Una cartella si apre nello stesso pannello.
   - Un file si apre nella sua app macOS predefinita — la stessa app che userebbe il Finder.
   - Un archivio (come un .zip) si apre come una cartella, così puoi sfogliarne il contenuto.

![La finestra principale di Peach Commander con entrambi i pannelli che mostrano file e cartelle](screenshots/main-window.png)
*(Figura: posiziona il cursore su un elemento qualsiasi, poi premi Invio per aprirlo.)*

## Apri con un'altra app, mostra o condividi

Fai clic destro su un file (o premi Maiusc+F10) per aprire il menu dell'elemento, poi scegli:

- **Apri** o **Apri nell'app predefinita** — apri il file come farebbe Invio.
- **Apri con** — scegli qualsiasi app installata in grado di aprire questo file, o scegli **Altro…** per cercarne una.
- **Quick Look** — anteprima del file senza aprire un'app.
- **Mostra nel Finder** — mostra il file selezionato in una finestra del Finder.
- **Condividi…** — invia il file tramite il foglio di condivisione di macOS.

Il menu integra anche i **Servizi** standard di macOS per il file selezionato e aggiunge **Tag**, così puoi applicare i soliti tag colore del Finder.

## Apri un terminale nella cartella corrente

Scegli **Apri Terminale qui** dal menu File o Comandi (Cmd+Opzione+T) per aprire una finestra del Terminale già puntata sulla cartella del pannello attivo.

## Scorciatoie

| Azione | Tasto |
|---|---|
| Apri elemento sotto il cursore | Invio |
| Visualizza file (visualizzatore) | F3 |
| Modifica file | F4 |
| Anteprima Quick Look | Cmd+Y |
| Ottieni informazioni / proprietà | Opzione+Invio |
| Apri menu dell'elemento | Maiusc+F10 o clic destro |
| Apri Terminale qui | Cmd+Opzione+T |

## Note

- "App predefinita" indica l'app che macOS è impostato a usare per quel tipo di file; cambiala nel pannello Ottieni informazioni del file, esattamente come nel Finder.
- **Mostra nel Finder**, **Condividi…** e **Apri con ▸ Altro…** si applicano agli elementi sul disco del tuo Mac. Non sono disponibili per elementi dentro un archivio o su una connessione remota (FTP/SFTP).
- Il clic destro su un processo in esecuzione (in una vista dei processi) mostra un menu più breve, specifico del processo, invece delle azioni sui file.
