---
title: Spostamento e rinomina
slug: moving-and-renaming
section: File e cartelle
order: 26
related: [copying-files, multi-rename]
---

Lo spostamento riposiziona file e cartelle invece di duplicarli, e la rinomina cambia i loro nomi senza toccarne il contenuto. Poiché Peach Commander mostra due pannelli affiancati, spostare è solo questione di scegliere ciò che vuoi in un pannello e inviarlo alla cartella aperta nell'altro. Puoi anche rinominare un elemento sul posto, o dare agli elementi spostati nuovi nomi al volo usando una maschera a caratteri jolly.

## Sposta file nell'altro pannello

1. Nel pannello di origine, apri la cartella che contiene gli elementi da spostare, e apri la cartella di destinazione nell'altro pannello.
2. Seleziona il file o la cartella da spostare. Per spostarne più di uno in una volta, selezionali tutti prima (vedi *Selezione dei file*).
3. Premi F6, o scegli **File > Sposta**.
4. Controlla la cartella di destinazione mostrata nella finestra e fai clic su **OK** (o premi Invio) per avviare lo spostamento.

![La finestra di spostamento che mostra il campo del percorso di destinazione, le opzioni e una casella per la coda](screenshots/copy-dialog.png)
*(Figura: la finestra di spostamento usa lo stesso campo di destinazione della copia — digita un percorso, o aggiungi una maschera a caratteri jolly per rinominare mentre sposti.)*

Gli spostamenti sullo stesso disco avvengono quasi istantaneamente. Quando la destinazione è su un disco diverso, Peach Commander copia gli elementi e rimuove gli originali solo dopo che ogni file è arrivato in modo sicuro.

## Rinomina sul posto

1. Seleziona un singolo file o cartella.
2. Premi Maiusc+F6, o scegli **File > Rinomina**.
3. Modifica il nome direttamente nel pannello, poi premi Invio per confermare o Esc per annullare.

## Rinomina durante lo spostamento

Il campo di destinazione nella finestra di spostamento accetta una maschera a caratteri jolly, così puoi rinominare gli elementi mentre si spostano:

1. Seleziona gli elementi e premi F6.
2. Nel campo di destinazione, aggiungi una maschera di nome dopo la cartella di destinazione, per esempio `/Users/tu/Archive/*_backup.*`.
3. `*` sta per il nome originale e `.*` per l'estensione originale. Conferma per spostare e rinominare in un solo passaggio.

## Scorciatoie

| Azione | Scorciatoia |
| --- | --- |
| Sposta nell'altro pannello | F6 |
| Rinomina sul posto | Maiusc+F6 |

## Suggerimenti

- La finestra di spostamento offre lo stesso pulsante di opzioni e la stessa casella della coda in background della copia, così puoi accodare spostamenti grandi e lasciarli in esecuzione in background.
- Lo spostamento all'interno dello stesso disco è un'operazione rapida sul posto, quindi è sicuro per cartelle molto grandi. Uno spostamento tra dischi diversi richiede più tempo perché i dati vengono prima copiati, poi l'origine viene eliminata.
- Per rinominare molti file in una volta con numerazione, cerca-e-sostituisci o schemi, usa invece lo strumento di rinomina multipla (vedi *Rinomina multipla*).
