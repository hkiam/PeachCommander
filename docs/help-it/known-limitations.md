---
title: Limitazioni note
slug: known-limitations
section: Aiuto e risoluzione dei problemi
order: 144
related: [troubleshooting]
---

Peach Commander fa molto, ma alcune funzioni hanno limiti onesti nella versione attuale. Conoscerli in anticipo evita confusione quando qualcosa si comporta in modo inatteso. Questa pagina elenca i vincoli attuali e, dove possibile, una soluzione semplice.

## Archivi

- **I file ZIP molto grandi (ZIP64) non possono essere aperti dal lettore integrato.** Gli archivi ZIP, TAR e TAR compressi con gzip standard si aprono direttamente come cartelle. Gli archivi ZIP64 — usati quando un archivio contiene più di circa 65.000 elementi o supera i 4 GB — sono al di fuori di ciò che il lettore nativo gestisce, quindi potrebbero non aprirsi o elencarsi in modo incompleto.
- **Gli archivi ZIP crittografati** (sia il vecchio ZipCrypto sia WinZip AES) sono supportati per la navigazione, ma ti verrà chiesta la password.
- Altri formati come CPIO, ISO, CAB, LZH, XAR e PAX si aprono tramite uno strumento ausiliario invece del lettore nativo.

## Rete (SFTP / SCP)

- **Cambiare gli attributi dei file tramite SFTP non ha effetto in questa versione.** Puoi sfogliare, scaricare e caricare tramite SFTP/SCP, ma le richieste di modifica di permessi, proprietà o marche temporali su un server remoto vengono ignorate silenziosamente. Effettua quelle modifiche sul server stesso, o tramite un protocollo diverso.
- Alla prima connessione a un server SFTP ti verrà chiesto di fidarti della sua chiave host. Peach Commander la ricorda in seguito (fiducia al primo uso).

## Scaricare da un URL

- Il comando **Scarica da URL** (menu Rete) usa attualmente la scorciatoia Cmd+Maiusc+D, che è la stessa scorciatoia di Vai > Scrivania. Quando entrambi sono disponibili i menu possono entrare in conflitto — avvia il download direttamente dal menu Rete per sicurezza.

## Aggiornamento delle cartelle

- **Un pannello nota le modifiche esterne con un breve ritardo, non istantaneamente.** Peach Commander controlla la cartella corrente per modifiche circa ogni 2 secondi, quindi un file aggiunto o rimosso da un'altra app può impiegare un momento a comparire. Se non vuoi aspettare, aggiorna il pannello attivo manualmente con F2 o Ctrl+R.

## Altri limiti attuali

- **Alcuni percorsi assoluti molto lunghi** (cartelle profondamente annidate il cui percorso completo è insolitamente lungo) potrebbero non essere gestiti in modo affidabile. Lavorare più vicino alla cima dell'albero delle cartelle evita questo.
- **Questa build di anteprima non è firmata.** Gatekeeper di macOS potrebbe avvisare che l'app proviene da uno sviluppatore non identificato la prima volta che la apri. Fai clic destro sull'app e scegli Apri, poi conferma, per eseguirla. Gli aggiornamenti automatici non sono ancora disponibili in questa build.

## Scorciatoie

| Azione | Scorciatoia |
| --- | --- |
| Aggiorna il pannello attivo | F2 o Ctrl+R |
| Scarica da URL | Cmd+Maiusc+D |

## Note

Queste sono limitazioni della versione attuale e si prevede che miglioreranno nelle versioni successive. Se incontri un comportamento non descritto qui, consulta l'argomento sulla risoluzione dei problemi.
