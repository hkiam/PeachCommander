---
title: Amazon S3 e storage compatibili con S3
slug: amazon-s3
section: Plugin
order: 135
related: [plugins, webdav, ftp-and-sftp, copying-files]
---

Un bucket S3 si può esplorare in un pannello come qualsiasi cartella. Scegli **Connetti ad Amazon S3…** dal menu Rete, inserisci l’endpoint e le tue chiavi, e lo storage appare nel pannello attivo — con l’**elenco dei bucket come livello superiore** e ogni bucket come una normale directory sottostante.

Funziona con Amazon S3 e con tutto ciò che parla lo stesso protocollo: MinIO, Ceph/RADOS Gateway, Cloudflare R2, Wasabi, Backblaze B2 e DigitalOcean Spaces sono tutti raggiungibili.

È un plugin, quindi puoi disattivarlo o rimuoverlo in **Configurazione ▸ Plugin…**.

## Connessione

Il menu **Servizio** compila le due impostazioni che non si possono indovinare — se usare HTTPS e se l’endpoint richiede l’indirizzamento per percorso — e lascia a te l’endpoint, perché di solito dipende dal tuo account. Entrambe fallirebbero in un modo che sembra qualcos’altro: l’indirizzamento virtual-hosted verso un semplice indirizzo IP è un errore di risoluzione dei nomi, e l’indirizzamento per percorso verso Amazon è un «bucket inesistente» che si legge come un bucket mancante.

La **chiave di accesso segreta** finisce nel **Portachiavi** tramite l’applicazione host, mai in un file di configurazione. Lascia il campo vuoto a una connessione successiva e verrà usata quella salvata.

**Ricorda questa connessione** conserva endpoint, regione, ID chiave e modalità di indirizzamento — mai il segreto — in `~/Library/Application Support/PeachCommander/s3/profiles.json`. Una connessione ricordata diventa anche un pulsante nella barra dei volumi, e farci clic la collega direttamente invece di riaprire questa finestra.

### Profili che hai già

Se usi la riga di comando AWS, i suoi profili vengono offerti nel menu **Nome** con la dicitura *(AWS CLI)*, letti da `~/.aws/credentials` e `~/.aws/config` — compresi regione, token di sessione e `s3.addressing_style`. Lì non viene riscritto nulla, e un profilo così **non** viene ricordato per impostazione predefinita: tenere una seconda copia di un segreto è qualcosa che si chiede, non qualcosa che succede perché hai scelto un nome da un menu.

### Bucket pubblici

**Connetti in modo anonimo** non invia alcuna firma, che è ciò che vuole un bucket leggibile pubblicamente. Se il bucket non è pubblico te lo dice, invece di dirti che la chiave è stata rifiutata: non c’era nessuna chiave.

## Cosa puoi fare

Elencare, leggere, scrivere, creare cartelle e bucket, eliminare, rinominare e spostare funzionano tutti. Copie e spostamenti avvengono **sul server**: i byte non passano dal tuo Mac.

Una cartella in S3 non è una cosa reale — è un prefisso condiviso dalle chiavi che contiene, oppure un oggetto di zero byte il cui nome termina con `/`. Entrambi vengono mostrati come cartelle. Crearne una scrive quel marcatore; eliminarne una elimina ogni oggetto sottostante, perché non c’è altro da eliminare.

Al livello superiore, **Nuova cartella crea un bucket** — quel livello *è* l’elenco dei bucket, non potrebbe significare altro.

**Classe di storage** ed **ETag** sono disponibili come colonne del pannello (clic destro sull’intestazione). Entrambe provengono dall’elenco già ottenuto, quindi non costano nulla.

## Cosa aspettarsi

**Un bucket non si può rinominare.** S3 non ha questa operazione, e l’alternativa — copiare ogni oggetto in un nuovo bucket ed eliminare il vecchio — non è ciò che una finestra di rinomina ha chiesto. Viene rifiutato anziché simulato.

**I trasferimenti riguardano l’intero file.** Un file viene preso o inviato in un pezzo unico; un trasferimento interrotto ricomincia invece di riprendere. I caricamenti grandi vengono divisi in parti automaticamente; se una parte fallisce, le parti vengono ripulite anziché lasciate lì a essere fatturate.

**Rinominare una cartella non è atomico.** Copia ed elimina un oggetto per volta, e si ferma al primo errore invece di proseguire verso uno stato spostato a metà.

**Gli oggetti archiviati non si leggono direttamente.** Un oggetto in Glacier o Deep Archive va prima ripristinato, nella console AWS o con la CLI. Il pannello lo dice, invece di fallire come se l’oggetto fosse danneggiato.

**Elencare una cartella molto grande richiede il tempo del server.** Gli oggetti arrivano mille alla volta e il pannello si riempie quando è arrivata l’ultima pagina.

**Ogni richiesta costa denaro su un servizio a pagamento.** Il plugin è scritto per chiedere il meno possibile — le colonne vengono dall’elenco già ottenuto, la regione di un bucket viene appresa una volta e ricordata — ma esplorare un bucket non è gratis come esplorare un disco.
