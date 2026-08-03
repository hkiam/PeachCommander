---
title: Modificare i file
slug: editing-files
section: Visualizzazione e modifica
order: 72
related: [viewing-files]
---

Quando avete bisogno di modificare un file invece di limitarvi a guardarlo, Peach Commander lo apre in un editor integrato. I file di testo e di codice si aprono in un editor completo con evidenziazione della sintassi, ricerca e sostituzione, una struttura dei simboli del vostro codice e una minimappa per una navigazione rapida. I file binari possono essere aperti in un editor esadecimale separato, dove potete ispezionare e modificare i singoli byte. Non dovete mai lasciare l'app per una rapida modifica.

## Modificare un file di testo o di codice

1. In uno dei pannelli, spostate il cursore sul file da modificare.
2. Premete F4, oppure scegliete File ▸ Modifica. Il file si apre nella finestra dell'editor.
3. Apportate le vostre modifiche. Se il file è in un formato di programmazione o di dati riconosciuto, parole chiave, stringhe e commenti vengono colorati automaticamente.
4. Premete Cmd+S (o fate clic su Salva) per scrivere le modifiche. Il primo salvataggio conserva un backup dell'originale accanto al file, così potete sempre tornare a esso.

Per iniziare un file di testo nuovo di zecca nella posizione corrente, premete Shift+F4.

![L'editor di testo integrato che mostra l'evidenziazione della sintassi, la struttura dei simboli e la minimappa](screenshots/editor.png)
*(Figura: l'editor con l'evidenziazione della sintassi, la struttura dei simboli a sinistra e la minimappa a destra.)*

Se il file appartiene a `root` — una voce in `/etc`, un plist di launchd, la configurazione di un server web —, il salvataggio propone di farlo **come amministratore**: macOS chiede l’autorizzazione come sempre, il contenuto passa da un file temporaneo privato invece che da una riga di comando, e il file mantiene proprietario e permessi invece di diventare vostro in silenzio.

## Trovare, sostituire e navigare

- Premete Cmd+F per aprire la barra di ricerca. Per sostituire il testo, aprite la barra di ricerca e passate alla vista di sostituzione, oppure fate clic su Trova/Sostituisci nella barra degli strumenti.
- Fate clic su Formatta JSON/XML per reindentare un documento JSON o XML in una disposizione pulita e leggibile.
- Fate clic su Simboli (o premete Cmd+Shift+O) per mostrare una barra laterale che elenca le classi, le funzioni e i metodi del vostro codice. Fate clic su una voce per saltare direttamente a essa.
- Premete Cmd+L per saltare a una riga specifica.
- Premete Cmd+\ per saltare tra una parentesi e la sua corrispondente.
- Fate clic sul pulsante della mappa per mostrare o nascondere la minimappa, una panoramica in scala dell'intero file su cui potete fare clic per scorrere.
- Usate il menu Codifica nella barra degli strumenti se il file è stato salvato in una codifica di testo diversa da quella predefinita.

## Formattare un file

Fate clic su **Formatta** nell’editor (lo stesso comando esiste nel visualizzatore) per rientrare il file. Peach Commander scegle il formattatore in base all’estensione e mostra nella barra di stato quale ha usato, per esempio *formatted (jq)* — così sapete sempre cosa ha dato forma al risultato.

**Senza installare nulla**: JSON, XML, SVG, plist, HTML, configurazione in stile INI e YAML. YAML è un caso a parte: viene ripulito invece di essere rientrato, perché in YAML l’indentazione *è* la struttura e riscriverla senza un vero parser YAML potrebbe cambiare il significato del file. Gli spazi a fine riga sparyscono, le tabulazioni sparse nell’indentazione diventano spazi, le sequenze di righe vuote si riducono — e tutto ciò che sta in uno scalare di blocco (`|` o `>`) resta esattamente com’è, perché lì lo spazio è contenuto.

**I formattatori migliori subentrano automaticamente.** Se ne avete uno installato, Peach Commander usa quello, perché uno strumento dedicato corrisponde di solito a ciò che l’ecosistema si aspetta — e per i formati di configurazione conserva i vostri commenti:

| Installate | e ottenete |
| --- | --- |
| `yq` o `prettier` | formattazione YAML completa, commenti preservati |
| `taplo` | TOML |
| `sqlformat` o `sql-formatter` | SQL |
| `prettier` | Markdown |
| `jq` | JSON, nello stile consueto |
| `xmllint` | XML e SVG |

Se un tipo di file non ha formattatore, il pulsante è disattivato e la voce di menu non è selezionabile. Provarci comunque spiega perché — *«taplo non è installato»* si legge diversamente da *«JSON non valido»*.

### Usare un formattatore proprio

Per formattare un tipo che Peach Commander non conosce, o per usare un altro strumento, create `formatters.ini` nella cartella di configurazione — una sezione per estensione:

```ini
[swift]
tool = swiftformat
args = --quiet stdin

[sql]
tool = /opt/homebrew/bin/sqlfluff
args = format -
```

`tool` è un nome di eseguibile (cercato come farebbe la vostra shell) o un percorso assoluto; `args` vengono passati così come sono. Il testo del file entra dallo standard input e il testo formattato viene riletto dallo standard output, quindi funziona qualsiasi formattatore da riga di comando ben educato. Le vostre voci vincono su tutto il resto. Al primo avvio viene creato un modello commentato: aprite il file e compilatelo.

Anche i plugin possono fornire formattatori — vedi [Plugins](plugins.md).

## Modificare un file byte per byte

1. Selezionate il file in un pannello.
2. Scegliete File ▸ Modifica come esadecimale (oppure fate clic destro sul file e scegliete Modifica come esadecimale).
3. Digitate cifre esadecimali per sovrascrivere i byte, oppure usate i tasti freccia per muovervi nel file. Backspace e Delete rimuovono i byte.
4. Premete Cmd+S per salvare. Come per l'editor di testo, viene conservato un backup una tantum dell'originale.

## Scorciatoie

| Azione | Tasto |
|---|---|
| Modificare il file | F4 |
| Creare e modificare un nuovo file di testo | Shift+F4 |
| Salvare | Cmd+S |
| Trovare | Cmd+F |
| Mostrare/nascondere la struttura dei simboli | Cmd+Shift+O |
| Andare a una riga | Cmd+L |
| Saltare alla parentesi corrispondente | Cmd+\ |
| Annulla / ripristina (editor esadecimale) | Cmd+Z / Cmd+Shift+Z |

## Note

- L'evidenziazione della sintassi copre JSON, C, C#, Java, JavaScript, TypeScript, Python e Rust. Gli altri tipi di file si aprono e si modificano comunque normalmente con una colorazione di base, ma l'evidenziazione dettagliata e la struttura dei simboli sono disponibili solo per i linguaggi supportati.
- La struttura dei simboli e la funzione Vai alla riga si applicano all'editor di testo. L'editor esadecimale è pensato per l'ispezione binaria e le modifiche a livello di byte, non per il testo.
- Entrambi gli editor conservano un backup del file originale la prima volta che salvate, così una modifica accidentale è facile da annullare ripristinando quel backup.
