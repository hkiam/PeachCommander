---
title: Ricerca rapida e filtro
slug: quick-search-and-filter
section: Organizzare la visualizzazione
order: 44
related: [searching, view-modes-and-sorting]
---

Quando una cartella contiene centinaia di elementi, raramente hai bisogno di scorrere. Peach Commander ti permette di saltare direttamente a un file digitandone il nome (ricerca rapida), ridurre l'elenco ai soli elementi che ti interessano (filtro rapido) e mostrare o nascondere i file con il punto che macOS di solito tiene nascosti. Tutti e tre funzionano dentro il pannello attivo senza aprire una finestra.

## Salta a un file digitando (ricerca rapida)

1. Fai clic su un pannello dei file così che sia attivo.
2. Inizia a digitare l'inizio di un nome. Il cursore salta al primo elemento corrispondente.
3. Continua a digitare per affinare la corrispondenza, o premi di nuovo la stessa lettera per scorrere gli elementi che iniziano con quella lettera.
4. Il testo digitato si cancella dopo una breve pausa, così puoi iniziare una nuova ricerca in qualsiasi momento.

Per impostazione predefinita, le lettere semplici vanno alla riga di comando e la ricerca rapida si attiva con Ctrl+Opzione+lettera (il comportamento classico). Puoi impostare la ricerca rapida per rispondere invece alla digitazione semplice, o disattivarla, nelle impostazioni di configurazione.

## Filtra l'elenco (filtro rapido)

1. Nel pannello attivo, premi Ctrl+S per attivare il filtro rapido.
2. Digita una maschera di filtro. Il pannello si restringe in tempo reale agli elementi corrispondenti mentre digiti.
3. Premi Esc per cancellare il filtro e mostrare di nuovo tutto.

Il filtro accetta diversi tipi di maschere:

- **Testo semplice** corrisponde a qualsiasi nome che contiene ciò che hai digitato (per esempio, `report` mostra ogni elemento con "report" in un punto qualsiasi del nome).
- **Caratteri jolly** usano `*` (qualsiasi carattere) e `?` (un carattere). Separa più maschere con un punto e virgola e aggiungi esclusioni dopo una barra verticale, per esempio `*.jpg;*.png|*thumb*` per mostrare le immagini ma nascondere le miniature.
- **Tag del Finder** filtrano per colore del tag: digita `tag:red` (o `#red`) per mostrare solo gli elementi con tag rosso, o un semplice `tag:` per mostrare tutto ciò che porta un tag qualsiasi.

## Mostra i file nascosti

Premi Ctrl+H, o scegli il comando dal menu Vista, per commutare gli elementi nascosti (nomi che iniziano con un punto e file nascosti dal sistema). L'impostazione si applica al pannello attivo ed è ricordata tra le sessioni.

## Scorciatoie

| Azione | Scorciatoia |
| --- | --- |
| Ricerca rapida (modalità classica) | Ctrl+Opzione+lettera |
| Filtro rapido on/off | Ctrl+S |
| Cancella filtro / annulla | Esc |
| Mostra/nascondi file nascosti | Ctrl+H |

## Note

- La ricerca rapida sposta solo il cursore; il filtro rapido cambia effettivamente quali elementi sono elencati. Usa il filtro quando vuoi lavorare su un sottoinsieme (per esempio, selezionare o copiare solo le corrispondenze).
- Le impostazioni di filtro e file nascosti sono per pannello, così i due lati possono mostrare cose diverse contemporaneamente.
- La ricerca rapida corrisponde ai nomi dall'inizio; la modalità testo semplice del filtro rapido corrisponde in qualsiasi punto del nome. Usa un carattere jolly come `*testo*` se vuoi che il filtro si comporti allo stesso modo.
