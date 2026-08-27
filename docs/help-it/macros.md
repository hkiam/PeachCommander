---
title: Macro
slug: macros
section: Strumenti avanzati
order: 99
related: [automation, toolbar, start-menu, keyboard-shortcuts]
---

Una macro è una sequenza con un nome di azioni sui file — creare una cartella, spostarci la selezione, etichettare ciò che resta — che puoi rieseguire con un clic. Non è un linguaggio di script: non ci sono condizioni né cicli, ed è voluto. Una macro è un elenco che puoi leggere, e saperlo leggere è ciò che serve prima di approvarlo.

Tutto ciò che fa una macro passa per gli stessi meccanismi dell’assistente: una macro non può quindi fare nulla che non abbia il tuo permesso, ogni suo passo compare nel registro delle azioni, e un passo che si può annullare resta annullabile.

## La via più rapida: da ciò che hai appena fatto

Non devi scrivere una macro da zero.

1. Fai la cosa una volta — con l’assistente, o eseguendo una macro esistente.
2. Scegli **Configurazione ▸ Macro dalle azioni recenti…**.
3. Seleziona i passi che la macro deve ripetere, dalle un nome e lascia attivo **Aggiungi anche un pulsante**.

**Salva macro**, e il pulsante è nella barra. È tutto il ciclo.

> **Cosa non viene registrato.** L’elenco è costruito dalle azioni passate attraverso l’assistente o un’altra macro. Copiare, spostare o rinominare *a mano* nei pannelli — F5, F6, F7 — non viene registrato e non può quindi diventare una macro per questa via. Per quelle usa l’editor più sotto.

## Modificare le macro a mano

**Configurazione ▸ Modifica macro…** apre `macros.json` nella cartella di configurazione, lasciandoci un esempio commentato la prima volta. Una macro è un elenco di passi, e ogni passo indica uno strumento e i suoi argomenti:

```json
[
  {
    "id": "stage-by-month",
    "title": "File the selection into a dated folder",
    "icon": "calendar",
    "steps": [
      { "tool": "set_selection", "arguments": { "mask": "*.pdf" } },
      { "tool": "make_directory", "arguments": { "path": "%T/%{date:yyyy-MM}" } },
      { "tool": "move", "arguments": { "sources": "%S", "destination": "%T/%{date:yyyy-MM}" } }
    ]
  }
]
```

Il salvataggio ricarica subito le macro. Per vedere quali strumenti esistono e cosa prendono, chiedi `list_macros` all’assistente, o leggi l’esempio con cui il file è stato creato.

### Segnaposto

Le lettere singole sono le stesse che usano la barra dei pulsanti e il menu Start: se hai già fatto un pulsante, qui non c’è nulla di nuovo da imparare.

| Segnaposto | Significa |
| --- | --- |
| `%P` | La cartella del pannello attivo |
| `%T` | La cartella dell’altro pannello |
| `%N` | Il file sotto il cursore |
| `%S` | I file selezionati — un **elenco**, che è ciò che prendono `copy`, `move` e `move_to_trash` |
| `%{date:yyyy-MM}` | La data di avvio della macro, in quel formato |
| `%{1}` | Il risultato del passo 1, quando quel passo ha prodotto un percorso o un elenco di percorsi |

Le graffe servono per le aggiunte perché le lettere sono già occupate: `%M` significa «il nome sotto il cursore nell’altro pannello» in tutto il resto del programma, quindi un mese non poteva scriversi così.

`%S` è il solo punto in cui una macro si discosta da un pulsante: su un pulsante la selezione diventa un elenco di parole per una riga di comando, qui diventa l’elenco dei percorsi completi che prendono gli strumenti sui file.

Un passo il cui `%S` o `%{1}` risulta **vuoto ferma la macro** invece di eseguirsi senza nulla. Un `move` senza file non è un `move` più piccolo: è una richiesta che non dice più niente, e segnalarne il successo sarebbe una bugia.

## Eseguire una macro

Ogni macro diventa un comando chiamato `mc_<id>`, e compare quindi da sola in:

- **Configurazione ▸ Elenco comandi…**
- **Configurazione ▸ Modifica scorciatoie… — assegnala a un tasto**
- Il selettore di comandi dell’editor della barra dei pulsanti
- Il tuo file di menu `.mnu` e `usercmd.ini`, se li usi
- L’assistente, che può eseguirla per nome

Prima che una macro che modifica qualcosa venga eseguita, ti mostra i suoi passi come elenco e attende. Puoi escludere un passo che non vuoi; ciò che resta è ciò che viene eseguito. Una macro che solo legge parte senza chiedere.

Se un passo fallisce, la macro **si ferma lì** invece di continuare: il passo due presuppone di norma che il passo uno sia avvenuto, e spostare file in una cartella che non è stata creata non è un successo parziale. Il resoconto indica il passo e dice cosa è andato storto; i passi eseguiti sono nel registro delle azioni.

## Cosa può fare una macro

Una macro è valutata sulla cosa più impegnativa che contiene. Una macro i cui passi solo leggono è trattata come una lettura; una che termina con un’eliminazione definitiva è protetta come un’eliminazione definitiva — prima che parta qualunque cosa, non quattro passi dopo.

Non concedere nulla in più è il comportamento predefinito. Se una macro contiene un passo che i tuoi permessi non ammettono — un comando shell, uno script — l’intera macro viene rifiutata con la sua motivazione, e non accade nulla.

## Annullare

Ogni passo è registrato separatamente, quindi **annulla** dopo una macro riprende il suo *ultimo* passo, non l’intera macro. Non esiste un annulla per l’intera macro, perché diversi strumenti non hanno alcun inverso e un pulsante che lo offrisse mentirebbe su quelli.

## Dove viene salvato tutto

- Le tue macro sono in `macros.json` nella cartella di configurazione — un file semplice, che puoi confrontare e tenere con i tuoi dotfile.
- I pulsanti aggiunti da una macro sono normali voci della barra dei pulsanti in `default.bar`, quindi rimuoverne uno è come rimuovere qualsiasi pulsante.

## Prossimi passi

- [Automazione (AppleScript e Comandi rapidi)](automation.md) — Pilotare Peach Commander da uno script, ed eseguire i tuoi script come passo di una macro.
- [La barra dei pulsanti](toolbar.md) — Dove finisce il pulsante aggiunto da una macro.
- [Tastiera e scorciatoie](keyboard-shortcuts.md) — Assegnare una macro a un tasto.
