---
title: Limitazioni note
slug: known-limitations
section: Aiuto e risoluzione dei problemi
order: 144
related: [troubleshooting]
---

Peach Commander fa molto, ma alcune funzioni hanno limiti onesti nella versione attuale. Conoscerli in anticipo evita confusione quando qualcosa si comporta in modo inatteso. Questa pagina elenca i vincoli attuali e, dove possibile, una soluzione semplice.

## Archivi

- **Gli archivi divisi (in più parti) non possono essere aperti.** Lo ZIP standard — compreso ZIP64, quindi più di 65.535 elementi o più di 4 GB — come TAR e TAR compresso con gzip si aprono direttamente come cartelle. Un archivio diviso su più file (`.z01`, `.zip.001`) non è supportato: unite prima le parti oppure scompattatelo con lo strumento che lo ha creato.
- **Gli archivi ZIP crittografati** (sia il vecchio ZipCrypto sia WinZip AES) sono supportati per la navigazione, ma ti verrà chiesta la password.
- Altri formati come CPIO, ISO, CAB, LZH, XAR e PAX si aprono tramite uno strumento ausiliario invece del lettore nativo.

## Rete (SFTP / SCP)

- **Via SFTP si possono cambiare permessi e date, il proprietario no.** Il protocollo trasporta proprietario e gruppo solo come numeri e non consente di risolvere un nome utente: un cambio di proprietario viene quindi rifiutato invece di essere indovinato, così come i flag di file di macOS, che dall’altra parte non esistono. Via FTP semplice si possono impostare solo i permessi, con il comando opzionale `SITE CHMOD`; un server che non lo offre lo dice invece di far finta di riuscire.
- Alla prima connessione a un server SFTP ti verrà chiesto di fidarti della sua chiave host. Peach Commander la ricorda in seguito (fiducia al primo uso).

## Aggiornamento delle cartelle

- **Vengono osservate solo le cartelle su questo Mac.** Una cartella su questo Mac si aggiorna da sé appena un altro programma vi aggiunge, modifica o elimina un file. Una posizione remota (FTP o SFTP) e l’interno di un archivio non vengono osservati, perché quei protocolli non offrono alcun modo di essere avvisati: premete F2 o Ctrl+R per rileggerli.

## Altri limiti attuali

- **Alcuni percorsi assoluti molto lunghi** (cartelle profondamente annidate il cui percorso completo è insolitamente lungo) potrebbero non essere gestiti in modo affidabile. Lavorare più vicino alla cima dell'albero delle cartelle evita questo.
- **Questa build di anteprima non è firmata.** Gatekeeper di macOS potrebbe avvisare che l'app proviene da uno sviluppatore non identificato la prima volta che la apri. Fai clic destro sull'app e scegli Apri, poi conferma, per eseguirla. Gli aggiornamenti automatici non sono ancora disponibili in questa build.

## Scorciatoie

| Azione | Scorciatoia |
| --- | --- |
| Aggiorna il pannello attivo | F2 o Ctrl+R |
| Scarica da URL | Cmd+Maiusc+U |

## Note

Queste sono limitazioni della versione attuale e si prevede che miglioreranno nelle versioni successive. Se incontri un comportamento non descritto qui, consulta l'argomento sulla risoluzione dei problemi.
