---
title: Confronto e sincronizzazione
slug: comparing-and-syncing
section: Strumenti avanzati
order: 90
related: [multi-rename]
---

Quando mantenete due copie della stessa cartella — una cartella di lavoro e un backup, un portatile e una condivisione di rete, un progetto e il suo archivio — Peach Commander vi aiuta a vedere esattamente cosa è cambiato e a riportare i due lati in sincronia. Potete sincronizzare due directory, confrontare i singoli file riga per riga e ispezionare i file byte per byte quando avete bisogno di certezza fino all'ultimo carattere.

## Sincronizzare due directory

1. Aprite la cartella da sincronizzare nel pannello sinistro e la cartella con cui confrontarla nel pannello destro.
2. Scegliete **Comandi ▸ Sincronizza directory…**. I due percorsi delle cartelle vengono compilati dai vostri pannelli.
3. Impostate quanto deve essere approfondito il confronto: includere le sottocartelle, confrontare **per contenuto** (non solo per data e dimensione) o ignorare la data di modifica.
4. Aggiungete una maschera di filtro (ad esempio `*.jpg;*.png`) se volete sincronizzare solo determinati file.
5. Esaminate la griglia dei risultati. Ogni riga mostra un file a sinistra, una freccia di direzione al centro e il file corrispondente a destra. Le frecce indicano cosa accadrà: **→** copia da sinistra a destra, **←** copia da destra a sinistra e **=** significa che i due sono identici.
6. Modificate le singole righe se non siete d'accordo con una direzione suggerita, poi fate clic sul pulsante di sincronizzazione per eseguire le modifiche.

![La finestra di sincronizzazione delle directory con due percorsi di cartella e una griglia di risultati di file con frecce sinistra, uguale e destra](screenshots/sync-dialog.png)
*(Figura: la finestra Sincronizza directory confronta entrambi i lati e propone una direzione di copia per ogni file.)*

## Confrontare due file per contenuto

1. Selezionate un file in ciascun pannello (oppure due file nello stesso pannello).
2. Scegliete **File ▸ Confronta per contenuto…**.
3. I due file si aprono affiancati con le loro differenze evidenziate. Usate i controlli successivo/precedente per saltare tra i blocchi modificati.
4. Se attivate la modalità di modifica, potete regolare direttamente uno dei due file e salvare le vostre modifiche.

![La finestra di confronto che mostra due file di testo affiancati con le righe divergenti evidenziate](screenshots/diff-window.png)
*(Figura: confronto di due file di testo; le righe modificate sono evidenziate su entrambi i lati.)*

## Confrontare i file byte per byte

Quando due file sembrano uguali ma dovete dimostrare che sono davvero identici (o trovare l'unico byte che differisce), usate il confronto binario. Mostra entrambi i file in una vista esadecimale con i byte non corrispondenti contrassegnati, il che è ideale per verificare i download, controllare dati codificati o confermare una copia esatta.

## Confrontare gli elenchi delle directory

Per individuare a colpo d'occhio le differenze tra due cartelle aperte, scegliete **Seleziona ▸ Confronta directory** (Shift+F2). Peach Commander contrassegna i file che differiscono o che mancano sull'altro lato, così potete agire su di essi con i consueti comandi di copia, spostamento ed eliminazione.

## Scorciatoie

| Azione | Scorciatoia |
| --- | --- |
| Confrontare gli elenchi delle directory (contrassegnare i file divergenti) | Shift+F2 |
| Confrontare per contenuto | File ▸ Confronta per contenuto… |
| Sincronizzare le directory | Comandi ▸ Sincronizza directory… |

## Note

- **Per contenuto vs. per data/dimensione.** Un confronto rapido abbina i file per dimensione e data di modifica, il che è veloce ma può essere ingannato quando le date differiscono per file identici. Attivate **per contenuto** per un risultato affidabile, al costo della lettura di ogni file.
- **Sottocartelle e filtri.** La finestra di sincronizzazione può scendere nelle sottocartelle e può essere limitata con una maschera di filtro, così potete sincronizzare solo i tipi di file che vi interessano.
- **Restate al comando.** La sincronizzazione non viene mai eseguita da sola — esaminate le direzioni proposte nella griglia dei risultati e potete modificarne qualsiasi prima che venga copiato alcunché.
- **Preimpostazioni.** Le configurazioni di sincronizzazione usate di frequente possono essere salvate e riutilizzate così non dovete reinserire le stesse opzioni ogni volta.
