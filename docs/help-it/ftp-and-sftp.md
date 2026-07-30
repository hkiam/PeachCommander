---
title: Connessione a FTP e SFTP
slug: ftp-and-sftp
section: Rete e accesso remoto
order: 100
related: [downloading-from-url, network-shares]
---

Peach Commander può sfogliare i server remoti come se fossero cartelle ordinarie. Una volta connesso, un pannello mostra i file remoti e li copi, sposti, rinomini ed elimini con gli stessi tasti che usi in locale. Parla FTP semplice, FTPS sicuro e SFTP/SCP su SSH, così puoi raggiungere di tutto, da un classico host web a un server SSH irrobustito. Le connessioni salvate vivono nel gestore delle connessioni, e le password sono conservate in modo sicuro nel tuo portachiavi macOS invece che nella connessione stessa.

## Connettiti a un server

1. Apri il menu **Rete** e scegli **Connessione FTP…** (Ctrl+F) per aprire il gestore delle connessioni.
2. Scegli una connessione salvata dall'elenco e fai clic su **Connetti**, o fai clic su **Nuova** per crearne una. Usa le cartelle nell'elenco per raggruppare le connessioni.
3. Per una connessione veloce una tantum, scegli **Rete > Nuova connessione FTP…** (Ctrl+N) e digita l'indirizzo direttamente.
4. Inserisci la tua password quando richiesta; spunta l'opzione per salvarla e va nel tuo portachiavi per la prossima volta.
5. Quando hai finito, scegli **Rete > Disconnetti FTP** (Ctrl+Maiusc+F).

![Il gestore delle connessioni FTP che mostra l'elenco delle sessioni salvate con i pulsanti Nuova, Modifica ed Elimina](screenshots/ftp-connection-manager.png)
*(Figura: il gestore delle connessioni contiene i tuoi server salvati; usa Nuova, Modifica ed Elimina per gestirli.)*

Quando configuri una connessione puoi scegliere il protocollo (FTP, FTPS con AUTH TLS esplicito, FTPS implicito sulla porta 990, o SFTP/SCP), la modalità passiva o attiva, le cartelle iniziali remota e locale, la codifica del testo e un intervallo keep-alive opzionale per impedire ai server inattivi di disconnetterti. Per SFTP puoi autenticarti con il tuo agente SSH, una password o un file di chiave privata, e puoi scegliere SCP per i trasferimenti. Le chiavi host SSH sconosciute sono considerate attendibili al primo uso; se la chiave di un server noto dovesse cambiare, la connessione viene rifiutata per proteggerti da manomissioni.

## La console FTP

Per vedere esattamente cosa dice il server, apri la console FTP dal menu **Rete**. Mostra un registro in tempo reale del canale di controllo (la tua password è mascherata) e ti permette di digitare comandi FTP grezzi al server.

![La console FTP che mostra il registro del canale di controllo e un campo per i comandi grezzi](screenshots/ftp-console.png)
*(Figura: la console FTP registra ogni scambio e accetta comandi grezzi, il che è comodo per la risoluzione dei problemi.)*

## Scorciatoie

| Azione | Scorciatoia |
| --- | --- |
| Apri il gestore delle connessioni | Ctrl+F |
| Nuova connessione | Ctrl+N |
| Disconnetti | Ctrl+Maiusc+F |
| Cambia modalità di trasferimento | Ctrl+Maiusc+M |

## Note

- I download e gli upload interrotti possono riprendere da dove si erano fermati, invece di ricominciare.
- Per i server FTPS con un certificato autofirmato, attiva l'opzione per accettare un certificato non attendibile nelle impostazioni di quella connessione.
- Un proxy SOCKS5 può essere impostato per connessione per l'FTP semplice. Instradare una connessione FTPS crittografata attraverso un proxy non è supportato.
- Le connessioni FTP esistenti da Total Commander possono essere importate.
- SCP è usato solo per trasferire file; l'elenco, la rinomina e l'eliminazione passano sempre per SFTP.
