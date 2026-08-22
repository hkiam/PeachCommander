---
title: Risoluzione dei problemi
slug: troubleshooting
section: Aiuto e risoluzione dei problemi
order: 140
related: [privacy-and-security, known-limitations]
---

Questo argomento copre i problemi che le persone incontrano più spesso: macOS che blocca l'accesso a certe cartelle, una cartella che sembra bloccata su un contenuto vecchio, un server FTP sicuro che rifiuta di connettersi, e la compressione in RAR. Ogni sezione ti dice cosa sta succedendo e come risolverlo.

## macOS chiede un'autorizzazione, o le cartelle sembrano vuote

Alcune posizioni — come la tua cartella `~/Library`, le cartelle di altri utenti e le aree di sistema — sono protette da macOS e restano nascoste finché non concedi l'accesso. Peach Commander rileva quando questo accade e si offre di guidarti all'impostazione giusta.

Una cartella così viene rifiutata invece di essere mostrata vuota, e il pannello lo dice: *macOS mantiene <cartella> privato — vedi Comandi ▸ Accesso completo al disco…*. Vale la pena dirlo, perché niente sembra un problema di permessi: la cartella è visibile, è tua e i suoi permessi dicono che puoi leggerla. Solo macOS è di mezzo, e i diritti di amministratore non cambiano nulla. Il pannello resta nella cartella che stava già mostrando.

1. Quando richiesto, scegli di aprire Impostazioni di Sistema, o aprile tu stesso.
2. Vai su Privacy e sicurezza, poi Accesso completo al disco.
3. Attiva l'interruttore accanto a Peach Commander. Se non è elencato, usa il pulsante Aggiungi per aggiungerlo.
4. Esci e riapri Peach Commander così che la nuova autorizzazione abbia effetto.

Peach Commander non viene eseguito dentro un sandbox limitato, quindi una volta concesso l'Accesso completo al disco può sfogliare e gestire i file proprio come il Finder.

## Una cartella non mostra le modifiche recenti

I pannelli normalmente si aggiornano da soli quando i file cambiano sul disco. Se una cartella è stata modificata da un altro programma, si trova su un volume di rete, o semplicemente sembra obsoleta, aggiornala manualmente.

1. Fai clic sul pannello che vuoi aggiornare.
2. Premi F2 (o Ctrl+R) per rileggere quella cartella.

I volumi di rete e montati non sempre segnalano le modifiche a macOS, quindi un aggiornamento manuale è la soluzione affidabile lì.

## Un server FTPS non si connette

Se una connessione FTP sicura fallisce, controlla queste impostazioni nei dettagli della connessione:

- Fai corrispondere la modalità di sicurezza del server: FTPS esplicito (AUTH TLS) contro FTPS implicito (porta 990) non sono intercambiabili.
- Se la connessione si blocca dopo l'accesso, passa tra la modalità di trasferimento passiva e attiva — la maggior parte dei server dietro un firewall ha bisogno della passiva.
- Se il server usa un certificato autofirmato, devi consentirlo esplicitamente; altrimenti la connessione viene rifiutata.
- Conferma host, porta, nome utente e password, e se sulla tua rete è richiesto un proxy SOCKS5.

## La compressione in RAR non fa nulla

Peach Commander può creare archivi ZIP, 7z, TAR, TAR.GZ, BZ2 e XZ da solo. RAR è diverso: poiché RAR è un formato proprietario, creare archivi RAR richiede uno strumento a riga di comando RAR separato installato sul tuo Mac. Senza di esso, RAR non è disponibile quando comprimi i file (Opzione+F5). Per leggere gli archivi RAR esistenti puoi comunque aprirli come una cartella. Se non hai bisogno specificamente di RAR, scegli invece ZIP o 7z — entrambi supportano la robusta crittografia AES-256 e i volumi divisi.

## Scorciatoie

| Azione | Scorciatoia |
| --- | --- |
| Aggiorna la cartella attiva | F2 o Ctrl+R |
| Connettiti a un server FTP/FTPS | Ctrl+F |
| Monta una condivisione di rete | Cmd+K |
| Comprimi i file selezionati | Opzione+F5 |

## Note

- Le password e le altre credenziali sono conservate solo nel portachiavi macOS, mai in file di configurazione in chiaro.
- Montare una condivisione di rete (Cmd+K, o menu Rete ▸ Monta condivisione di rete…) usa la stessa connessione che macOS stesso usa, così comparirà anche nel Finder.
- Se un problema persiste dopo un aggiornamento e un riavvio, potrebbe essere una limitazione nota piuttosto che un difetto — vedi Limitazioni note.
