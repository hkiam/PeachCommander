---
title: Visualizzazione dei file
slug: viewing-files
section: Visualizzazione e modifica
order: 70
related: [editing-files, searching]
---

Peach Commander ha un visualizzatore integrato che ti permette di guardare dentro un file senza aprire un'altra app o modificare il file. Premi F3 sull'elemento sotto il cursore e il visualizzatore si apre all'istante, anche per file molto grandi. Sceglie automaticamente il modo migliore di mostrare il contenuto: testo leggibile, codice con colorazione della sintassi, un dump esadecimale grezzo o un'immagine a dimensione piena. Puoi anche visualizzare un'anteprima di un file proprio dentro la finestra usando l'Anteprima rapida, o affidarlo a Quick Look di macOS.

## Visualizza un file

1. Sposta il cursore su un file nel pannello attivo.
2. Premi F3 (o scegli Visualizza nel menu File). Il visualizzatore si apre in una propria finestra.
3. Usa la barra degli strumenti per cambiare come viene mostrato il contenuto: Testo, Codice, Hex, Immagine o Renderizzato. Lascialo sull'impostazione automatica per lasciar decidere a Peach Commander.
4. Scorri con i tasti freccia, Pag su/Pag giù e la barra di scorrimento. Per testi lunghi, attiva il pulsante della minimappa per vedere e spostarti nell'intero file con un colpo d'occhio.
5. Premi N per saltare al file selezionato successivo, o chiudi la finestra con Esc.

![Il visualizzatore integrato che mostra un file di testo con la minimappa a destra](screenshots/lister-text.png)
*(Figura: visualizzazione di un file di testo, con il selettore di rappresentazione e la minimappa nella barra degli strumenti.)*

## Trova testo e cambia la codifica

- Premi Ctrl+F per cercare dentro il file. Premi F3 per saltare alla corrispondenza successiva e Maiusc+F3 per quella precedente.
- Se il testo appare confuso, fai clic su Codifica nella barra degli strumenti (o premi E) per scorrere le codifiche di testo finché non si legge correttamente; l'impostazione automatica di solito è corretta.
- Premi W per commutare l'a capo automatico per le righe lunghe.

## Note su una riga

Se il plugin Note è installato, una nota può riguardare una riga precisa di un file anziché il file nel suo insieme.

- Porta il cursore sulla riga e scegli **Vista ▸ Nota per questa riga…** (Cmd+Maiusc+N). L'editor delle note si apre con il nome del file e il numero di riga nel titolo.
- Le righe che hanno già una nota compaiono come gruppo **Note** nel pannello dei segni in fondo alla finestra, accanto ai risultati di ricerca. Cmd+Ctrl+M apre il pannello; un doppio clic su una voce salta a quella riga.
- Le note stanno insieme a tutte le altre, quindi il riepilogo delle note e Cerca file le trovano come qualsiasi altra. Si eliminano nell'editor delle note: il pulsante di chiusura del pannello si limita a nascondere il gruppo.

## Anteprima rapida e Quick Look

L'Anteprima rapida mostra un'anteprima in tempo reale nel pannello che *non* stai usando, così puoi continuare a sfogliare da un lato mentre visualizzi l'anteprima dall'altro.

1. Premi Ctrl+Q. Il pannello inattivo diventa un'area di anteprima.
2. Sposta il cursore su diversi file nel pannello attivo per visualizzare l'anteprima di ciascuno.
3. Premi di nuovo Ctrl+Q, o Esc, per riportare il pannello a un normale elenco di file.

Per un'anteprima veloce a schermo intero gestita da macOS stesso, premi Cmd+Y (Quick Look). Premi di nuovo Cmd+Y o Spazio per chiuderla.

## La pagina Informazioni del pannello laterale

Il pannello laterale (**Vista > Pannello anteprima**, oppure Cmd+Maiusc+P) ha una pagina **Informazioni** che mostra l’elemento sotto il cursore come fa la barra laterale delle informazioni del Finder.

- L’anteprima occupa tutta la larghezza del pannello: allargando il pannello, l’anteprima cresce con esso. Trascinate il bordo sinistro del pannello per allargarlo o restringerlo; la larghezza viene ricordata.
- È una vera anteprima di macOS, non una piccola miniatura: funziona ogni formato che Vista Rapida sa mostrare, e un documento di più pagine si sfoglia pagina per pagina dentro l’anteprima.
- Sotto compaiono nome, tipo e dimensione, poi quando l’elemento è stato creato e modificato e in quale cartella si trova.

Spostando il cursore, nome e dati si aggiornano subito; l’anteprima segue un istante dopo, così tenere premuta una freccia lungo una cartella lunga non avvia un’anteprima per ogni riga attraversata.

## Decompilare file .class Java

Con il modulo **Java Decompiler** attivo, F3 su un file `.class` mostra codice leggibile invece di dati binari — anche per le classi dentro un JAR o uno ZIP, in cui potete entrare e che potete leggere senza scompattarlo.

Il modulo non contiene alcun decompilatore proprio. Pilota un motore che installate voi, e potete cambiarlo in qualsiasi momento:

- **CFR** (licenza MIT) e **Vineflower** (Apache 2.0) producono sorgente Java. Mettete `cfr.jar` o `vineflower.jar` nella cartella dei motori.
- **Procyon** (Apache 2.0) è un terzo decompilatore verso il sorgente.
- **javap** non richiede alcun download: fa parte di qualsiasi JDK e mostra bytecode anziché sorgente Java.

Non viene scaricato nulla per voi: sono programmi di terzi con licenze proprie, e Peach Commander non li scarica né li aggiorna. Il pulsante **Cartella dei motori…** nel visualizzatore apre la cartella a cui sono destinati e vi lascia una nota con il nome di ogni motore e dove ottenerlo. Tutti tranne javap richiedono Java installato.

Cambiate motore con il menu in cima al visualizzatore; quello scelto viene usato subito e il risultato viene conservato, così confrontare due motori sullo stesso file è immediato.

Il sorgente è evidenziato sintatticamente, e due pulsanti fanno di più: **Registra come…** lo scrive in un file e **Apri nell’editor** lo consegna a ciò che apre i `.java` sul vostro Mac. Un risultato molto grande viene mostrato senza evidenziazione per comparire subito anziché dopo una pausa; la riga di stato lo segnala.

I risultati sono messi in cache su disco, così riaprire un file già visto è immediato; la chiave comprende dimensione e data del file e gli argomenti del motore, quindi una classe ricompilata o un’opzione modificata viene decompilata di nuovo. Il motore scelto viene ricordato per tipo di file. Un profilo può ereditare da un motore integrato con `extends = cfr` e ridefinire solo le opzioni — comodo se tenete due preimpostazioni dello stesso motore.

Attivate **Confronta** per aprire un secondo pannello con il proprio menu del motore. Due decompilatori sbagliano in punti diversi, quindi vederli affiancati è spesso più rapido che decidere di quale fidarsi; scegliendo `javap` da un lato, il bytecode sta accanto al sorgente. I due pannelli condividono la cache, così passare tra motori già eseguiti è immediato.

F3 su un `.jar`, `.apk` o `.dex` intero lo decompila tutto in una volta e mostra un albero di package accanto al sorgente. Il campo di ricerca sopra l’albero cerca in ogni classe — proprio la domanda a cui una singola classe non può rispondere: dove una stringa, una chiamata o una costante compare davvero, quando non si sa ancora in quale classe. Le corrispondenze restringono l’albero e la prima si apre alla sua riga. Con Invio il JAR si apre ancora come archivio: i due verbi restano distinti.

C’è una seconda via, più diretta: mettete il cursore su un file `.class` o su un intero archivio e scegliete **Decompila in sorgenti** (menu Comandi, menu contestuale o ⌘⇧J). Le classi vengono decompilate e il risultato si apre nell’altro pannello come normali file `.java`. Da lì vale tutto il file manager: F3 li mostra con l’evidenziazione Java di Peach Commander, Alt+F7 cerca fra di essi, F5 li copia fuori, e potete confrontarli o etichettarli come qualsiasi altra cosa. Per la maggior parte del lavoro questo batte una finestra a sé; per questo l’albero del plugin si può disattivare in Impostazioni ▸ Decompilatore.

Un secondo plugin fa lo stesso per .NET: F3 su un `.dll`, `.exe` o `.winmd` gestito mostra i suoi tipi come C#, **Decompila l’assembly in sorgenti** (⌘⇧N) li mette in un pannello, e la ricerca può guardare dentro un assembly nello stesso modo. Guida **ILSpy** (MIT, `dotnet tool install -g ilspycmd`) per il sorgente, o **monodis** di Mono per l’IL — il corrispettivo .NET di `javap`. Un `.dll` nativo ha la stessa estensione e nessun sorgente da mostrare: il plugin lo verifica prima di aprire e lo lascia al visualizzatore integrato.

La pagina delle impostazioni ha un pulsante **Controlla motori**, e vale la pena premerlo: «installato» altrove significa solo che il file c'è, e un motore Java su un Mac senza JDK è presente e non può funzionare. Il controllo chiede a ogni motore la sua versione e dice quali funzionano davvero.

Anche Android è coperto: F3 su un file `.dex` usa **jadx** (Apache 2.0, `brew install jadx`), che riporta il bytecode Dalvik a Java. È bastata una descrizione di motore — stesso meccanismo, formato diverso.

Il modulo è **spento finché non lo accendete**, in Impostazioni ▸ Moduli: quasi nessuno apre un file .class, e senza motore non serve.

Per aggiungere un motore vostro, create `decompilers.ini` nella cartella dei motori:

```ini
[myengine]
name   = My Decompiler
kinds  = class
tool   = java
args    = -jar {engine} {input}
engine  = my-decompiler.jar   ; a bare name is looked up in this folder
output  = stdout
timeout = 30                  ; seconds before the engine is stopped
```

`{input}`, `{engine}` e `{outdir}` vengono sostituiti all’esecuzione. Le vostre voci hanno la precedenza su quelle integrate, e riusare un nome integrato (`cfr`, `vineflower`, `procyon`, `javap`) lo sostituisce invece di aggiungere una seconda voce.

## Scorciatoie

| Azione | Scorciatoia |
| --- | --- |
| Visualizza file sotto il cursore | F3 |
| Visualizza solo il file sotto il cursore (ignora i file contrassegnati) | Maiusc+F3 |
| Apri in un visualizzatore esterno | Opzione+F3 |
| Trova nel visualizzatore | Ctrl+F |
| Nota per la riga sotto il cursore | Cmd+Maiusc+N |
| Mostrare o nascondere il pannello dei segni | Cmd+Ctrl+M |
| Corrispondenza successiva / precedente | F3 / Maiusc+F3 |
| Anteprima rapida nell'altro pannello | Ctrl+Q |
| Quick Look (anteprima macOS) | Cmd+Y |
| Chiudi il visualizzatore o l'Anteprima rapida | Esc |

## Note

- Il visualizzatore è di sola lettura. Per modificare un file, usa invece l'editor (vedi Modifica dei file).
- I file molto grandi si aprono senza ritardo: il testo apre una vista rapida e scorrevole, e la vista esadecimale viene trasmessa direttamente dal disco a qualsiasi dimensione.
- Premi F3 su una cartella per vedere un riepilogo del suo contenuto e la dimensione totale invece dei byte del file.
- La modalità Renderizzato mostra contenuti formattati come le pagine web; la modalità esadecimale mostra i byte grezzi affiancati ai loro caratteri, il che è comodo per esaminare file binari.
- In modalità Renderizzato potete selezionare e copiare testo, e Trova cerca nella pagina renderizzata. I pulsanti non applicabili a una pagina renderizzata — Formatta, Codifica, Seleziona tutto, Selezioni e Vai a — sono disattivati anziché restare senza effetto.
- Il pulsante Formatta rientra di nuovo i file strutturati (JSON, XML, HTML, INI, YAML e altri se avete installato il relativo strumento a riga di comando). È descritto per intero in [Modificare i file](editing-files.md#formatting-a-file) e qui funziona allo stesso modo.
