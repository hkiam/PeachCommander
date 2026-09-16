---
title: Spazi di lavoro
slug: workspaces
section: Personalizzazione
order: 118
related: [settings, panels-and-tabs]
---

Un’area di lavoro è un contesto con un nome in cui si lavora: “Fare ordine nei backup”, “Ordinare le candidature”. Ciascuna ricorda entrambi i pannelli, tutte le schede aperte, quale scheda è attiva su ciascun lato, la modalità di visualizzazione, l’albero delle cartelle, la cronologia avanti/indietro e quali file aveva contrassegnato, il filtro rapido e la disposizione della finestra: il pannello laterale, il dock, le barre e dove si trova il divisore. Passare da una all’altra costa un clic, e per strada non si perde mai nulla: un’area di lavoro non viene mai salvata, perché non finisce mai.

Finché non se ne crea una seconda, non c’è nulla da vedere. Nessuna barra, nessun menu, nessuna scorciatoia.

## Come si fa

1. Predisponga entrambi i pannelli per il lavoro da svolgere: apra le cartelle, aggiunga le schede, scelga la vista che desidera.
2. Apra il menu **Vai** e scelga **Aree di lavoro…**, quindi **Nuova area di lavoro…**. Le dia un nome.
3. In cima alla finestra compare una striscia di pastiglie colorate, e nella barra dei menu compare il menu **Area di lavoro**. La nuova area di lavoro parte come copia della disposizione in cui si trovava.
4. Predisponga la nuova area di lavoro per il suo compito. Quella da cui proviene conserva ciò che aveva.
5. Faccia clic su una pastiglia per passare, oppure prema **Ctrl+1** fino a **Ctrl+9**. Tutto passa con essa.

## Tornare a un punto di partenza

Ogni area di lavoro ricorda anche la disposizione con cui è stata impostata. **Area di lavoro ▸ Salva lo stato attuale nell’area di lavoro** (Cmd+Ctrl+S) rende la disposizione attuale quel punto di partenza, e **Ripristina lo stato salvato** vi riporta dopo un pomeriggio di divagazioni.

Questo è indipendente dalla memoria continua: non deve mai salvare per non perdere il segno.

## La raccolta

Ogni area di lavoro ha una raccolta — per quello che succede davvero mentre si mette ordine: tre
cartelle dentro i backup trova qualcosa che appartiene a un lavoro tutt’altro. **Trascini file sulla
pastiglia di un’altra area** e finiranno nella *sua* raccolta: non cambia area, e non viene copiato né
spostato nulla; il contatore sulla pastiglia sale e lei prosegue. Tenga **⌥** mentre rilascia per
copiare nella cartella di quell’area, o **⌘** per spostare. **Ctrl+Cmd+A** mette la selezione nella
raccolta dell’area corrente, la pagina **Raccolta** nel pannello laterale ne mostra il contenuto, e
**Area di lavoro ▸ Copia la raccolta nell’altro pannello** tratta l’intera raccolta in una sola
operazione.

I file eliminati nel frattempo, o su un volume non montato, sono mostrati come mancanti anziché
rimossi, e un’operazione di gruppo propone di ignorarli o di toglierli prima. Uno spostamento svuota la
raccolta di ciò che ha spostato; una copia la lascia com’era.

| Azione | Scorciatoia |
| --- | --- |
| Passare all’area di lavoro da 1 a 9 | Ctrl+1 … Ctrl+9 |
| Rendere la disposizione attuale il punto di partenza | Cmd+Ctrl+S |

## Suggerimenti

- Faccia clic con il tasto destro su una pastiglia per rinominarla, darle un colore o eliminarla — oppure faccia clic sulla **✕** alla sua estremità destra, che elimina quell’area di lavoro dopo aver chiesto conferma. Il colore è ciò che le permette di distinguere le aree di lavoro a colpo d’occhio quando la finestra è stretta e i nomi non ci stanno più.
- Nove è il limite, così ogni pastiglia resta riconoscibile.
- **Mostra ▸ Mostra la barra delle aree di lavoro** nasconde la striscia senza disattivare la funzione, per chi si sposta tra le aree con la tastiera.
- Le aree di lavoro si possono disattivare del tutto in **Impostazioni ▸ Schede**. Le sue aree di lavoro vengono conservate e tornano invariate quando riattiva la funzione.

## Limitare un’area di lavoro a una cartella

A un’area di lavoro si può dire di che cosa si occupa, e allora controlla prima che un’operazione esca
dai confini. Faccia clic con il tasto destro sulla pastiglia, **Limita a una cartella ▸ Imposta sulla
cartella attiva**, e scelga se le operazioni fuori vadano consentite, chieste o rifiutate.

Si controlla prima che un’eliminazione prenda file da fuori, prima che una copia o uno spostamento
atterri fuori, e prima che una rinomina o una nuova cartella scriva fuori. **La navigazione non è mai
limitata**: un gestore di file che si rifiuta di mostrare una cartella è rotto, e tutto il valore sta
nell’istante prima di F8. Nemmeno i salvataggi dell’editor sono coperti; avvengono nella loro finestra.

## Il diario

Ogni area di lavoro tiene nota di ciò che vi è stato fatto: cartelle visitate, operazioni eseguite,
righe di shell digitate e tutto ciò che un limite di cartella ha rifiutato. **Area di lavoro ▸ Diario…**
lo mostra, giorno più recente per primo, con un filtro **Problemi** per tutto ciò che è fallito o è
stato fermato.

Invio ripete la riga selezionata, con la stessa regola della cronologia: solo una copia o uno
spostamento si ripetono con un tasto, e una riga di shell viene inserita nella riga di comando invece
che eseguita. Il diario è deliberatamente separato dalla cronologia globale: quella risponde a "dove
vado di solito" e ordina per frequenza; questo risponde a "che cosa è successo qui" e mantiene
l’ordine. Viene eliminato con la sua area di lavoro, conservato senza limiti altrimenti, e si può
disattivare in **Impostazioni ▸ Schede**.

## Passare un’area di lavoro a qualcun altro

**Area di lavoro ▸ Esporta area di lavoro…** scrive l’area di lavoro corrente in un file
`.pcworkspace` che puoi inviare a qualcuno o tenere in una cartella di progetto. **Importa area di
lavoro…** lo rilegge, e lo stesso fa un doppio clic nel Finder.

Ciò che viaggia è il **punto di partenza salvato** dell’area di lavoro — premi prima ⌘⌃S se vuoi la
disposizione che hai davanti — insieme al nome, al colore, al limite di cartella e alla raccolta. Le
cartelle dentro la tua cartella Inizio vengono scritte in forma abbreviata, così il file si apre
nella cartella Inizio dell’*altra* persona e non in una cartella col tuo nome.

Ciò che deliberatamente non viaggia:

- **Tutto ciò che potrebbe essere una credenziale.** Le schede che puntano a una connessione o a un’unità di plugin montata vengono rimosse all’esportazione, e il resoconto ne dice il numero. Non c’è nulla da perdere, perché di una connessione non viene scritto nulla.
- **Il diario.** Registra quello che hai fatto tu e nomina cartelle della tua macchina. Resta qui.
- Le posizioni del cursore, la cronologia di annullamento, la dimensione della finestra e le finestre aperte di visualizzatore, editor, ricerca o sincronizzazione.
- Le schede del terminale e le conversazioni con l’assistente. Appartengono a questo Mac; un file di area di lavoro porta *dove* lavorare, non ciò che è in esecuzione.

Un’importazione **aggiunge** sempre un’area di lavoro; non sostituisce mai quella in cui ti trovi e
non passa mai da sola a un’altra — un file che qualcuno ti ha mandato non deve spostare la tua
finestra. Le cartelle non presenti su questo Mac si aprono sulla più vicina che esiste, gli elementi
della raccolta mantengono i loro percorsi e appaiono in grigio, e un limite di cartella la cui
cartella manca viene mantenuto ma passa a chiedere invece che a rifiutare. Un resoconto elenca tutto.

## Note

- Il passaggio non chiede mai se salvare e non chiude mai nulla. Le operazioni sui file in corso proseguono, e così tutto ciò che gira in un terminale: le schede dell’area che lascia vengono messe da parte con le loro shell vive, non chiuse. Anche le conversazioni dell’assistente seguono l’area di lavoro.
- L’annullamento segue un’area di lavoro solo finché l’app è in esecuzione: un passo di annullamento porta con sé l’azione che lo inverte, e quella non può essere scritta su disco.
- Un’area di lavoro registra posizioni di cartelle, non i file che contengono. Se una cartella salvata è stata spostata o eliminata, quella scheda si apre nella cartella più vicina ancora esistente.
- Passando da una versione precedente: le aree di lavoro che aveva salvato diventano pastiglie, e la sessione in cui si trovava diventa la prima. Non si perde nulla, e il vecchio `workspaces.ini` viene conservato come `workspaces.ini.migrated`.
