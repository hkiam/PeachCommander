---
title: La barra dei pulsanti
slug: toolbar
section: Personalizzazione
order: 110
related: [keyboard-shortcuts, settings]
---

La barra dei pulsanti è la striscia di pulsanti a icone in cima alla finestra. Ogni pulsante è una scorciatoia con un solo clic che definisci tu stesso: esegui un comando integrato, avvia un programma o un'app esterna, salta a una cartella, o apri un'intera sotto-barra di altri pulsanti. È il modo più rapido di mettere a portata di mano le azioni che usi di più, e puoi adattarla esattamente al tuo modo di lavorare.

## Personalizza la barra dei pulsanti

1. Scegli **Configurazione > Personalizza barra strumenti…**, o fai clic destro sulla barra e scegli **Modifica barra pulsanti…**.
2. L'elenco a sinistra mostra i pulsanti correnti. Usa **+** per aggiungere un pulsante, **—** per aggiungere un separatore, **−** per rimuovere il pulsante selezionato, e **↑ / ↓** per riordinare.
3. Seleziona un pulsante e compila il modulo a destra:
   - **Comando** — digita un comando integrato, o fai clic su **Scegli…** per selezionarne uno da un elenco. Puoi anche inserire il percorso di un programma o un'app, una cartella da aprire, o un'altra barra dei pulsanti da usare come sotto-barra.
   - **Didascalia** — l'etichetta e il suggerimento mostrati per il pulsante.
   - **Parametri** e **Percorso iniziale** — passati ai programmi esterni. I segnaposto come `%P` (cartella di origine), `%N` (file corrente) e `%S` (file selezionati) vengono riempiti quando il pulsante viene eseguito.
   - **Icona** — scegli un SF Symbol o usa l'icona propria di un file o un'app; attiva **solo icona** per nascondere la didascalia.
4. Fai clic su **Salva**. La striscia si ricarica subito.

![La barra dei pulsanti in cima alla finestra con pulsanti a icone](screenshots/button-bar-crop.png)
*(Figura: la barra dei pulsanti si trova sopra i pannelli dei file; ogni pulsante esegue un comando, un programma, una cartella o una sotto-barra.)*

## Sotto-barre e overflow

Un pulsante può aprire una *sotto-barra* — un secondo insieme di pulsanti sovrapposto al primo. Fai clic su di esso per scendere; un pulsante **◀** a sinistra ti riporta alla barra precedente. Quando ci sono più pulsanti di quanti ne stiano nella larghezza della finestra, quelli in eccesso si comprimono dietro un chevron **»** all'estremità destra; fai clic su di esso per raggiungerli.

## Aggiungere un programma trascinandolo sulla barra

Non serve aprire l’editor per mettere uno strumento sulla barra. Trascinate un programma, un’app o uno script da un pannello — o dal Finder — su uno **spazio libero** della barra. Un trattino mostra dove finirà; rilasciandolo il pulsante viene creato lì.

- **Programmi, app e script** diventano un pulsante che li esegue sulla selezione corrente: i parametri del nuovo pulsante valgono `%S`, i nomi dei file selezionati. Svuotate quel campo nell’editor per uno strumento che non deve ricevere argomenti.
- **Cartelle** diventano un pulsante che vi salta — e che vi copia dentro i file quando ce li rilasciate in seguito.
- Ciò che non può essere eseguito viene rifiutato: un normale documento non ha il permesso di esecuzione, e un pulsante per esso fallirebbe al primo clic.

Rilasciare su un pulsante **esistente** ne conserva il significato: quel pulsante viene eseguito con i file rilasciati. Solo lo spazio libero ne crea uno nuovo.

## Trascina file su un pulsante

Puoi trascinare file o cartelle direttamente su un pulsante:

- **Pulsante cartella** — gli elementi rilasciati vengono copiati in quella cartella in background.
- **Pulsante programma** — il programma viene eseguito con gli elementi rilasciati come sua selezione.
- **Pulsante comando** — il comando viene eseguito normalmente.

## Nascondere la barra dei pulsanti

Scegliete **Vista > Barra dei pulsanti** per nasconderla, e di nuovo per farla tornare. Lo stesso interruttore è nella pagina **Disposizione** delle impostazioni, e la scelta viene ricordata.

## Barra dei pulsanti verticale

Per spostare la striscia dalla cima della finestra a una colonna lungo il lato sinistro, scegli **Vista > Barra dei pulsanti verticale**. Scegliila di nuovo per tornare alla striscia orizzontale.

## Note

- La barra è conservata in un file di barra pulsanti standard compatibile con Total Commander, così le barre che hai già possono essere riutilizzate.
- A queste azioni non è assegnata alcuna scorciatoia da tastiera per impostazione predefinita, ma puoi aggiungere le tue — vedi [Scorciatoie da tastiera](keyboard-shortcuts).
- Un pulsante senza icona e senza comando compare come un semplice separatore, comodo per raggruppare pulsanti correlati.
