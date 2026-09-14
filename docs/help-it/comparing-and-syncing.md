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

Fate clic con il tasto destro su una riga per guardare i file che stanno dietro. **Confronta** apre i due lati uno accanto all’altro, mentre **Visualizza file sinistro** e **Visualizza file destro** aprono un solo lato nel visualizzatore: è la risposta per una riga che esiste su un lato soltanto, dove non c’è nulla da confrontare. Le voci che non si applicano alla riga su cui avete fatto clic sono disattivate invece di non fare nulla. Un file dentro un `.zip` o su un server viene prima estratto o scaricato in una copia temporanea in sola lettura, così l’originale non viene mai toccato. Vale anche per **Confronta**, quindi una cartella può essere confrontata con un archivio o con un server — e i pulsanti di unione e salvataggio restano disattivati per quel lato, perché ciò che vi è aperto è la copia.

## Confrontare due file per contenuto

1. Selezionate un file in ciascun pannello (oppure due file nello stesso pannello).
2. Scegliete **File ▸ Confronta per contenuto…**.
3. I due file si aprono affiancati con le loro differenze evidenziate. Usate i controlli successivo/precedente per saltare tra i blocchi modificati.
4. Se attivate la modalità di modifica, potete regolare direttamente uno dei due file e salvare le vostre modifiche.

![La finestra di confronto che mostra due file di testo affiancati con le righe divergenti evidenziate](screenshots/diff-window.png)
*(Figura: confronto di due file di testo; le righe modificate sono evidenziate su entrambi i lati.)*

Quando i due file non presentano differenze di alcun tipo, la finestra lo dice in una fascia colorata in alto, invece di lasciarvelo dedurre da una tabella in cui non c’è nulla di evidenziato. La fascia compare anche, in un colore di avviso, quando un file non è stato possibile leggerlo affatto: qualunque verdetto sulle differenze sarebbe allora un’affermazione su un confronto che non è mai avvenuto. Il confronto byte per byte dice la stessa cosa per la stessa ragione: due file che non riesce ad aprire non sono due file identici.

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
- Nulla viene eliminato in base a un’assenza che il confronto non ha potuto confermare — una
  cartella illeggibile, o una trattenuta dal filtro, non prova nulla su ciò che contiene.
- Solo due cartelle di questo Mac. Né un server né un archivio: un’eliminazione in un archivio lo
  riscrive, un’eliminazione su un server è definitiva, e questa modalità non è quella con cui
  provarlo.

**Un’eliminazione non si annulla.** Su questo Mac il file va nel Cestino e si può rimettere dal
Finder; è tutta la rete di sicurezza. **Memoria…** nella finestra elenca ogni coppia che l’app ricorda, segnala quella che stai guardando e consente di dimenticarne una qualsiasi; dopo di che il confronto successivo di quelle cartelle si comporta di nuovo come un primo. Nulla viene mai dimenticato da sé: una cartella su un disco smontato non è sparita, è solo scollegata.

Il registro sta con le impostazioni: spostare una delle cartelle
lascia la coppia senza storia — e un’esecuzione senza storia non elimina nulla.

## Che cosa ha fatto un’esecuzione, e che cosa se ne può riprendere

Ogni sincronizzazione viene annotata. **Esecuzioni…** nella finestra le elenca, le più recenti per prime — quando, quali due cartelle, quale modalità e quanti file sono stati copiati, eliminati o tenuti fuori — e mostra che cosa è successo a ciascun file dell’esecuzione selezionata.

È quell’elenco a rendere utilizzabile il Cestino. Un file che questo Mac ha eliminato è finito nel Cestino, e l’esecuzione ha registrato *dove*, il che conta più di quanto sembri: il Cestino rinomina in caso di collisione, così un secondo `notes.txt` atterra come `notes.txt 11-17-15-028.txt`, e cercarlo per nome porta a quello sbagliato. **Mostra nel Cestino** porta il Finder dritto sull’elemento.

**Rimetti a posto…** sposta i file eliminati da un’esecuzione fuori dal Cestino, ai percorsi da cui erano stati eliminati. Ciascuno viene prima controllato, e ciò che non regge viene rifiutato con la sua motivazione anziché forzato:

- A quel percorso c’è di nuovo qualcosa. Viene lasciato stare — un rimettere a posto non può mai sovrascrivere.
- L’elemento non è più nel Cestino, oppure è stato eliminato definitivamente invece che messo lì.
- Il lato era un archivio o un server. Un archivio viene riscritto per intero, e un server non ha
  Cestino: non è stato quindi conservato nulla.
- La cartella in cui l’esecuzione ha scritto non c’è più, o non è più la stessa cartella — un punto di
  mount riutilizzato, per dire. Allora viene rifiutata l’intera esecuzione anziché agire su una sua
  parte.
- È già stato rimesso a posto. Il registro lo ricorda, quindi un secondo tentativo non fa nulla.
- Oppure il registro stesso è uno su cui questa versione non può agire — scritto da una versione più
  recente dell’app, o che nomina un percorso fuori da entrambe le cartelle. Raro, e rifiutato anziché
  indovinato.

**Una copia non si può riprendere.** Toglierla significherebbe eliminare un file che potresti aver modificato nel frattempo, che è lo scambio opposto rispetto al rimettere a posto un’eliminazione: l’app quindi non lo offre — l’esecuzione ti dice quali file ha copiato e puoi eliminarli tu. Un file che è stato *sovrascritto* è l’unica vera lacuna, ed è ormai piccola: su questo Mac la versione sostituita finisce nel Cestino come un file eliminato, così **Mostra nel Cestino** la ritrova. Verso un archivio, verso un server o verso un volume senza Cestino non è possibile, e la conferma lo dice prima dell’esecuzione.

Vengono conservate le ultime 200 esecuzioni, o 64 MB di esse, a seconda di che cosa arriva prima; oltre, le più vecchie cadono una alla volta man mano che ne arrivano di nuove, e **Dimentica** e **Dimentica tutto** le cancellano sul posto. Un’esecuzione molto grande — più di 20.000 file — conserva ogni problema e tutto ciò che ha messo nel Cestino, ma non le copie andate a buon fine, e lo dice invece di lasciartene accorgere. Le sue eliminazioni si possono comunque rimettere a posto: ciò che è stato lasciato fuori sono le copie, e una copia non si sarebbe potuta riprendere comunque.

Dimenticare non cambia nulla nelle cartelle; ciò che se ne va è il registro di quanto è stato fatto, e con esso l’offerta di rimettere qualcosa a posto. A differenza della memoria bidirezionale, questo viene buttato via automaticamente — perdere la memoria di una *coppia* cambierebbe ciò che fa l’esecuzione successiva, mentre perdere il registro di un’esecuzione toglie solo un’offerta.

## Scorciatoie

| Azione | Scorciatoia |
| --- | --- |
| Confrontare gli elenchi delle directory (contrassegnare i file divergenti) | Shift+F2 |
| Confrontare per contenuto | File ▸ Confronta per contenuto… |
| Sincronizzare le directory | Comandi ▸ Sincronizza directory… |
| Visualizzare un lato di una riga di sincronizzazione | Clic destro sulla riga ▸ Visualizza file sinistro / destro |

## Note

- **Per contenuto vs. per data/dimensione.** Un confronto rapido abbina i file per dimensione e data di modifica, il che è veloce ma può essere ingannato quando le date differiscono per file identici. Attivate **per contenuto** per un risultato affidabile, al costo della lettura di ogni file.
- **Sottocartelle e filtri.** La finestra di sincronizzazione può scendere nelle sottocartelle e può essere limitata con una maschera di filtro, così potete sincronizzare solo i tipi di file che vi interessano.
- **Restate al comando.** La sincronizzazione non viene mai eseguita da sola — esaminate le direzioni proposte nella griglia dei risultati e potete modificarne qualsiasi prima che venga copiato alcunché.
- **Preimpostazioni.** Le configurazioni di sincronizzazione usate di frequente possono essere salvate e riutilizzate così non dovete reinserire le stesse opzioni ogni volta.

