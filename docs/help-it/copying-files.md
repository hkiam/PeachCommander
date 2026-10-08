---
title: Copiare i file
slug: copying-files
section: File e cartelle
order: 24
related: [moving-and-renaming, background-transfers]
---

Peach Commander è costruito attorno a due pannelli affiancati: uno contiene i file su cui state lavorando, l'altro è la destinazione. La copia prende ciò che è selezionato nel pannello attivo e ne colloca un duplicato nella cartella mostrata nell'altro pannello, lasciando gli originali al loro posto. È il modo più rapido per duplicare file e cartelle tra due posizioni senza trascinare.

## Copiare una selezione nell'altro pannello

1. In un pannello, aprite la cartella che contiene gli elementi da copiare.
2. Nell'altro pannello, aprite la cartella in cui devono andare le copie.
3. Selezionate i file e le cartelle da copiare. Se non è selezionato nulla, viene usato l'elemento sotto il cursore.
4. Premete F5. Si apre la finestra di copia, che mostra il percorso di destinazione già compilato.

![La finestra di copia con il percorso di destinazione e le opzioni](screenshots/copy-dialog.png)
*(Figura: la finestra di copia. Il percorso di destinazione punta all'altro pannello; usate le opzioni per regolare con precisione la copia.)*

5. Modificate la destinazione se necessario, poi confermate per avviare la copia.

## Opzioni di copia

Prima di confermare, potete modificare il comportamento della copia:

- **Solo file più recenti** — salta ogni elemento la cui copia esiste già ed è della stessa età o più recente, così vengono aggiornati solo i file modificati.
- **Esegui in background** — affida la copia al gestore dei trasferimenti in background invece di mostrare la finestra di avanzamento.
- **Metti in coda per dopo** — aggiunge la copia alla coda in background senza avviarla subito.
- **Maschera di rinomina** — digitate un pattern con caratteri jolly nel campo di destinazione (ad esempio `*.bak`) per rinominare gli elementi durante la copia.

Due impostazioni valgono per ogni copia e si trovano in **Configurazione ▸ Impostazioni… ▸ Copia/Elimina**: la conservazione di date, permessi e altri attributi (attiva per impostazione predefinita) e un limite di velocità che impedisce a una copia di grandi dimensioni di saturare il disco o la connessione di rete. Per le operazioni in coda, vedi Trasferimenti in background.

## Avanzamento

Una finestra di avanzamento mostra l'intera operazione con il numero di file e di byte, la velocità di trasferimento e il tempo rimanente; quando un file richiede più di un momento, una seconda barra sopra mostra quel file. Potete mettere in pausa e riprendere in qualsiasi momento. Il menu della velocità accanto ai pulsanti limita subito questa copia (1, 5 o 20 MB/s, oppure velocità massima) senza modificare il limite in Configurazione; **Predefinito** torna a quel limite. **In background** affida la copia in corso al gestore dei trasferimenti in background: la finestra si chiude e la copia prosegue lì.

![La finestra di avanzamento del trasferimento con una barra per il file corrente e una per l'intera operazione, conteggi di file e byte, un menu della velocità e i pulsanti In background, Pausa e Annulla](screenshots/progress-dialog.png)
*(Figura: la finestra di avanzamento mostrata durante una copia o uno spostamento.)*

## Gestione dei file già esistenti

Se una copia dovesse sostituire un file esistente, Peach Commander si ferma e chiede cosa fare. Un'anteprima di entrambi i file vi aiuta a decidere.

![La finestra di conflitto per la sovrascrittura che confronta due file](screenshots/overwrite-dialog.png)
*(Figura: la finestra di sovrascrittura confronta il file esistente con quello in fase di copia.)*

Le vostre scelte comprendono:

- **Sovrascrivi** il file esistente, oppure **Sovrascrivi tutto** per applicarlo a ogni conflitto rimanente.
- **Salta** questo file, oppure **Salta tutto** i conflitti rimanenti.
- **Rinomina** automaticamente la copia in arrivo così che entrambi i file vengano mantenuti.
- **Accoda** i dati in arrivo alla fine del file esistente.
- Sovrascrivi solo quando l'origine è **più recente** o **più grande** del file esistente.

## Scorciatoie

| Azione | Tasto |
|---|---|
| Copiare la selezione nell'altro pannello | F5 |
| Copiare nella stessa cartella (creare un duplicato rinominato) | Shift+F5 |
| Aprire il gestore dei trasferimenti in background | Cmd+Shift+B |

## Note

- Copiare tra due posizioni sullo stesso disco usa una clonazione rapida quando il disco la supporta, così i file di grandi dimensioni vengono copiati quasi istantaneamente e usano poco spazio aggiuntivo.
- Le cartelle vengono copiate con tutto il loro contenuto.
- Per spostare i file invece di copiarli, usate F6. Per seguire o gestire le operazioni in coda, aprite il gestore dei trasferimenti in background con Cmd+Shift+B.
