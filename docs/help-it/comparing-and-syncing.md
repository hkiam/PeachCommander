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

## Limitare ciò che una sincronizzazione comprende

Il campo maschera contiene un elenco di inclusione sui nomi dei file. Per ciò che non riesce a esprimere, **Filtro…** accanto apre un foglio con tre schede. Quanto vi si imposta vale per il confronto *successivo*, e il pulsante indica poi quanti criteri sono attivi: un filtro che non si vede è il modo in cui un backup finisce incompleto mentre la finestra segnala di avere finito.

- **Escludi** accetta modelli separati da `;` o `|`. Un nome senza barra corrisponde a qualsiasi profondità (`*.tmp`), una barra finale indica una cartella e tutto ciò che contiene (`node_modules/`), e un modello con una barra corrisponde al percorso relativo (`src/*/generated`). Le maiuscole non contano.
- **Dimensione** e **data** giudicano una coppia nel suo insieme: se uno dei due lati esce dall’intervallo, l’intera coppia resta fuori. È voluto. Applicata a un solo lato, un’esclusione farebbe sembrare la coppia unilaterale e si trasformerebbe in una copia nella direzione sbagliata.
- **Negli ultimi N giorni** si misura da ogni confronto, non da quando un preset è stato salvato: un compito salvato continua quindi a significare «l’ultimo mese».
- La scheda **Plugin** interroga un plugin di contenuto sul lato da cui un file verrebbe copiato. Gli serve un file reale, quindi è offerta solo quando entrambi i lati sono cartelle di questo Mac.

Una cartella esclusa non viene eliminata nemmeno in modalità specchio: uno specchio rimuove solo ciò che ha effettivamente confrontato. La riga di stato indica quante voci il filtro ha trattenuto, accanto a ciò che l’esecuzione farà. Un filtro viene salvato e caricato con il preset di sincronizzazione a cui appartiene.

## Tenere due cartelle uguali, in entrambi i sensi

Le due modalità originarie non distinguono una cosa: un file presente su un solo lato è **nuovo qui**
oppure **eliminato là**, e i due casi sembrano identici. La modalità simmetrica lo ricopia — elimini
qualcosa sul portatile, sincronizzi, e torna dal backup — e la modalità specchio elimina, ma in un
solo senso.

**Bidirezionale (con memoria)** ricorda come erano le due cartelle l’ultima volta che concordavano.
Con quel registro un’eliminazione su un lato può essere riportata sull’altro.

- La **prima** esecuzione di una coppia non ha registro: si comporta come prima e non elimina nulla.
  Scrive il registro. La modalità agisce dalla seconda.
- Un’eliminazione riportata è mostrata con un colore proprio e `⇒🗑`, e **non** è spuntata: è l’unica
  riga che viene dalla memoria dell’app. Un clic sulla freccia offre le altre risposte: ricopiare il
  file, oppure lasciare entrambi i lati come sono.
- Modificato su un lato ed eliminato sull’altro è un **conflitto**, mai un’eliminazione. Così anche
  un file modificato su entrambi i lati.
- Nulla viene eliminato in base a un’assenza che il confronto non ha potuto confermare.
- Solo due cartelle di questo Mac, né un server né un archivio.

**Un’eliminazione non si annulla.** Su questo Mac il file va nel Cestino e si può rimettere dal
Finder; è tutta la rete di sicurezza. Il registro sta con le impostazioni: spostare una delle cartelle
lascia la coppia senza storia — e un’esecuzione senza storia non elimina nulla.

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

