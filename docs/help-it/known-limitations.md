---
title: Limitazioni note
slug: known-limitations
section: Aiuto e risoluzione dei problemi
order: 144
related: [troubleshooting]
---

Peach Commander fa molto, ma alcune funzioni hanno limiti onesti nella versione attuale. Conoscerli in anticipo evita confusione quando qualcosa si comporta in modo inatteso. Questa pagina elenca i vincoli attuali e, dove possibile, una soluzione semplice.

## Archivi

- **Gli archivi ZIP divisi (in più parti) si aprono, ma devono esserci tutte le parti.** Lo ZIP standard — compreso ZIP64, quindi più di 65.535 elementi o più di 4 GB — come TAR e TAR compresso con gzip si aprono direttamente come cartelle. Anche un archivio diviso su più file si apre: premete Invio sul `.zip` di un insieme `.z01`, `.z02`, … oppure sul `.001` di un insieme `name.zip.001`. Tutte le parti devono trovarsi nella stessa cartella e un insieme a cui ne manca una viene rifiutato invece di essere aperto letto a metà. Gli archivi TAR divisi non sono coperti.
- **Gli archivi ZIP crittografati** (sia il vecchio ZipCrypto sia WinZip AES) sono supportati per la navigazione, ma ti verrà chiesta la password.
- Altri formati come CPIO, ISO, CAB, LZH, XAR e PAX si aprono tramite uno strumento ausiliario invece del lettore nativo.

## Rete (SFTP / SCP)

- **Via SFTP si possono cambiare permessi e date, il proprietario no.** Il protocollo trasporta proprietario e gruppo solo come numeri e non consente di risolvere un nome utente: un cambio di proprietario viene quindi rifiutato invece di essere indovinato, così come i flag di file di macOS, che dall’altra parte non esistono. Via FTP semplice si possono impostare solo i permessi, con il comando opzionale `SITE CHMOD`; un server che non lo offre lo dice invece di far finta di riuscire.
- Alla prima connessione a un server SFTP ti verrà chiesto di fidarti della sua chiave host. Peach Commander la ricorda in seguito (fiducia al primo uso).

## Aggiornamento delle cartelle

- **Vengono osservate solo le cartelle su questo Mac.** Una cartella su questo Mac si aggiorna da sé appena un altro programma vi aggiunge, modifica o elimina un file. Una posizione remota (FTP o SFTP) e l’interno di un archivio non vengono osservati, perché quei protocolli non offrono alcun modo di essere avvisati: premete F2 o Ctrl+R per rileggerli.

## Altri limiti attuali

- **I percorsi molto lunghi funzionano, tranne il Cestino.** macOS rifiuta come argomento di chiamata qualsiasi percorso oltre 1024 byte, e cartelle annidate fino a tanto esistono. Sfogliare, aprire, copiare, spostare, rinominare, creare ed eliminare definitivamente li raggiungono tutti. L’unica eccezione è **spostare nel Cestino**: macOS non offre alcun modo di cestinare un file che non può nominare, quindi lì Canc segnala un errore — Maiusc+Canc (elimina definitivamente) funziona.
- **Questa versione di anteprima non è firmata.** Gatekeeper blocca il primo avvio, e il modo di consentirlo dipende dalla versione di macOS. Su **macOS 15 Sequoia e successivi**: fate doppio clic una volta, chiudete l'avviso, poi andate in **Impostazioni di Sistema ▸ Privacy e sicurezza** e fate clic su **Apri comunque** — Apple ha rimosso la scorciatoia con il clic destro per il software non firmato in macOS 15, quindi il clic destro non aiuta più. Su **macOS 13–14**: fate clic destro sull'app e scegliete Apri, poi confermate. Gli aggiornamenti automatici non sono ancora disponibili in questa versione.

## Scorciatoie

| Azione | Scorciatoia |
| --- | --- |
| Aggiorna il pannello attivo | F2 o Ctrl+R |
| Scarica da URL | Cmd+Maiusc+U |

## Note

Queste sono limitazioni della versione attuale e si prevede che miglioreranno nelle versioni successive. Se incontri un comportamento non descritto qui, consulta l'argomento sulla risoluzione dei problemi.
