---
title: Automazione (AppleScript e Comandi rapidi)
slug: automation
section: Strumenti avanzati
order: 98
related: [start-menu, settings, macros]
---

Qui l’automazione funziona nei due sensi.

**Verso l’esterno:** Peach Commander è pilotabile da script, quindi puoi guidarlo da AppleScript e dall’app Comandi rapidi. Alcuni verbi di base permettono a uno script di navigare nei pannelli, selezionare file con una maschera, copiare o spostare la selezione corrente ed eseguire qualsiasi comando di Peach Commander tramite il suo id — riutilizzando esattamente le stesse azioni dei menu, così che un passo eseguito da script si comporti come uno manuale. Di questo tratta il resto della pagina.

**Verso l’interno:** Peach Commander può anche *eseguire* uno script tuo — AppleScript o JavaScript — e metterlo su un menu, un pulsante o un tasto. Serve il plugin **Scripting**, distribuito disattivato; vedi [Eseguire i tuoi script](#eseguire-i-tuoi-script) più sotto.

Per ripetere una *sequenza* di azioni sui file invece di una sola, vedi [Macro](macros.md).

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

## Eseguire i tuoi script

L’altro senso: uno script tuo, eseguito da Peach Commander.

Questo è un plugin, e viene distribuito **disattivato**, perché eseguire un programma di tua scelta può fare tutto ciò che fa il resto dell’applicazione e diverse cose che nessuna sua parte copre. Due interruttori, entrambi spenti finché non li accendi:

1. **Configurazione ▸ Plugin…** — attiva **Scripting**.
2. **Impostazioni ▸ IA** — attiva **Consenti l’esecuzione di script**. Sta in quella pagina perché è lo stesso tipo di permesso della shell dell’assistente, e i due stanno insieme.

Metti poi uno script in `scripts/` dentro la cartella di configurazione — **Comandi ▸ Apri la cartella degli script** ti porta lì e la prima volta lascia un esempio. Un file `.applescript`, `.scpt` o `.jxa` in quella cartella *è* uno script; non c’è nulla da registrare.

### Cosa riceve uno script

Lo stato dei pannelli arriva nell’ambiente, così il caso ordinario non richiede Apple event né alcuna richiesta di permesso:

| Variabile | Significa |
| --- | --- |
| `PC_ACTIVE_DIR` | La cartella del pannello attivo |
| `PC_TARGET_DIR` | La cartella dell’altro pannello |
| `PC_CURSOR_NAME` | Il file sotto il cursore |
| `PC_SELECTION_COUNT` | Quanti elementi sono selezionati |
| `PC_SELECTION_FILE` | Un file di testo con un percorso selezionato per riga (assente quando non è selezionato nulla) |

```applescript
set here to system attribute "PC_ACTIVE_DIR"
return "The active panel is showing " & here
```

Tutto ciò che va oltre passa dall’applicazione stessa, con i verbi visti sopra — le due metà quindi si compongono.

### Mettere uno script su un pulsante o un tasto

Ogni script diventa un comando chiamato `plugin.script.run.<nome>`, dove `<nome>` è il nome del file senza estensione (spazi e punti diventano trattini). Quell’id funziona in ogni posto in cui funziona un id `cm_*`: nella barra dei pulsanti, in `usercmd.ini`, in un file `.mnu` e in **Configurazione ▸ Modifica scorciatoie…**.

### Come viene eseguito uno script, e il limite di tempo

Per impostazione predefinita uno script viene eseguito come processo separato, il che consente di dargli un limite di tempo e di fermarlo se lo supera — trenta secondi salvo diversa indicazione. Uno script può scegliere di essere eseguito *dentro* l’applicazione, cosa che gli permette di restituire un valore strutturato e lo mantiene compilato tra le esecuzioni, ma allora non c’è limite di tempo: uno script che entra in ciclo blocca l’applicazione. Indica la scelta in `scripts.json`, accanto ai tuoi script:

```json
[
  { "id": "Tidy", "fileName": "Tidy.applescript", "title": "Tidy Downloads",
    "language": "AppleScript", "mode": "subprocess", "timeoutSeconds": 60 }
]
```

Solo ciò che si discosta dai valori predefiniti richiede una voce; un file senza voce prende il proprio nome come titolo, viene eseguito come processo separato e si ferma dopo trenta secondi.

### Per l’assistente

Con il plugin attivo e l’impostazione abilitata, l’assistente ottiene `run_applescript`, `run_jxa` e `check_script`. Ognuno ti mostra lo script esatto e attende la tua approvazione prima che qualcosa venga eseguito, e nessuno viene mai offerto a un agente esterno tramite MCP.

## Note

- L'id del comando che passate a `run command` è lo stesso id `cm_*` mostrato nel browser dei comandi (vedi [Il menu Avvio e i comandi personalizzati](start-menu.md)).
- Lo scripting agisce sempre sul pannello **attivo**; usate prima `go to … in left` / `in right` se avete bisogno di un lato specifico.
- Peach Commander è un'app a finestra singola, quindi gli script agiscono sui due pannelli di quella finestra.
