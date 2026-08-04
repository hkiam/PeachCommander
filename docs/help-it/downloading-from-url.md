---
title: Scaricare da un URL
slug: downloading-from-url
section: Rete e accesso remoto
order: 102
related: [ftp-and-sftp]
---

Peach Commander può recuperare un file direttamente da un indirizzo web HTTP o HTTPS nel pannello attivo, senza aprire un browser. Incollate un link, confermate il nome con cui verrà salvato e il download procede da solo — con ripresa se la connessione cade, download in lotto per molti link in una volta e verifica del checksum opzionale così sapete che il file è arrivato integro.

## Scaricare un file

1. Aprite la cartella del pannello in cui volete che arrivi il file.
2. Scegliete **Rete > Scarica da URL**, oppure premete Cmd+Shift+U.
3. Incollate l'indirizzo web nella casella **URL**. Se avete copiato prima un link, viene inserito automaticamente.
4. Controllate il nome in **Salva come** — viene suggerito dal link e potete modificarlo liberamente.
5. Fate clic su **Scarica**.

![La finestra Scarica da URL con un link, il nome di file modificabile e le opzioni](screenshots/download-url.png)
*(Figura: la finestra di download — incollate un link, modificate il nome e impostate verifica, credenziali, intestazioni o un proxy opzionali.)*

Per impostazione predefinita il download procede **in background**, così potete continuare a lavorare nei pannelli mentre viene trasferito. Disattivate **Scarica in background** per attenderlo, oppure attivate **Metti in coda per dopo** per configurarlo senza avviarlo subito.

## Scaricare più file in una volta

Incollate un indirizzo web per riga nella casella **URL**. Quando è presente più di un link, il nome di ogni file viene ricavato automaticamente dal suo link e i campi per singolo file **Salva come** e **Verifica** vengono disattivati.

## Riprendere un download interrotto

Se un trasferimento viene interrotto, Peach Commander conserva ciò che ha già ricevuto in un file temporaneo `.part`. Riavviare lo stesso download riprende dal punto in cui si era fermato ogniqualvolta il server lo supporti, invece di ricominciare da capo. Il file `.part` viene rinominato con il nome finale solo una volta che il download si è concluso con successo.

## Scorciatoie

| Azione | Scorciatoia |
| --- | --- |
| Scaricare da URL | Cmd+Shift+U |

## Suggerimenti

- **Verificate il file.** Per un singolo download, incollate un checksum **SHA-256** atteso nel campo **Verifica**. Dopo il trasferimento, il checksum del file viene confrontato con esso così potete fidarvi che il file corrisponda a quanto indicato dall'autore.
- **Serve un accesso?** Inserite un nome utente e una password nei campi **Auth** per i siti che usano l'autenticazione di base. Per l'accesso basato su token, aggiungete una riga `Authorization: Bearer …` nella casella **Intestazioni**.
- **Intestazioni personalizzate.** Aggiungete un'intestazione per riga nella casella **Intestazioni**, ad esempio `Referer: …` o `Cookie: …`, per i link che funzionano solo con intestazioni di richiesta specifiche.
- **Proxy.** Instradate il download attraverso un proxy HTTP o SOCKS5 compilando host, porta e tipo del **Proxy**.
- **Certificati non attendibili.** Attivate **Consenti certificato non attendibile** solo per un sito di cui vi fidate che usa un certificato autofirmato; disattiva il normale controllo di sicurezza HTTPS per quel download.
- **Nota:** la scorciatoia era Cmd+Maiusc+D, usata anche da Vai ▸ Scrivania, quindi una delle due non scattava mai. Lo scaricamento è passato a Cmd+Maiusc+U (U di URL) e Scrivania mantiene Cmd+Maiusc+D, come nel Finder.
