---
title: Server WebDAV
slug: webdav
section: Plugin
order: 130
related: [plugins, ftp-and-sftp, network-shares]
---

Un server WebDAV — Nextcloud, ownCloud, un Synology, l’archivio di un’università — si può sfogliare in un pannello come qualsiasi cartella. Scegliete **Connessione WebDAV…** dal menu Rete, indicate un URL e il server compare nel pannello attivo.

È un plugin: potete disattivarlo o rimuoverlo in **Configurazione ▸ Plugin…**.

## Connettersi

L’URL è la raccolta in cui volete arrivare, con il vostro nome utente davanti all’host:

```
https://anna@files.example.com/remote.php/dav/files/anna/
```

La password viene chiesta a parte e finisce nel **portachiavi** tramite l’app, mai in un file di configurazione. Lasciatela vuota a una connessione successiva e verrà usata quella salvata.

Ogni URL a cui vi connettete viene ricordato — gli ultimi trenta, il più recente per primo — e proposto la volta dopo nel menu a comparsa. Quell’elenco si trova in `~/Library/Application Support/PeachCommander/webdav/sites.json` e contiene **solo URL**; nessuna password vi viene mai scritta.

## Usate https

L’autenticazione è HTTP Basic, il che significa che nome utente e password viaggiano codificati in base64 — codificati, non cifrati. Con `https://` la connessione li protegge. Con `http://` sono di fatto in chiaro, e tutto ciò che sta fra voi e il server può leggerli. Il semplice `http://` è accettato, perché un server sulla vostra macchina o su una rete di laboratorio chiusa è un caso legittimo, ma non è una buona impostazione predefinita.

## Cosa potete fare

Elencare, leggere, scrivere, creare cartelle, eliminare, rinominare e spostare funzionano tutti: corrispondono ai verbi WebDAV `PROPFIND`, `GET`, `PUT`, `MKCOL`, `DELETE` e `MOVE`. Un pannello su un server WebDAV si comporta quindi, per il lavoro di ogni giorno, come un pannello su un disco.

## Cosa aspettarsi

**I trasferimenti riguardano il file intero.** Un file viene preso o inviato in un pezzo solo; non c’è trasferimento per intervalli, quindi un trasferimento interrotto di un file grande ricomincia invece di riprendere.

**Copiare all’interno del server passa dal vostro Mac.** Il plugin non usa il verbo `COPY`, perciò duplicare un file sul server lo scarica e lo ricarica. Su una linea lenta, spostare — cosa che fa il server stesso — è molto più veloce che copiare.

**Niente viene bloccato.** Il `LOCK` di WebDAV non è usato: se due persone scrivono lo stesso file nello stesso momento decide chi salva per ultimo, esattamente come su una condivisione di rete senza blocchi.

**Solo autenticazione Basic.** I server che richiedono Digest, un token bearer o un flusso di single sign-on rifiuteranno la connessione. Molti di essi offrono in alternativa una password specifica per l’app, che qui funziona.
