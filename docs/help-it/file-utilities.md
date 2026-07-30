---
title: Utility per i file
slug: file-utilities
section: Strumenti avanzati
order: 94
related: [comparing-and-syncing]
---

Oltre alla copia e allo spostamento, Peach Commander include una serie di utility quotidiane per i file per verificare che i file siano integri, recuperare spazio su disco, suddividere file di grandi dimensioni in parti più piccole e convertire i file da e verso formati sicuri per il testo. Le raggiungete tutte dal menu **File** e agiscono su qualunque cosa abbiate selezionato nel pannello attivo (o sull'elemento sotto il cursore quando non è selezionato nulla). Questo argomento tratta i checksum, il ricercatore di duplicati, dividi/combina, codifica/decodifica e il calcolo dello spazio occupato.

## Creare o verificare i checksum

I checksum vi permettono di confermare che un file è stato scaricato o copiato senza corruzione, oppure di fornire a un destinatario un modo per controllare la copia ricevuta.

1. Selezionate i file di cui volete calcolare l'impronta.
2. Scegliete **File ▸ Crea checksum…**, scegliete un algoritmo (CRC32, MD5, SHA-1, SHA-256 o SHA-512) e salvate il file di checksum.
3. Per controllare i file in seguito, selezionate il file di checksum e scegliete **File ▸ Verifica checksum…**. Peach Commander ricalcola ogni hash e segnala qualsiasi file che non corrisponde.

I checksum vengono elaborati in streaming direttamente sulla posizione corrente, quindi potete crearli o verificarli anche per i file all'interno di archivi o su un server FTP.

## Trovare i file duplicati

Il ricercatore di duplicati individua i file identici sparsi tra le cartelle così potete rimuovere le copie in eccesso.

1. Selezionate le cartelle (o i file) da analizzare.
2. Scegliete **File ▸ Trova duplicati…**. Peach Commander confronta i candidati e raggruppa i file identici byte per byte.
3. Esaminate ogni gruppo, contrassegnate le copie che non vi servono più ed eliminatele.

![Il ricercatore di duplicati che elenca gruppi di file identici](screenshots/duplicate-finder.png)
*(Figura: il ricercatore di duplicati raggruppa i file identici così potete tenerne uno e rimuovere il resto.)*

## Dividere e combinare i file

La divisione spezza un file di grandi dimensioni in una serie numerata di parti più piccole — comoda per i limiti di archiviazione o di trasferimento. La combinazione le riassembla.

1. Per dividere, selezionate un file e scegliete **File ▸ Dividi file…**, poi impostate la dimensione delle parti. Le parti vengono scritte nella cartella dell'altro pannello.
2. Per riassemblare, selezionate la prima parte e scegliete **File ▸ Combina file…**. Il file originale viene ricostruito dalle parti numerate.

## Codificare e decodificare

La codifica trasforma un file binario in testo semplice così sopravvive a canali che trasportano solo testo (ad esempio, la posta elettronica più datata o le caselle di incollaggio). La decodifica la inverte.

1. Selezionate un file e scegliete **File ▸ Codifica…**, poi scegliete un formato — MIME (Base64), UUE (uuencode) o XXE.
2. Per ripristinare l'originale, selezionate il file codificato e scegliete **File ▸ Decodifica…**. Il formato viene rilevato automaticamente.

## Calcolare lo spazio occupato

Per vedere quanto spazio occupa realmente su disco una cartella o una selezione, selezionate gli elementi e premete **Ctrl+L** (**File ▸ Calcola spazio occupato…**). Peach Commander somma ogni file al loro interno, incluse le sottocartelle, e mostra il totale.

## Scorciatoie

| Azione | Tasto |
| --- | --- |
| Calcolare lo spazio occupato | Ctrl+L |

## Note

- I checksum, dividi/combina e codifica/decodifica sono rivolti ad attività più avanzate, ma ciascuno è un'unica finestra di dialogo con impostazioni predefinite sensate.
- Quando un'utility produce nuovi file (parti divise, un file codificato, un elenco di checksum), questi vengono scritti nella cartella mostrata nell'altro pannello — impostate prima quel pannello sulla destinazione desiderata.
- L'eliminazione dei duplicati è definitiva a seconda delle vostre impostazioni di eliminazione; esaminate attentamente ogni gruppo e conservate almeno una copia di qualsiasi cosa vi serva ancora.
