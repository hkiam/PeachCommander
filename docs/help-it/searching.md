---
title: Trovare i file
slug: searching
section: Trovare i file
order: 60
related: [selecting-files, quick-search-and-filter]
---

Quando devi rintracciare file ovunque sul tuo Mac — per nome, per ciò che contengono, o per dimensione e data — usa la finestra Trova file. Cerca in una o più cartelle (e nelle loro sottocartelle), può guardare dentro file di testo e archivi e ti permette di inviare tutto ciò che trova direttamente in un pannello, così puoi agire sui risultati come se fossero una cartella ordinaria.

## Trova file per nome

1. Nel pannello che mostra la cartella in cui vuoi cercare, scegli **Comandi > Trova file…** (o premi Cmd+Maiusc+F).
2. Nella scheda **Generale**, digita uno schema di nome in **Cerca**. Puoi usare caratteri jolly come `*.pdf` o `report_*.docx`. Per cercare in più cartelle in una volta, elencale nel campo della cartella iniziale separate da un punto e virgola (`;`).
3. Fai clic su **Avvia**. Le corrispondenze compaiono nell'elenco dei risultati sotto man mano che vengono trovate.
4. Fai doppio clic su un risultato qualsiasi per saltare a quel file nel pannello attivo, o seleziona un risultato e fai clic su **Visualizza** (F3) per aprirlo nel visualizzatore integrato.

![La finestra Trova file nella scheda Generale, che mostra lo schema del nome, la cartella e l'elenco dei risultati](screenshots/find-files-general.png)
*(Figura: la scheda Generale — cerca per schema di nome in una o più cartelle.)*

## Cerca per contenuto, dimensione e data

1. Per cercare all'interno dei file, digita il testo in **Trova testo** nella scheda Generale: viene cercato ciò che è nel campo, e un campo vuoto cerca solo per nome. Le opzioni ti permettono di renderlo **Distingui maiuscole**, corrispondere solo a una **Parola intera**, trattare il testo come un'**Espressione regolare**, fare una **Ricerca contenuto esadecimale** o trovare file **Non contenenti** il testo.
2. Passa alla scheda **Avanzate** per restringere i risultati per **Dimensione** (per esempio da `10K` a `5M`), per intervallo di **data di modifica**, o ai file modificati negli ultimi N giorni.
3. Attiva **Cerca dentro gli archivi** per guardare dentro gli archivi trovati — gli stessi formati che puoi aprire con Invio, compresi quelli aggiunti da un plugin di archiviazione. Gli archivi che non è stato possibile aprire vengono segnalati al termine della ricerca.
4. Per limitare la ricerca a ciò che hai già scelto, attiva **Cerca solo negli elementi selezionati** prima di avviare.
5. Attivate **Cercare anche nei commenti dei file** e il testo verrà cercato nel commento di ogni file oltre che nel suo contenuto. È così che si ritrova un file per quello che si è scritto *su* di esso — «l'originale del cliente», «sostituito dall'esportazione 2026» — quando nel file non compare nulla di simile. Un risultato trovato così mostra il commento invece di una riga del file, e nessun numero di riga, perché la corrispondenza non è nel testo del file. Maiuscole/minuscole, parola intera ed espressioni regolari valgono per il commento esattamente come per il contenuto; una ricerca esadecimale no, perché un commento è testo digitato. **Non contenente** resta coerente: un file è elencato quando il testo non è né nel contenuto né nel commento. Se il plugin Note è attivo, la sua nota è disponibile come campo di contenuto, sul quale potete filtrare in **Plugins** — vedete [Lavorare con i plugin](plugins.md).
6. Alcuni plugin sanno trasformare un file in un testo che il file non contiene — il plugin di decompilazione trasforma un `.class` in sorgente Java. Attivate **Cerca nel testo fornito dai plugin** e quei file vengono cercati come quel testo invece che come i propri byte, così una frase del sorgente si trova in una classe compilata. L’opzione appare solo se un plugin del genere è installato, ed è più lenta: produrre il testo può significare eseguire un decompilatore per ogni file.

![La finestra Trova file nella scheda Avanzate, che mostra i filtri di dimensione e data](screenshots/find-files-advanced.png)
*(Figura: la scheda Avanzate — filtra per dimensione, data e altri attributi.)*

Se hai plugin che aggiungono campi di contenuto (come le dimensioni delle immagini), la scheda **Plugin** ti permette di richiedere che un campo corrisponda a una condizione — per esempio, solo immagini più larghe di 1000 pixel.

![La finestra Trova file nella scheda Plugin, che mostra una condizione su un campo di contenuto](screenshots/find-files-plugins.png)
*(Figura: la scheda Plugin — corrispondenza su campi di contenuto forniti dai plugin.)*

## Ricerche veloci con Spotlight

Per le cartelle locali che macOS ha già indicizzato, attiva **Usa Spotlight** nella scheda Generale per risultati quasi istantanei. Spotlight cerca nell'indice invece di scansionare i file, quindi ignora le espressioni regolari, i limiti di profondità delle sottocartelle e l'ambito solo-selezione.

## Riutilizza e trasferisci i risultati

- **Invia all'elenco** colloca ogni risultato nel pannello attivo come elenco temporaneo, così puoi copiare, spostare o eliminare l'intero insieme in una volta.
- Nella scheda **Carica / Salva**, scegli **Salva come modello…** per memorizzare la ricerca corrente (schemi e opzioni) e sceglierla di nuovo più tardi dall'elenco dei modelli.
- **Cerca** e **Trova testo** ricordano ciascuno le ultime 20 voci usate, dalla più recente: fai clic sulla freccia in fondo al campo per sceglierne di nuovo una. Un termine usato due volte torna in cima invece di comparire due volte, e gli elenchi sopravvivono alla chiusura della finestra e all'uscita dall'app. **Cancella cronologia…** nella scheda **Carica / Salva** li dimentica entrambi; i modelli salvati non sono interessati.

## Scorciatoie

| Azione | Scorciatoia |
| --- | --- |
| Apri Trova file | Cmd+Maiusc+F o Opzione+F7 |
| Avvia / arresta la ricerca | Pulsante Avvia nella finestra |
| Visualizza il risultato selezionato | F3 |

## Note

- La ricerca nel contenuto legge i file per intero nelle cartelle locali e negli archivi; nelle posizioni di rete i file molto grandi vengono letti solo in parte (circa 16 MB, o 64 MB con un'espressione regolare).
- La ricerca dentro gli archivi scende fino a quattro livelli di archivi annidati.
- **Includi cartelle nei risultati** elenca anche le cartelle i cui nomi corrispondono, non solo i file.
- Spotlight copre solo le cartelle locali indicizzate; per posizioni di rete o corrispondenza basata su schemi, lascialo disattivato e lascia che Trova file scansioni.
