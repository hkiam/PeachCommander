---
title: Tastiera e scorciatoie
slug: keyboard-shortcuts
section: Personalizzazione
order: 112
related: [keyboard-shortcuts-reference, settings, macros]
---

Peach Commander è costruito per essere guidato dalla tastiera. Viene fornito con due schemi di scorciatoie già pronti e ti permette di riassegnare qualsiasi comando ai tasti che preferisci. Se vieni da un classico gestore di file a due pannelli, puoi mantenere i tasti che conosci già; se preferisci usare le combinazioni Mac familiari, passa allo schema macOS con un clic. Un browser dei comandi con ricerca ti permette di scoprire tutto ciò che l'app può fare ed eseguire qualsiasi comando per nome.

## Cambia schema di tastiera

1. Apri **Impostazioni** (Cmd+, o **Configurazione > Impostazioni…**) e scegli la pagina **Tastiera**.
2. Scegli uno schema dal menu **Schema**:
   - **Total Commander (classico)** (predefinito) mantiene i tasti tradizionali, con combinazioni basate su Ctrl come Ctrl+R per aggiornare un pannello.
   - **macOS** mappa le stesse azioni su tasti Mac familiari dove ha senso, per esempio Cmd+C per copiare i file e Cmd+F per cercare.
3. La modifica ha effetto subito nei menu e nella barra delle scorciatoie. **Modifica scorciatoie…** si trova subito sotto, perché le singole riassegnazioni si sovrappongono allo schema che hai scelto.

## Personalizza le scorciatoie

1. Scegli **Configurazione > Modifica scorciatoie…**, oppure fai clic su **Modifica scorciatoie…** nella pagina Tastiera delle Impostazioni.
2. Trova un comando usando il campo di ricerca, poi seleziona la sua riga.
3. Fai clic su **Registra…** e premi la combinazione di tasti che vuoi. Viene assegnata subito.
4. Se quella combinazione era già usata da un altro comando, un avviso ti indica a quale comando è stata sottratta.
5. Usa **Cancella** per rimuovere la scorciatoia di un comando, o **Ripristina valori predefiniti** per scartare tutte le tue modifiche e tornare ai tasti originali dello schema.

![L'editor delle scorciatoie da tastiera che elenca i comandi con i tasti assegnati](screenshots/keys-editor.png)
*(Figura: cerca un comando, poi usa Registra, Cancella o Ripristina valori predefiniti per cambiare la sua scorciatoia.)*

## Sfoglia tutti i comandi

1. Scegli **Configurazione > Browser dei comandi…**.
2. Digita nel campo di ricerca per filtrare per nome, categoria o descrizione.
3. Fai doppio clic su un comando, o selezionalo e fai clic su **Esegui**, per eseguirlo sul pannello attivo.

![Il browser dei comandi che mostra un elenco di comandi con ricerca](screenshots/command-browser.png)
*(Figura: ogni comando in un unico elenco con ricerca, con una breve descrizione di ciascuno.)*

## Scorciatoie

| Azione | Percorso di menu |
|---|---|
| Scegli uno schema | Impostazioni > Tastiera > Schema |
| Modifica le scorciatoie | Configurazione > Modifica scorciatoie… |
| Sfoglia tutti i comandi | Configurazione > Browser dei comandi… |
| Aggiorna il pannello attivo | F2 (anche Ctrl+R) |

## Note

- Le tue scorciatoie personalizzate vengono salvate automaticamente e sovrapposte allo schema attivo. Cambiare schema mantiene le tue sostituzioni personali.
- I comandi non disponibili nel contesto corrente compaiono attenuati sia nell'editor delle scorciatoie sia nel browser dei comandi.
- Per usare i tasti funzione (F1–F12) direttamente, attiva **Usa i tasti F1, F2, ecc. come tasti funzione standard** in Impostazioni di Sistema > Tastiera. Altrimenti, tieni premuto il tasto **Fn** insieme al tasto funzione.
