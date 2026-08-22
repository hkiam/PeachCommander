---
title: Decompilare Java e .NET
slug: decompilers
section: Plugin
order: 131
related: [plugins, viewing-files, searching]
---

Premete **F3** su un file compilato e vedrete codice sorgente invece di byte. Lo fanno due plugin — uno per Java (`.class`, `.jar`, `.apk`, `.dex`) e uno per .NET (`.dll`, `.exe`, `.winmd`, `.netmodule`) — e si comportano allo stesso modo, perciò questa pagina copre entrambi. Ciascuno si può disattivare o rimuovere per conto suo in **Configurazione ▸ Plugin…**.

Un archivio compare come albero delle sue classi; una singola classe come un file. **Decompila nei sorgenti** nel menu Comandi scrive il risultato e lo mette in un pannello, così potete cercarci dentro, confrontare e copiare come in qualsiasi altra cartella di sorgenti.

## Il motore lo installate voi

Nessun decompilatore è incluso e nulla viene scaricato per voi. È voluto, per due ragioni: JD-Core, il decompilatore Java più noto, è GPLv3 e non poteva essere distribuito dentro un’app Apache-2.0 — e i motori migliorano, quindi sostituirne uno non dovrebbe richiedere una nuova versione di Peach Commander.

**Cartella dei motori…** nel visualizzatore apre la cartella a cui appartengono. Il README lì dentro nomina ogni motore e la sua licenza.

| | |
| --- | --- |
| Java | CFR, Vineflower, Procyon, jadx (per `.dex` e `.apk` Android) e `javap` per il bytecode puro |
| .NET | ILSpy e `monodis` per l’IL |

**Verifica i motori** esegue il comando di versione di ciascun motore e distingue tre cose: installato e funzionante, non installato, e *installato ma incapace di partire* — uno strumento Java senza JDK è presente e comunque non si avvia, e solo eseguendolo davvero lo si scopre.

Un motore è descritto da dati e non da codice, quindi potete aggiungerne uno voi stessi:

```
[cfr]
kinds  = class, jar
tool   = java
args   = -jar {engine} {input}
engine = ~/Library/Application Support/PeachCommander/decompilers/cfr.jar
output = stdout
```

Quando più motori possono gestire un file, si usa il primo disponibile a meno che non ne scegliate uno. Con due installati, **Confronta** mostra entrambi i risultati affiancati — utile quando un motore rinuncia su un metodo che l’altro riesce a gestire.

## Cercare dentro codice compilato

**Cerca in tutte le classi** scorre il testo decompilato invece dei byte, così potete trovare una stringa letterale o il nome di un metodo dentro un JAR.

Decompilare durante una *ricerca nei contenuti* su molti file è un’impostazione separata, disattiva per impostazione predefinita: produrre il testo può voler dire eseguire il motore una volta per classe, il che su una macchina lenta non è una cosa ragionevole da spendere per una ricerca. La finestra di ricerca principale lo chiede a parte; anche qui viene rifiutato.

## Cache e limiti

I risultati vengono messi in cache, perché decompilare due volte la stessa classe è solo attesa. Nelle preferenze ci sono per quanti giorni conservare i risultati e un **limite di dimensione** per la cache; **Svuota la cache adesso** la svuota e riferisce quanto ha liberato.

Due timeout proteggono da un motore che non finisce: uno per una singola classe o tipo, uno per un intero archivio. Entrambi accettano 0, che significa «usa il valore predefinito del motore».
