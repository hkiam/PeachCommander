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

## Anteprima rapida e Quick Look

L'Anteprima rapida mostra un'anteprima in tempo reale nel pannello che *non* stai usando, così puoi continuare a sfogliare da un lato mentre visualizzi l'anteprima dall'altro.

1. Premi Ctrl+Q. Il pannello inattivo diventa un'area di anteprima.
2. Sposta il cursore su diversi file nel pannello attivo per visualizzare l'anteprima di ciascuno.
3. Premi di nuovo Ctrl+Q, o Esc, per riportare il pannello a un normale elenco di file.

Per un'anteprima veloce a schermo intero gestita da macOS stesso, premi Cmd+Y (Quick Look). Premi di nuovo Cmd+Y o Spazio per chiuderla.

## Scorciatoie

| Azione | Scorciatoia |
| --- | --- |
| Visualizza file sotto il cursore | F3 |
| Visualizza solo il file sotto il cursore (ignora i file contrassegnati) | Maiusc+F3 |
| Apri in un visualizzatore esterno | Opzione+F3 |
| Trova nel visualizzatore | Ctrl+F |
| Corrispondenza successiva / precedente | F3 / Maiusc+F3 |
| Anteprima rapida nell'altro pannello | Ctrl+Q |
| Quick Look (anteprima macOS) | Cmd+Y |
| Chiudi il visualizzatore o l'Anteprima rapida | Esc |

## Note

- Il visualizzatore è di sola lettura. Per modificare un file, usa invece l'editor (vedi Modifica dei file).
- I file molto grandi si aprono senza ritardo: il testo apre una vista rapida e scorrevole, e la vista esadecimale viene trasmessa direttamente dal disco a qualsiasi dimensione.
- Premi F3 su una cartella per vedere un riepilogo del suo contenuto e la dimensione totale invece dei byte del file.
- La modalità Renderizzato mostra contenuti formattati come le pagine web; la modalità esadecimale mostra i byte grezzi affiancati ai loro caratteri, il che è comodo per esaminare file binari.
