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
4. Premete Cmd+S (o fate clic su Salva) per scrivere le modifiche. Il salvataggio sostituisce il file; se volete conservare il contenuto precedente accanto a esso, attivate i backup in Impostazioni ▸ Modifica/Visualizza.

Per iniziare un file di testo nuovo di zecca nella posizione corrente, premete Shift+F4.

![L'editor di testo integrato che mostra l'evidenziazione della sintassi, la struttura dei simboli e la minimappa](screenshots/editor.png)
*(Figura: l'editor con l'evidenziazione della sintassi, la struttura dei simboli a sinistra e la minimappa a destra.)*

Se il file appartiene a `root` — una voce in `/etc`, un plist di launchd, la configurazione di un server web —, il salvataggio propone di farlo **come amministratore**: macOS chiede l’autorizzazione come sempre, il contenuto passa da un file temporaneo privato invece che da una riga di comando, e il file mantiene proprietario e permessi invece di diventare vostro in silenzio.

Se il file non è scrivibile, lo scoprite all’apertura e non al momento di salvare: il titolo porta un lucchetto e la riga di stato indica l’ostacolo — appartiene a un altro utente, permessi che vietano la scrittura, un file bloccato, un volume in sola lettura o la protezione del sistema. Solo il primo caso si risolve autorizzando il salvataggio, ed è il solo in cui viene proposto; negli altri la richiesta vi costerebbe una password e fallirebbe comunque.

Il margine mostra i numeri di riga, con la riga del cursore più chiara delle altre; il pulsante accanto al menu della codifica lo nasconde. Una riga mandata a capo è numerata una volta sola, quindi il numero indica sempre la stessa riga a cui si riferisce un errore del compilatore o un commento di revisione.

## Trovare, sostituire e navigare

- Premete Cmd+F per aprire la barra di ricerca. Per sostituire il testo, aprite la barra di ricerca e passate alla vista di sostituzione, oppure fate clic su Trova/Sostituisci nella barra degli strumenti.
- Per un’**espressione regolare** usa Cerca ▸ *Trova con espressione regolare…* (Ctrl+Cmd+F) o *Sostituisci con espressione regolare…* (Ctrl+Opt+Cmd+F). `^` e `$` corrispondono a inizio e fine riga, e nella sostituzione `$1` sta per il primo gruppo — `(\w+) (\d+)` sostituito con `$2=$1` trasforma quindi `alpha 11` in `11=alpha`. **Solo nella selezione** mantiene la modifica nel testo selezionato; **Sostituisci tutto** riscrive ogni occorrenza in un unico passo annullabile con Cmd+Z.
- Trova successivo (Cmd+G) segue l’ultima ricerca usata, semplice o con motivo. Un motivo che non compila viene segnalato nella finestra invece di non trovare nulla in silenzio.
- Fate clic su Formatta JSON/XML per reindentare un documento JSON o XML in una disposizione pulita e leggibile.
- Fate clic su Simboli (o premete Cmd+Shift+O) per mostrare una barra laterale che elenca le classi, le funzioni e i metodi del vostro codice — oppure, per un file JSON, YAML o XML, le sue chiavi ed elementi. Fate clic su una voce per saltare direttamente a essa. Vedete [Lavorare con JSON, YAML e XML](#lavorare-con-json-yaml-e-xml) per cos'altro serve quella struttura.
- Premete Cmd+L per saltare a una riga specifica.
- Premete Cmd+\ per saltare tra una parentesi e la sua corrispondente.
- Fate clic sul pulsante della mappa per mostrare o nascondere la minimappa, una panoramica in scala dell'intero file su cui potete fare clic per scorrere.
- Usate il menu Codifica nella barra degli strumenti se il file è stato salvato in una codifica di testo diversa da quella predefinita.

## Lavorare con JSON, YAML e XML

Questi tre formati ricevono un trattamento a parte, perché un file di configurazione si percorre per struttura e non per numero di riga.

La barra laterale **Simboli** elenca le chiavi di un file JSON o YAML e gli elementi di un file XML, annidati come lo è il documento. Un elemento prende il nome dal suo attributo `id`, `name` o `key` quando ne ha uno, così venti voci `<server>` si distinguono. Un elenco mostra le sue voci come `[0]`, `[1]`, e dove una voce inizia con una chiave viene indicata anche quella — `[0] name`. Il campo di filtro sopra l'elenco trova una chiave per nome in un file di qualsiasi dimensione, e la barra di stato mostra sempre il percorso di ciò che contiene il cursore.

Anche un file rotto ottiene una struttura fino al punto in cui si rompe, che è proprio quando serve di più.

Il menu **Struttura** — nella barra dei menu mentre l'editor è in primo piano — vi muove in quella struttura:

- **Vai al nodo contenitore** (Ctrl+Cmd+Su) esce verso il blocco che contiene il cursore: da `image:` al servizio a cui appartiene.
- **Vai al primo figlio** (Ctrl+Cmd+Giù) entra.
- **Vai al fratello precedente / successivo** (Ctrl+Cmd+Sinistra / Destra) passa tra le voci dello stesso livello scavalcando l'intero blocco intermedio — da un server al successivo senza scorrere quaranta righe di impostazioni.
- **Seleziona il nodo contenitore** (Ctrl+Cmd+A) seleziona il blocco in cui si trova il cursore. Premetelo di nuovo e la selezione cresce fino al blocco che lo circonda, così selezionate esattamente un servizio, o esattamente un elemento, senza trascinare.
- **Copia il percorso strutturale** (Ctrl+Cmd+C) copia la posizione del cursore come un'espressione che gli strumenti del formato accettano: `.services.web.ports[0]` per JSON e YAML, che è ciò che `jq` e `yq` si aspettano, e `//server[@id='web-1']/port` per XML, cioè un XPath. Le chiavi che non sono parole semplici vengono messe tra virgolette per voi — `."content-type"` e non `.content-type`, che in `jq` significa qualcosa di completamente diverso.
- **Convalida il documento** (Ctrl+Cmd+V) controlla il file e mette il cursore **sul problema**, con il motivo nel titolo della finestra. Segnala ciò che nessun altro strumento della catena segnalerà: una chiave duplicata, che ogni parser JSON accetta in silenzio scartando uno dei due valori, e una virgola finale, che il parser di Apple accetta mentre Python, Go e `jq` la rifiutano.

I file lunghi si leggono comprimendo ciò su cui non si sta lavorando. **Comprimere il nodo** (Opzione+Cmd+Sinistra) comprime il blocco in cui si trova il cursore — il più vicino che abbia un corpo, così premendolo su una singola riga si comprime la mappatura che la circonda —, **Espandere il nodo** (Opzione+Cmd+Destra) lo riapre, **Comprimere il livello superiore** (Opzione+Cmd+Su) comprime tutto il livello più esterno per una vista d'insieme, e **Espandere tutto** (Opzione+Cmd+Giù) ripristina. La riga con la chiave o il tag resta visibile ed è contrassegnata, così un blocco compresso si vede come tale; i numeri di riga saltano ciò che è nascosto. Dal documento non viene rimosso nulla — il testo semplicemente non è disegnato, quindi salvataggio, annulla e ricerca non cambiano, e la ricerca trova ancora il testo dentro un blocco compresso. Mettere il cursore dentro una compressione la apre, e qualsiasi modifica apre tutto: una compressione è una coppia di posizioni, e inserire testo le sposta.

Lo stesso menu contiene le trasformazioni, che riscrivono l'intero documento — o, se è selezionato del testo, solo quello — in un unico passo annullabile: **Compattare (una riga)** per un corpo JSON che deve stare in un comando `curl`, **Ordinare le chiavi ricorsivamente** perché due esportazioni delle stesse impostazioni non mostrino alcuna differenza, **Convertire in stringa JSON** e **Decodificare la stringa JSON** per il lavoro quotidiano di mettere un certificato, uno script o un intero documento JSON *dentro* un campo JSON, e **Convertire JSON in YAML**. La compattazione conserva l'ordine delle chiavi e la scrittura esatta di ogni numero, perché `1.0` e `1` non sono la stessa versione; l'ordinamento no, e di proposito, dato che ordinare è un riordinamento. La conversione in stringa vale per qualsiasi file, non solo per JSON. Da YAML a JSON non c'è nulla, ed è una decisione: servirebbe un parser YAML che il sistema non ha, e un'ipotesi sbagliata su un'ancora o su un `true` fra virgolette trasforma un file di configurazione in un altro.

Per JSON e XML il file è controllato da un vero parser. Per YAML non ce n'è alcuno sul sistema, quindi il controllo copre gli errori individuabili senza parser — una tabulazione usata per indentare, che YAML vieta espressamente, un'indentazione che non corrisponde a nulla, una chiave duplicata, una virgoletta non chiusa — e lo dice, invece di dichiarare valido il file.

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
4. Premete Cmd+S per salvare. Come nell'editor di testo, il contenuto precedente viene conservato solo se avete attivato i backup.

## Le stringhe del file che state modificando

L'editor esadecimale ha lo stesso pannello **Stringhe** del visualizzatore: ogni sequenza di testo leggibile del file, in quattro codifiche insieme, e un clic vi porta cursore e selezione.

- Legge i byte come li avete modificati, non come stanno sul disco, così gli offset continuano a indicare il punto giusto dopo che un inserimento ha spostato tutto ciò che segue.
- L'elenco segue le vostre modifiche: cambiate un byte e viene ricostruito poco dopo che avete smesso di digitare.
- È descritto per intero sotto [Visualizzare i file](viewing-files.md#read-the-strings-in-a-binary) e qui si comporta allo stesso modo.

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
| Vai al nodo contenitore (JSON/YAML/XML) | Ctrl+Cmd+Su |
| Vai al primo figlio | Ctrl+Cmd+Giù |
| Vai al fratello precedente / successivo | Ctrl+Cmd+Sinistra / Destra |
| Seleziona il nodo contenitore | Ctrl+Cmd+A |
| Copia il percorso strutturale | Ctrl+Cmd+C |
| Convalida il documento | Ctrl+Cmd+V |
| Comprimere / espandere il nodo | Opzione+Cmd+Sinistra / Destra |
| Comprimere il livello superiore / espandere tutto | Opzione+Cmd+Su / Giù |
| Annulla / ripristina (editor esadecimale) | Cmd+Z / Cmd+Shift+Z |
| Filtrare la selezione con un comando | Shift+Cmd+\ |

## Note

- L'evidenziazione della sintassi copre JSON, C, C#, Java, JavaScript, TypeScript, Python e Rust. Gli altri tipi di file si aprono e si modificano comunque normalmente con una colorazione di base, ma l'evidenziazione dettagliata è disponibile solo per i linguaggi supportati.
- La struttura copre i linguaggi di programmazione supportati più JSON, YAML e XML — compresi i formati basati su XML come `.plist`, `.svg`, `.csproj` e `.storyboard`. I comandi di navigazione strutturale, percorso e convalida si applicano a JSON, YAML e XML.
- La struttura dei simboli e la funzione Vai alla riga si applicano all'editor di testo. L'editor esadecimale è pensato per l'ispezione binaria e le modifiche a livello di byte, non per il testo.
- Nessuno dei due editor conserva un backup se non lo chiedete. Attivate «Conserva una copia di backup (.bak) del contenuto precedente al salvataggio» in Impostazioni ▸ Modifica/Visualizza e il primo salvataggio scriverà l'originale accanto al file come `name.bak`, così una modifica accidentale è facile da annullare.
