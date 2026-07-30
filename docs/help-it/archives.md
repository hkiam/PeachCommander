---
title: Lavorare con gli archivi
slug: archives
section: Archivi
order: 80
related: [copying-files]
---

Peach Commander tratta gli archivi come cartelle. Potete entrare in un archivio ZIP, TAR o in un altro formato supportato, sfogliarne il contenuto e copiare file all'esterno — il tutto senza doverli prima estrarre su disco. Quando volete creare un archivio, il comando Comprimi raccoglie la vostra selezione in un formato ZIP, 7z, TAR o altro, con crittografia opzionale e volumi suddivisi. È comodo per raccogliere file da inviare, ridurre le dimensioni di una cartella per l'archiviazione o dare un'occhiata dentro un download prima di decidere di estrarlo.

## Sfogliare un archivio come una cartella

1. In un pannello, spostate il cursore su un file di archivio (ad esempio un `.zip` o un `.tar.gz`).
2. Premete Enter o Ctrl+PageDown per entrarci, proprio come aprireste una cartella.
3. Navigate il contenuto normalmente. Premete Backspace o Ctrl+PageUp per risalire e uscire dall'archivio.
4. Per estrarre i file, selezionateli e copiateli (F5) nell'altro pannello.

![Navigazione all'interno di un archivio come se fosse una cartella](screenshots/archive-browse.png)
*(Figura: un archivio aperto mostrato come un normale elenco di cartella, con i suoi file pronti per essere copiati fuori.)*

ZIP, TAR e TAR compresso con gzip vengono letti direttamente. Altri formati come CPIO, ISO, CAB, LZH, XAR e PAX vengono letti tramite strumenti di sistema integrati. Gli archivi ZIP crittografati (sia classici sia AES) possono essere aperti quando fornite la password.

## Comprimere i file in un nuovo archivio

1. Selezionate i file e le cartelle da includere nel pannello attivo.
2. Scegliete File ▸ Comprimi… oppure premete Alt+F5. (Per comprimere e poi eliminare gli originali, usate Alt+Shift+F5.)
3. Nella finestra di dialogo, scegliete il formato dell'archivio (ZIP, 7z, TAR, tar.gz, bzip2, xz o RAR), il livello di compressione e dove salvarlo.
4. Facoltativamente attivate la crittografia AES-256 e impostate una password, oppure suddividete l'archivio in volumi di dimensione fissa.
5. Confermate per creare l'archivio.

![La finestra Comprimi che mostra le opzioni di formato, compressione, crittografia e suddivisione](screenshots/pack-dialog.png)
*(Figura: la finestra Comprimi, dove scegliete il formato e impostate le opzioni di crittografia e di volumi suddivisi.)*

## Estrarre o verificare un archivio

1. Mettete l'archivio da estrarre nel pannello attivo e la cartella di destinazione nell'altro pannello.
2. Scegliete File ▸ Estrai… oppure premete Alt+F9, poi confermate la destinazione.
3. Per verificare la presenza di danni in un archivio senza estrarlo, scegliete File ▸ Verifica archivio.

## Modificare uno ZIP sul posto

Potete aggiungere o rimuovere file all'interno di uno ZIP esistente senza estrarlo. Aprite lo ZIP come una cartella, poi copiate file al suo interno o eliminate file come al solito — la modifica viene scritta direttamente nell'archivio.

## Scorciatoie

| Azione | Scorciatoia |
| --- | --- |
| Entrare nell'archivio sotto il cursore | Enter o Ctrl+PageDown |
| Uscire dall'archivio (risalire) | Backspace o Ctrl+PageUp |
| Comprimi | Alt+F5 |
| Comprimi ed elimina gli originali | Alt+Shift+F5 |
| Estrai | Alt+F9 |

## Note

- La compressione in 7z, xz, bzip2 e RAR si basa su strumenti esterni. RAR in particolare richiede l'installazione del programma proprietario RAR; senza di esso, quel formato non è disponibile.
- Modificare uno ZIP sul posto riscrive l'intero archivio, quindi le date di modifica dei file al suo interno non vengono conservate.
- I singoli elementi molto grandi sono limitati a 512 MiB durante l'estrazione. L'estrazione può essere annullata mentre è in corso.
- Gli archivi estremamente grandi (ZIP64) non sono supportati.
