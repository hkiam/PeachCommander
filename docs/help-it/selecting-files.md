---
title: Selezione dei file
slug: selecting-files
section: File e cartelle
order: 22
related: [copying-files, searching]
---

Prima di copiare, spostare, eliminare o comprimere qualcosa, indichi prima a Peach Commander su quali elementi agire. L'elemento su cui si trova il cursore è sempre l'elemento corrente, ma puoi anche *contrassegnare* uno o più file e cartelle in modo che un comando venga eseguito su tutti in una volta. Gli elementi contrassegnati si distinguono con un colore del nome diverso nel pannello.

## Contrassegna file e cartelle

1. Fai clic su una riga per spostarvi il cursore. Un singolo clic seleziona solo quell'elemento.
2. Per contrassegnare più elementi in una volta, tieni premuto Cmd e fai clic su ciascuno, oppure tieni premuto Maiusc e fai clic per contrassegnare un intervallo.
3. Per contrassegnare l'elemento sotto il cursore e scendere in un solo movimento, premi Ins. Premilo ripetutamente per contrassegnare rapidamente una serie di elementi consecutivi. Anche la barra spaziatrice commuta il contrassegno dell'elemento corrente (e mostra la dimensione di una cartella).
4. Per contrassegnare tutto nel pannello, scegli Seleziona > Seleziona tutto (Ctrl+Num+), o premi Cmd+A. Scegli Seleziona > Deseleziona tutto (Ctrl+Num-) per cancellare tutti i contrassegni.

## Seleziona o deseleziona in base a uno schema

1. Scegli Seleziona > Seleziona gruppo… (Num+) per aggiungere elementi i cui nomi corrispondono a uno schema, o Seleziona > Deseleziona gruppo… (Num-) per rimuovere gli elementi corrispondenti dai contrassegni correnti.
2. Digita una maschera con caratteri jolly. Usa `*` per qualsiasi carattere e `?` per un singolo carattere. Separa più maschere con un punto e virgola ed elenca le eccezioni dopo una barra verticale — per esempio `*.jpg;*.png` contrassegna tutte le immagini, e `*.*|*.bak` contrassegna tutto tranne i file di backup.

![La finestra Seleziona gruppo con una maschera a caratteri jolly digitata nel campo dello schema](screenshots/select-by-mask.png)
*(Figura: contrassegnare i file con una maschera a caratteri jolly.)*

## Inverti, stessa estensione e ripristina

- **Inverti selezione** (Num*, menu Seleziona) capovolge ogni contrassegno: gli elementi contrassegnati diventano non contrassegnati e viceversa — comodo per "tutto tranne questi".
- **Seleziona tutti con la stessa estensione** (Alt+Num+, menu Seleziona) contrassegna ogni file che condivide l'estensione dell'elemento sotto il cursore, così una sola pressione prende, per esempio, tutti i file `.pdf`.
- **Ripristina selezione** (Num/, menu Seleziona) riporta il tuo precedente insieme di contrassegni — utile se un comando li ha cancellati o hai contrassegnato il gruppo sbagliato.

## Scorciatoie

| Azione | Tasto |
|---|---|
| Commuta contrassegno, scendi | Ins |
| Commuta contrassegno (elemento corrente) | Spazio |
| Seleziona tutto / Deseleziona tutto | Ctrl+Num+ / Ctrl+Num- |
| Seleziona tutto (alternativa) | Cmd+A |
| Seleziona gruppo per maschera | Num+ |
| Deseleziona gruppo per maschera | Num- |
| Inverti selezione | Num* |
| Seleziona tutti con la stessa estensione | Alt+Num+ |
| Ripristina selezione precedente | Num/ |

## Note

- I contrassegni e il cursore sono indipendenti: spostare il cursore con i tasti freccia non cambia ciò che è contrassegnato.
- La voce della cartella superiore (`..`) non può mai essere contrassegnata.
- Seleziona gruppo, Deseleziona gruppo e Inverti selezione corrispondono al nome del file, quindi puoi includere o lasciare fuori le cartelle a seconda delle opzioni della finestra.
- Dopo che una copia, uno spostamento o un'eliminazione termina, gli elementi gestiti con successo vengono deselezionati automaticamente, mentre quelli falliti restano contrassegnati così puoi riprovarli.
