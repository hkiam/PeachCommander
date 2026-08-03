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

Se il file non è scrivibile, lo scoprite all’apertura e non al momento di salvare: il titolo porta un lucchetto e la riga di stato indica l’ostacolo — appartiene a un altro utente, permessi che vietano la scrittura, un file bloccato, un volume in sola lettura o la protezione del sistema. Solo il primo caso si risolve autorizzando il salvataggio, ed è il solo in cui viene proposto; negli altri la richiesta vi costerebbe una password e fallirebbe comunque.

Il margine mostra i numeri di riga, con la riga del cursore più chiara delle altre; il pulsante accanto al menu della codifica lo nasconde. Una riga mandata a capo è numerata una volta sola, quindi il numero indica sempre la stessa riga a cui si riferisce un errore del compilatore o un commento di revisione.

## Trovare, sostituire e navigare

- Premete Cmd+F per aprire la barra di ricerca. Per sostituire il testo, aprite la barra di ricerca e passate alla vista di sostituzione, oppure fate clic su Trova/Sostituisci nella barra degli strumenti.
- Fate clic su Formatta JSON/XML per reindentare un documento JSON o XML in una disposizione pulita e leggibile.
- Fate clic su Simboli (o premete Cmd+Shift+O) per mostrare una barra laterale che elenca le classi, le funzioni e i metodi del vostro codice. Fate clic su una voce per saltare direttamente a essa.
- Premete Cmd+L per saltare a una riga specifica.
- Premete Cmd+\ per saltare tra una parentesi e la sua corrispondente.
- Fate clic sul pulsante della mappa per mostrare o nascondere la minimappa, una panoramica in scala dell'intero file su cui potete fare clic per scorrere.
- Usate il menu Codifica nella barra degli strumenti se il file è stato salvato in una codifica di testo diversa da quella predefinita.

## Filtrare con un comando shell

Fate clic su **Filtra…** (o premete Shift+Cmd+\) per inviare il testo selezionato a un comando e sostituirlo con ciò che il comando stampa. Se non è selezionato nulla, passa tutto il documento. Così gli strumenti che già conoscete diventano comandi dell’editor: `sort -u` rimuove le righe duplicate, `jq .` rende leggibile una risposta JSON, `column -t` allinea una tabella, `base64 -d` decodifica un blocco, `openssl x509 -noout -text` mostra un certificato in chiaro.

Il comando viene eseguito nella vostra shell di login: `PATH`, alias e funzioni si comportano esattamente come nel Terminale, e pipe e virgolette significano quello che vi aspettate. La directory di lavoro è la cartella del file che state modificando, così i percorsi relativi si risolvono dove ve li aspettate. I comandi usati vengono ricordati e riproposti nell’elenco a comparsa la volta successiva.

Se il comando non riesce, il vostro testo resta intatto e il messaggio di errore del comando compare nella riga di stato: un errore di sintassi di `jq` non finisce mai incollato nel vostro file. Un comando che non stampa nulla svuota la selezione, che è esattamente ciò a cui serve filtrare con `grep`, e Cmd+Z la riporta. Un comando che non termina viene interrotto dopo venti secondi.

## Ordinare, deduplicare e ripulire le righe

Il menu **Righe** — nella barra strumenti e, mentre l’editor è in primo piano, nella barra dei menu — applica le modifiche che tornano continuamente, senza comandi da digitare e senza strumenti da installare:

- Ordinare A→Z o Z→A, confrontando i numeri per valore, così `file9` viene prima di `file10`.
- Invertire l’ordine delle righe.
- Rimuovere le righe duplicate, tenendo la prima di ciascuna e lasciando le altre nel loro ordine.
- Rimuovere le righe vuote, comprese quelle che sembrano vuote solo perché contengono spazi.
- Rimuovere gli spazi a fine riga: la differenza invisibile che rende illeggibile un diff.
- Mantenere solo, oppure rimuovere, le righe che contengono un testo che digitate.

Con del testo selezionato ognuna di queste operazioni agisce sulle righe selezionate; la selezione viene prima estesa a righe intere, perché ordinare mezza riga non significa nulla. Senza selezione agiscono su tutto il documento. Ognuna è un unico passo di annullamento, quindi Cmd+Z ritira l’intera operazione.

I fine riga stanno accanto al menu Codifica: **LF** per Unix e macOS, **CRLF** per Windows, **CR** per il Mac OS classico e *(mixed)* quando un file ne contiene più di un tipo — spesso il motivo di un errore incomprensibile. Scegliendone un altro convertite tutto il file in un passo annullabile. Le operazioni sulle righe non cambiano mai il terminatore da sole: un file CRLF ordinato resta CRLF.

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
| Filtrare la selezione con un comando | Shift+Cmd+\ |

## Note

- L'evidenziazione della sintassi copre JSON, C, C#, Java, JavaScript, TypeScript, Python e Rust. Gli altri tipi di file si aprono e si modificano comunque normalmente con una colorazione di base, ma l'evidenziazione dettagliata e la struttura dei simboli sono disponibili solo per i linguaggi supportati.
- La struttura dei simboli e la funzione Vai alla riga si applicano all'editor di testo. L'editor esadecimale è pensato per l'ispezione binaria e le modifiche a livello di byte, non per il testo.
- Entrambi gli editor conservano un backup del file originale la prima volta che salvate, così una modifica accidentale è facile da annullare ripristinando quel backup.
