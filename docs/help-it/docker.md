---
title: Container e volumi Docker
slug: docker
section: Plugin
order: 137
related: [plugins, amazon-s3, webdav, copying-files, privacy-and-security]
---

Il filesystem di un container Docker si sfoglia in un pannello come una cartella qualsiasi, e lo stesso vale per un volume Docker. Scegli **Connetti a Docker…** dal menu Rete, oppure fai clic sulla targhetta **Docker** nella barra dei volumi, e il motore compare nel pannello attivo.

È un plugin ed è **fornito disattivato**. Attivalo in **Configurazione ▸ Plugin…**. Parte spento perché una connessione al demone Docker ha sul tuo Mac gli stessi diritti che hai tu — vedi *A cosa può accedere* più sotto.

## Che cosa vedi

Il livello superiore è composto da tre cartelle:

- **Compose Projects** — tutti i container avviati da Docker Compose, raggruppati per progetto e poi per servizio. Un servizio con un solo container *è* quel container: `my-stack/backend/etc` è l’`/etc` del backend. Un servizio con più repliche mantiene un livello per esse, una cartella per container.
- **Standalone Containers** — tutto il resto, in esecuzione o no.
- **Volumes** — ogni volume Docker, come un disco a sé.

Sotto di essi sei in un filesystem vero: F3 visualizza un file, F4 lo modifica, F5 lo copia nell’altro pannello, F7 crea una cartella. L’altro pannello può essere qualsiasi cosa: una cartella locale, un archivio, un bucket S3.

Il raggruppamento è letto dalle etichette che Compose applica ai propri container e volumi, quindi è corretto anche per uno stack il cui `docker-compose.yml` non è più su questa macchina.

**I volumi sono elencati a parte di proposito.** Un volume sopravvive al container che lo ha creato, può essere condiviso da più container ed è di solito dove stanno davvero i dati che cerchi. Un volume che al momento nessuno monta resta comunque sfogliabile.

## Colonne

Fai clic con il tasto destro sull’intestazione di colonna di un pannello per aggiungere le colonne proprie del provider:

- **Stato** — `● running`, `○ stopped`, `◌ paused`, `! restarting`.
- **Accesso** — `RW`, `RO` per un rootfs o un mount di sola lettura, `VOL` per un volume Docker, `BIND` per una tua cartella montata nel container, `TMP` per un tmpfs.
- **Immagine**, **ID**.
- **Mount** — su una directory che è in realtà un mount, che cos’è: `Volume: my-stack_db-data`, oppure il percorso host dietro un bind. È così che trovi quale volume sotto **Volumes** contiene i dati di un container.

## Container fermi

I container fermi sono elencati e i loro filesystem si possono leggere e scrivere. L’API file di Docker risponde anche per un container che non gira da un mese, ed è questo che rende il tutto simile a un disco e non a un elenco di processi.

Due cose richiedono un container effettivamente in esecuzione: **eliminare** e **rinominare**. L’API del motore Docker non offre alcuna operazione per nessuna delle due — l’unico modo di togliere o spostare un file dentro un container è eseguirvi qualcosa — perciò su un container fermo entrambe vengono rifiutate anziché simulate.

## Che cosa aspettarsi

**Le scritture entrano come `root`, le eliminazioni passano per l’utente del container.** È l’impostazione di Docker, non una scelta fatta qui: copiare un file all’interno usa l’API di archivio del motore, che scrive come root; eliminare o rinominare esegue un comando nel container, che gira con l’utente configurato dall’immagine. Un’eliminazione può quindi essere rifiutata con *permesso negato* su un file che un attimo prima sei riuscito a copiare. Peach Commander non aggira la cosa agendo da root: ti riferisce ciò che ha detto il container.

**Un container o un mount di sola lettura rifiuta la scrittura** e lo segnala come errore di permessi, non come un fallimento.

**Leggere un collegamento simbolico legge ciò a cui punta.** Il pannello continua a mostrarlo come collegamento nella colonna Attr; F3 mostra il contenuto della destinazione invece di un file vuoto.

**La radice di un container fermo di grandi dimensioni potrebbe non essere elencabile.** Docker non ha alcuna chiamata che elenchi una directory. Leggere una directory significa richiederla come archivio, che contiene tutto ciò che sta sotto — per un container fermo costruito su un’immagine completa possono essere decine di gigabyte, e l’elenco viene rifiutato anziché leggere tutto. Le directory più interne non sono interessate, e un container *in esecuzione* nemmeno: una directory troppo grande per essere letta come archivio la elenca il container stesso. Se vuoi solo la via dell’archivio, vedi l’impostazione più sotto.

**Copiare fuori un intero container copia tutto il suo filesystem** — compresi `/proc` e `/dev`. Copia la directory che ti serve, non `/`.

## A cosa può accedere

Il plugin parla con il motore che raggiungeresti da un terminale: `DOCKER_HOST` se lo hai impostato, altrimenti il tuo `docker context` corrente, altrimenti i socket abituali di Docker Desktop, Colima, Rancher Desktop, Lima e Podman. Podman funziona perché espone la stessa API.

L’accesso a un demone Docker comporta di norma un accesso molto ampio alla macchina su cui gira. Il plugin ha esattamente i tuoi diritti e non ne chiede altri: non conserva alcuna credenziale, non tocca mai le directory proprie di Docker sul tuo disco e non compie alcuna azione privilegiata per tuo conto.

L’unica cosa che crea è un **container usa e getta** — e solo per raggiungere un volume che nessun container esistente monta, dato che un volume è visibile soltanto dall’interno di qualcosa che lo monta. Non viene mai avviato, porta l’etichetta di Peach Commander e viene rimosso quando lasci il disco.

## Azioni su un container o su un volume

Un clic destro su un container o su un volume offre, nel sottomenu **Docker**, quello che un disco da solo non può dire:

- **Inspect** — tutto ciò che il motore sa di esso, come JSON formattato, in una finestra che si può
  scorrere e da cui si può copiare.
- **Show Logs** — le ultime 500 righe scritte dal container.
- **Show Mounts** — ogni mount che porta, che cosa è e se è scrivibile.
- **Copy ID** — l’identificativo completo del container, o il nome del volume, negli appunti.
  L’identificativo *completo*, non i dodici caratteri della colonna ID: serve per incollarlo in un
  comando `docker`, e un id breve è un prefisso che può smettere di essere univoco.
- **Jump to Volume** — su una cartella che è in realtà un volume, andare a quel volume sotto
  **Volumes**. È l’altra metà della colonna Mount: la colonna nomina il volume, questo ti ci porta.
- **Open Compose Project** — andare al progetto a cui il container appartiene.
- **Start**, **Stop**, **Restart**, **Pause**, **Unpause** — queste cambiano il container invece di
  leggerlo, quindi chiedono prima. Start è anche la via d’uscita dai due rifiuti qui sopra: eliminare
  e rinominare richiedono un container in esecuzione.

Le voci compaiono solo dentro un disco Docker; su una cartella tua non ci sono affatto.

**Il log è anche un file.** La radice di ogni container contiene `docker-logs.txt`, che non è un file del container: leggerlo chiede il log al motore. F3 su di esso lo apre nel visualizzatore, quindi la sua ricerca, il salto a una riga e la scelta della codifica valgono — cosa che una finestra a sé non può dare. Un container che porta davvero un file con quel nome mostra il proprio, e nel file virtuale non si può scrivere nulla.

## Impostazioni

**Configurazione ▸ Impostazioni ▸ Docker** contiene tutto questo. Gli stessi valori stanno in un piccolo file in `~/Library/Application Support/PeachCommander/Docker/docker.ini`, che è ciò da modificare se prepari una macchina da uno script:

- `Endpoint` — un indirizzo da usare al posto di quello trovato.
- `ExecFallback` — `0` fa usare al plugin soltanto l’API di archivio di Docker: non eseguirà mai nulla dentro un container, al prezzo di non poter elencare una directory molto grande, né eliminare, né rinominare.
- `ProbeBudgetMB`, `MaxBudgetMB`, `MaxBudgetSeconds` — quanta parte dell’archivio di una directory valga la pena leggere prima di ripiegare o rinunciare.
- `HelperImage` — l’immagine da cui nasce il container usa e getta di cui sopra (per impostazione predefinita una qualsiasi immagine già presente).
- `ShowAnonymousVolumes` — `0` nasconde i volumi a cui Docker ha dato per nome un lungo hash perché nessun altro li ha nominati.

## Non in questa versione

Motori remoti via SSH o TLS, una shell interattiva e le immagini come filesystem di sola lettura.
