---
title: System Monitor
slug: system-monitor
section: Plugin
order: 124
related: [plugins, settings]
---

Il plugin System Monitor mette una lettura in tempo reale dell'attività del vostro Mac direttamente nella barra del titolo della finestra: piccoli chip per processore, memoria, disco, rete e — dove l'hardware li espone — GPU, batteria e sensori. Ogni chip si aggiorna una volta al secondo; fate clic su uno per una finestra a comparsa con un grafico della cronologia e un dettaglio approfondito. Trattandosi di un plugin, potete abilitarlo, configurarlo o rimuoverlo da **Configurazione ▸ Plugin…**.

## I chip nella barra del titolo

Quando il plugin è attivo, una riga di chip compatti si trova nella barra del titolo. Ogni chip è un pallino colorato, una breve etichetta e un valore in tempo reale (alcuni con uno sparkline in linea):

| Chip | Mostra |
| --- | --- |
| **CPU** | Carico del processore, con dettaglio per core |
| **RAM** | Memoria usata / totale (più wired, compressa, swap) |
| **HDD** | Spazio del volume di avvio e velocità di lettura/scrittura |
| **Net** | Velocità e totali di download / upload |
| **GPU** · **Batt** · **Sens** | Utilizzo della GPU · carica e stato della batteria · velocità delle ventole e temperature |

Fate clic su un chip per aprire una finestra a comparsa con il grande valore corrente, uno sparkline **HISTORY**, un elenco chiave/valore **DETAILS** e — per la CPU — un elenco **CORE LOAD** di barre per core.

## Configurarlo

Scegliete **Comandi ▸ System Monitor…** (o aprite **Configurazione ▸ Impostazioni ▸ System Monitor**) per configurare la lettura:

- **Mostra il monitor di sistema nella barra del titolo** — l'interruttore principale per i chip.
- **Profilo** — le preimpostazioni *Minimal*, *Medium* o *Maximal* che scelgono un insieme sensato di moduli.
- **La tabella dei moduli** — attivate o disattivate ogni modulo (CPU, GPU, RAM, HDD, Net, Batt, Sens), sceglietene il colore e trascinate le righe per impostare l'ordine in cui compaiono nella barra del titolo. I moduli che il vostro hardware non può riportare sono mostrati come *(n/a)*.

![Le impostazioni di System Monitor con la sua tabella dei moduli, i profili e i colori per modulo](screenshots/system-monitor.png)
*(Figura: scegliete quali moduli compaiono, i loro colori e il loro ordine.)*

## Note

- Tutto è misurato, mai inventato: i moduli i cui dati l'hardware non espone (spesso GPU o sensori su alcuni Mac) restano non disponibili invece di mostrare numeri inventati. La batteria non è disponibile sui computer desktop.
- Il campionamento gira su un timer in background solo mentre la lettura è visibile, e conserva circa 30 minuti di cronologia per i grafici.
- Le vostre scelte di moduli, i colori e l'ordine vengono salvati insieme alla configurazione dell'app.
