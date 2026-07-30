---
title: Automazione (AppleScript e Comandi rapidi)
slug: automation
section: Strumenti avanzati
order: 98
related: [start-menu, settings]
---

Peach Commander è programmabile, quindi potete pilotarlo da AppleScript e dall'app Comandi rapidi. Un piccolo insieme di verbi principali consente a uno script di navigare nei pannelli, selezionare i file tramite una maschera, copiare o spostare la selezione corrente ed eseguire qualsiasi comando di Peach Commander tramite il suo id — riutilizzando esattamente le stesse azioni usate dai menu, così un passaggio da script si comporta come uno manuale. È comodo per le operazioni ripetitive: archiviare i download, preparare l'output di una build o inserire un passaggio sui file in un Comando rapido più ampio.

## Consultare il dizionario

1. Aprite **Editor di script** (in `/Applications/Utilities`).
2. Scegliete **Finestra ▸ Libreria**, poi fate doppio clic su **Peach Commander** (aggiungetelo con **+** se non è elencato).
3. Si apre il dizionario, che elenca i comandi e le proprietà riportati di seguito.

La prima volta che uno script controlla Peach Commander, macOS vi chiede di consentirlo (**Impostazioni di Sistema ▸ Privacy e Sicurezza ▸ Automazione**). Approvatelo una volta e gli script successivi verranno eseguiti senza richieste.

## Cosa potete leggere

| Proprietà | Significato |
| --- | --- |
| `active folder` | Percorso POSIX della cartella del pannello attivo. |
| `inactive folder` | Percorso POSIX della cartella dell'altro pannello. |
| `selection paths` | Gli elementi selezionati nel pannello attivo (o l'elemento sotto il cursore). |

## I verbi

| Comando | Cosa fa |
| --- | --- |
| `go to "<path>" [in left\|right]` | Apre una cartella in un pannello (predefinito: il pannello attivo). |
| `select "<mask>"` | Seleziona gli elementi nel pannello attivo tramite una maschera con caratteri jolly, ad es. `*.pdf`. |
| `copy items to "<folder>"` | Copia la selezione del pannello attivo in una cartella. |
| `move items to "<folder>"` | Sposta la selezione del pannello attivo in una cartella. |
| `run command "<id>"` | Esegue qualsiasi comando tramite il suo id, ad es. `cm_PackFiles`. |

La copia e lo spostamento usano la stessa coda di trasferimenti in background di F5/F6, quindi l'avanzamento e le eventuali richieste di sovrascrittura appaiono esattamente come per un'operazione manuale.

## Esempio

```applescript
tell application "Peach Commander"
    go to "~/Downloads" in left
    select "*.pdf"
    copy items to "~/Documents/PDFs"
    return selection paths
end tell
```

## Usarlo da Comandi rapidi

Nell'app **Comandi rapidi**, aggiungete l'azione **Esegui AppleScript** e incollate uno script come quello sopra. Questo vi permette di inserire un passaggio di Peach Commander in un Comando rapido più ampio — ad esempio, attivato da una modifica di una cartella o da un tasto di scelta rapida.

## Note

- L'id del comando che passate a `run command` è lo stesso id `cm_*` mostrato nel browser dei comandi (vedi [Il menu Avvio e i comandi personalizzati](start-menu.md)).
- Lo scripting agisce sempre sul pannello **attivo**; usate prima `go to … in left` / `in right` se avete bisogno di un lato specifico.
- Peach Commander è un'app a finestra singola, quindi gli script agiscono sui due pannelli di quella finestra.
