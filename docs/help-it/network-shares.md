---
title: Condivisioni di rete
slug: network-shares
section: Rete e accesso remoto
order: 104
related: [ftp-and-sftp]
---

Peach Commander può connettersi ai file server della tua rete locale o aziendale — condivisioni SMB (Windows/Samba) e AFP — e mostrare il loro contenuto in un pannello proprio come una cartella sul tuo Mac. Una volta connessa una condivisione, puoi sfogliare, copiare, spostare, rinominare e aprire file al suo interno esattamente come in locale, incluso copiare tra la condivisione e il tuo altro pannello.

## Connettiti a un server

1. Fai clic sul pannello a cui vuoi connetterti (la condivisione connessa si apre nel pannello attivo).
2. Premi Cmd+K, o scegli **Rete > Risorse di rete > Connetti condivisione di rete…**.
3. Nella finestra **Connetti al server**, digita l'indirizzo del server. Puoi indicare:
   - un indirizzo SMB, per esempio `smb://fileserver/projects`
   - un indirizzo AFP, per esempio `afp://fileserver/projects`
   - un percorso in stile Windows, per esempio `\\fileserver\projects\reports`
   - un semplice nome `server/condivisione`
4. Fai clic su Connetti (o premi Invio). Se il server richiede nome e password, macOS mostra la sua consueta finestra di accesso — inserisci lì le tue credenziali.
5. Quando la condivisione è pronta, il pannello attivo la apre automaticamente. Sfogliala e lavoraci come con qualsiasi altra cartella.

## Disconnetti

Una condivisione connessa compare come un volume montato sul tuo Mac. Per disconnetterla, espellila nel modo consueto di macOS — per esempio dalla barra laterale del Finder o dall'elenco dei dispositivi in Peach Commander.

## Scorciatoie

| Azione | Scorciatoia |
| --- | --- |
| Connetti condivisione di rete… | Cmd+K |

## Note

- L'autenticazione (nome utente, password e un'eventuale opzione "ricorda nel mio portachiavi") è gestita dalla consueta finestra di accesso di macOS, così le password dei server salvate funzionano come nel Finder.
- Se indichi un indirizzo che non può essere interpretato, Peach Commander chiede un indirizzo SMB/AFP, un percorso in stile Windows o un nome `server/condivisione`, e non viene montato nulla.
- Dopo la conferma, la connessione può richiedere un istante mentre macOS monta la condivisione; il pannello passa a essa non appena diventa disponibile.
- Questo si connette a dispositivi condivisi su una rete. Per raggiungere invece un server FTP, FTPS o SFTP, vedi l'argomento correlato sotto.
- Un percorso in stile Windows funziona anche in **Vai alla cartella** e nella barra del percorso sopra un pannello, non solo in «Connetti al server». Scrivetevi `\\fileserver\projects\reports` e arrivate in quella cartella.
- Se la condivisione è già connessa, si va direttamente alla cartella: nessun foglio di accesso e nessun secondo viaggio al server. Viene montata sempre e solo la condivisione stessa; alle cartelle sottostanti si arriva con una navigazione ordinaria, così l'intero albero sopra di esse resta raggiungibile.
