---
title: Markdown e HTML nel visualizzatore
slug: markdown-viewer
section: Plugin
order: 136
related: [plugins, viewing-files, privacy-and-security]
---

Premi F3 su un file `.md` o `.html` e apparirà formattato invece che come sorgente: titoli, elenchi, tabelle, collegamenti, elenchi di attività e blocchi di codice colorati per linguaggio. I diagrammi scritti come blocchi ` ```mermaid ` vengono disegnati, e la matematica scritta tra segni di dollaro viene composta.

Questo è un plugin. Tutto ciò che è descritto qui viene da **Markdown and HTML**, che puoi disattivare in **Configurazione ▸ Plugin…** — più sotto è spiegato cosa cambia.

## Dove appare la vista formattata

- **Il visualizzatore (F3).** La pagina formattata. Il menu **Vista** offre ancora Testo, Codice ed Hex, quindi il sorgente è a un clic di distanza, e in quell'elenco compare anche il nome del plugin.
- **Quick View (Ctrl+Q) e la pagina informazioni** del pannello laterale mostrano la stessa resa, così un'anteprima e una vista completa dello stesso file non si contraddicono mai.
- **La galleria** mostra una piccola immagine dell'inizio di un file Markdown invece di un'icona di documento generica.
- **Quick Look (Cmd+Y)** è l'anteprima di macOS stesso e *non* è interessata — quel pannello appartiene al sistema, e nessun plugin può disegnarvi.

## La struttura dei simboli

Premi **Simboli** nel visualizzatore per ottenere i titoli del documento, annidati come sono scritti, e fai clic su uno per saltarvi nella pagina. Funziona sulla vista formattata e sul sorgente, e le due concordano su dove si trovi un titolo.

## Diagrammi e matematica

Un blocco di codice il cui linguaggio è `mermaid` diventa un diagramma; `$…$` e `$$…$$` diventano matematica composta. Entrambi vengono disegnati **sul tuo Mac**, da motori che vengono forniti dentro il plugin — non viene scaricato nulla, e nessuna parte del tuo documento viene inviata da nessuna parte. Un segno di dollaro dentro un blocco di codice o del codice in linea resta un segno di dollaro.

Un documento senza diagrammi né formule non carica nessuno dei due motori, quindi un normale README non costa nulla in più. Un diagramma che non può essere letto mostra l'errore dove si trovava il blocco, con il testo del blocco sotto, invece di scomparire.

Entrambi possono essere disattivati separatamente in **Configurazione ▸ Impostazioni ▸ Markdown**, dove si vede anche quale versione è in uso e da dove proviene.

## La tua versione

Se ti serve una versione più recente o diversa di Mermaid o KaTeX, mettila nella cartella che apre il pulsante **Engine Folder…** e verrà usata al posto di quella fornita. I nomi dei file sono `mermaid.min.js`, `katex.min.js`, `katex.min.css` e `auto-render.min.js`. Non viene mai scaricato nulla da internet per te.

## Cosa la pagina formattata non farà

La pagina formattata è deliberatamente isolata, perché un file Markdown è contenuto che viene da altrove:

- **Non carica nulla dalla rete.** Un'immagine il cui indirizzo inizia con `http` resta vuota di proposito: recuperarla direbbe a quel server quando hai aperto il file, e da quale indirizzo. Un'immagine che sta accanto al documento sul disco viene caricata normalmente.
- **Gli script e l'HTML del documento non vengono mai eseguiti.** L'HTML scritto dentro un file Markdown è mostrato come testo, e un file `.html` è visualizzato con gli script disattivati.

## Disattivarlo

Disattiva il plugin in **Configurazione ▸ Plugin…** e i file `.md` e `.html` si apriranno come testo. La struttura continua a funzionare, la colorazione della sintassi continua a funzionare, e nulla altro cambia — la vista formattata semplicemente non viene più offerta. Lo stesso vale se nella pagina delle impostazioni del plugin disattivi solo la vista formattata.

## Limiti

- I file oltre un limite di dimensione (8 MB per impostazione predefinita, nella pagina delle impostazioni) si aprono come testo. Trasformare un documento generato molto grande in una pagina formattata è lento, e il visualizzatore di testo lo apre subito.
- La pagina formattata non può essere modificata. Usa F4 per questo, o la vista Testo per **Formatta**, **Codifica** e **Vai a**, che si applicano al sorgente e non a una pagina resa.
