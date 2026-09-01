---
title: Anteprima di file che non sono su questo Mac
slug: remote-previews
section: Visualizzazione e modifica
order: 71
related: [viewing-files, archives, network-shares]
---

Peach Commander mostra un'anteprima del file sotto il cursore nel pannello laterale delle informazioni, in Quick View e come miniature nella vista galleria. Quando quel file non è su un disco collegato a questo Mac, mostrarlo costa qualcosa di reale — un download, un'estrazione o entrambi — e nessuno l'ha chiesto: il cursore si è semplicemente spostato sul file. Perciò Peach Commander decide in anticipo quanto può costare un'anteprima; questa pagina spiega cosa decide e come cambiarlo.

## File dentro un archivio

Un file dentro un archivio si può visualizzare in anteprima esattamente come uno fuori. Peach Commander lo estrae in background in una copia temporanea e mostra quella. Lo stesso vale per Quick Look, per l'apertura in un'altra applicazione con Invio o doppio clic e per il sottomenu Apri con.

Quello che riceve l'altra applicazione è una copia, ed è di sola lettura: ciò che vi modificate non viene riscritto nell'archivio. Peach Commander lo dice la prima volta, con una casella per non dirlo più. Per modificare un file che vive in un archivio, estraetelo prima con F5 e lavorate sul file estratto.

## Quanto può costare un'anteprima

Un'anteprima segue il cursore, quindi avviene senza essere richiesta. È perciò soggetta a un budget che dipende da dove si trova davvero il contenuto del file:

- Su un disco collegato a questo Mac non c'è alcun limite, e le anteprime si comportano esattamente come sempre.
- In una posizione di rete — una condivisione montata, FTP, SFTP, Amazon S3 o un volume di plugin — i file vengono mostrati fino a 4 MB, finché Peach Commander non ha misurato quanto è veloce davvero quella connessione. Dopodiché consente tutto ciò che riesce a leggere in circa un secondo e mezzo, così una condivisione veloce mostra file grandi e una lenta ne rifiuta di piccoli.
- Dentro un archivio, un file viene estratto per l'anteprima fino a 32 MB.
- Un file che un servizio cloud non ha ancora scaricato su questo Mac non viene mai recuperato solo perché il cursore vi si è posato sopra.
- Nei formati di archivio che vanno estratti un file alla volta — CPIO, ISO, CAB, LZH e simili — non viene mostrato nulla automaticamente, perché ogni singolo file costa un passaggio completo sull'archivio.

Un'anteprima rifiutata non è un pannello vuoto: la barra laterale mostra l'icona del file, il nome, la dimensione e la data, più una riga che spiega il perché. Quick Look lo mostra comunque e non è soggetto a nessuno di questi limiti.

## Cambiare i limiti

1. Aprite Impostazioni ▸ Modifica/Visualizza.
2. Disattivate “Mostra automaticamente l’anteprima dei file nelle posizioni di rete” per fermare del tutto le anteprime in rete, oppure impostate “File di rete fino a (MB)” sulla dimensione che volete.
3. Attivate “Scarica i file dal cloud per l’anteprima” se preferite l'anteprima al traffico risparmiato.
4. Impostate “Estrai dagli archivi fino a (MB)” per quanto grande può essere un file dentro un archivio.

Altre due impostazioni non hanno un comando proprio e stanno in `peachcmd.ini` sotto `[Preview]`: `AutoPreviewSeconds` è il budget di tempo che vale una volta misurata la connessione (1,5 per impostazione predefinita; 0 lo disattiva) e `AutoPreviewLocalMB` è un tetto per i dischi locali (0 significa nessun limite).

## Dove finiscono le copie estratte

Le copie vengono scritte nella cartella temporanea del sistema e le anteprime le condividono invece di crearne una ciascuna. Una copia fatta per un'anteprima viene rimossa quando uscite dall'archivio; una copia consegnata a un'altra applicazione resta finché non chiudete Peach Commander, perché quell'applicazione la tiene ancora aperta. Ciò che una chiusura inattesa lascia indietro viene riconosciuto al lancio successivo e rimosso allora.

Le miniature nella vista galleria seguono lo stesso budget, e i file dentro un archivio vi conservano la loro icona generica invece di una miniatura.
