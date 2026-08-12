---
title: La finestra principale
slug: interface-overview
section: Per iniziare
order: 12
related: [navigating, panels-and-tabs]
---

Peach Commander mostra due elenchi di file affiancati, così puoi vedere allo stesso tempo da dove provengono i file e dove stanno andando. La maggior parte del tuo lavoro avviene in questi due pannelli; le barre attorno a essi ti permettono di cambiare disco, saltare a una cartella ed eseguire i comandi file più comuni senza lasciare la tastiera. Questa panoramica nomina ogni parte della finestra, in modo che il resto dell'aiuto abbia senso.

![La finestra principale di Peach Commander con i suoi due pannelli e le barre circostanti](screenshots/main-window.png)
*(Figura: la finestra principale — due pannelli con la barra dei pulsanti, la barra dei dischi e le barre del percorso sopra e la barra dei tasti funzione sotto.)*

## I due pannelli e il pannello attivo

La finestra è divisa in un pannello sinistro e un pannello destro, ciascuno che mostra il contenuto di una cartella. Solo un pannello è attivo alla volta: mostra il cursore (una riga evidenziata) e la sua barra del percorso è disegnata con uno sfondo colorato. Comandi come copia e sposta agiscono sempre sul pannello attivo e inviano i file all'altro.

1. Fai clic in un punto qualsiasi di un pannello per renderlo attivo, o premi Tab per passare dall'uno all'altro.
2. Usa i tasti freccia per spostare il cursore su e giù nel pannello attivo.
3. Premi Invio su una cartella per aprirla, o su `..` in cima all'elenco per salire di un livello.

## Le barre attorno ai pannelli

- **Barra dei pulsanti** (in alto): una fila di pulsanti piatti per i comandi frequenti. Fai clic su un pulsante per eseguire il suo comando; fai clic destro su un pulsante per modificare la barra.
- **Barra dei dischi**: un pulsante per ogni disco o volume disponibile, ciascuno con il suo spazio libero. Fate clic su un volume per portarci quel pannello; con un clic destro lo espellete — proposto per volumi rimovibili e immagini disco montate, in grigio per il disco di avvio e le condivisioni di rete. I plugin possono aggiungere dischi propri — il Task Manager è uno di questi — e si comportano come qualsiasi altro volume: il pannello ci passa, il pulsante resta selezionato e la scheda prende il nome del disco.
- **Barra del percorso**: mostra la cartella corrente come un percorso di navigazione cliccabile. Fai clic su un segmento per saltare direttamente a quella cartella, o fai clic sul percorso per digitare una posizione.
- **Barra di stato** (sotto ogni elenco): un riepilogo aggiornato del pannello — quanti file e cartelle sono selezionati e la loro dimensione totale.
- **Riga di comando** (in basso): un campo di testo dove puoi digitare un comando in stile shell che viene eseguito nella cartella corrente.
- **Barra dei tasti funzione** (in fondo): sei pulsanti etichettati F3 Visualizza, F4 Modifica, F5 Copia, F6 Sposta, F7 NuovaCartella e F8 Elimina. Fai clic su un pulsante o premi il tasto corrispondente.

![Primo piano della barra dei dischi che mostra i pulsanti dei volumi e lo spazio libero](screenshots/drive-bar-crop.png)
*(Figura: la barra dei dischi — un pulsante per volume, con lo spazio libero rimanente; un clic destro su un volume lo espelle.)*

## Scorciatoie

| Azione | Scorciatoia |
|---|---|
| Cambia pannello attivo | Tab |
| Apri cartella / elemento sotto il cursore | Invio |
| Sali di una cartella | Backspace |
| Visualizza file | F3 |
| Modifica file | F4 |
| Copia nell'altro pannello | F5 |
| Sposta / rinomina nell'altro pannello | F6 |
| Nuova cartella | F7 |
| Elimina (nel Cestino) | F8 |

## Note

- La barra dei tasti funzione si rietichetta in tempo reale quando tieni premuto un modificatore. Tenendo premuto Maiusc, per esempio, F6 cambia in un'azione di rinomina sul posto, così i pulsanti mostrano sempre cosa faranno i tasti in quel momento.
- Quasi ogni barra può essere mostrata o nascosta. Guarda nei menu Vista e Configurazione per attivare e disattivare la barra dei pulsanti, la barra dei dischi, la riga di comando o la barra dei tasti funzione, o per impilare i due pannelli sopra e sotto invece che affiancati.
- Su molte tastiere Mac i tasti F fungono per impostazione predefinita da controlli multimediali e di luminosità. Tieni premuto il tasto Fn insieme a F3-F8, o attiva "Usa i tasti F1, F2, ecc. come tasti funzione standard" in Impostazioni di Sistema, per usarli direttamente.
