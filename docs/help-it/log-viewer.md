---
title: Il visualizzatore di log
slug: log-viewer
section: Plugin
order: 128
related: [plugins, viewing-files, searching]
---

Mettete il cursore su un file di log e scegliete **Mostra come log…** per aprirlo in una finestra pensata per i log e non per il testo: una riga per riga, il livello di ciascuna riconosciuto e colorato, un filtro, e un inseguimento che tiene il passo mentre il file è ancora in scrittura.

È un plugin: potete disattivarlo o rimuoverlo in **Configurazione ▸ Plugin…**. Senza di esso, F3 mostra un log come qualsiasi altro file di testo.

## Perché si apre all’istante

Il file viene mappato in memoria e si costruisce solo un indice di dove comincia ogni riga, in background. Nulla viene caricato come testo prima di essere sullo schermo, e solo le righe realmente visibili vengono decodificate. Un log di più gigabyte si apre veloce quanto uno piccolo, e andare alla fine non legge il mezzo.

## Livelli e colore

Ogni riga viene classificata — **Errore**, **Avviso**, **Info**, **Debug**, **Traccia**, oppure **Sconosciuto** quando il formato non dice nulla — e colorata di conseguenza. I colori predefiniti seguono l’aspetto chiaro o scuro; impostate i vostri nelle preferenze del plugin e verranno usati quelli.

La colonna **Livello** mostra a colpo d’occhio dove stanno gli errori, e il campo del filtro restringe l’elenco a ciò che cercate. Attivate **Regex** per filtrare con un’espressione regolare anziché con testo semplice.

## Seguire un file che sta ancora crescendo

Attivate **Dal vivo (scorrimento automatico)** e la finestra segue la fine del file mentre arrivano nuove righe: l’indice viene esteso sui byte aggiunti invece di essere ricostruito, quindi resta economico per quanto lungo diventi il file. Scorrete in su e state leggendo il passato; l’inseguimento continua sotto.

## Orientarsi

| | |
| --- | --- |
| **Trova…** | Cerca nei messaggi; **Trova (marca e vai)…** marca ogni occorrenza così da poterle percorrere |
| **Vai alla riga…** | Salta a un numero di riga fisico |
| **Vai a data/ora…** | Salta alla prima riga a partire da un timestamp, ad es. `2024-01-15 10:23:45` |

La copia sa cos’è una riga di log: **Copia riga** prende la riga sotto il cursore, **Copia voce (tutte le righe)** prende l’intera voce quando ne occupa più d’una — una traccia dello stack, per esempio — e **Copia righe selezionate** prende esattamente ciò che avete selezionato.

## Formati

**log4j**, **log4net** e **CSV** sono integrati, e il formato viene riconosciuto automaticamente; la finestra mostra su quale si è fermata. Se i vostri log non sono nessuno di questi, aggiungete il vostro sotto **Formati di log** nelle preferenze: un’espressione regolare con gruppi denominati per le parti che contano.

```
(?<time>…)   (?<level>…)   (?<msg>…)
```

Una riga che l’espressione non riconosce compare comunque: viene semplicemente classificata come Sconosciuto anziché scartata, perché un log che non si può leggere è peggio di un log senza colori.

## Visualizzazione

**Mostra i numeri di riga** e **Manda a capo le righe lunghe** sono nelle preferenze. L’area di dettaglio sotto l’elenco mostra sempre il testo completo della voce selezionata, mandato a capo, qualunque cosa faccia l’elenco.
