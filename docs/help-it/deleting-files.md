---
title: Eliminare i file
slug: deleting-files
section: File e cartelle
order: 28
related: [copying-files]
---

Quando non avete più bisogno di file o cartelle, Peach Commander può spostarli nel Cestino così da poterli recuperare in seguito, oppure eliminarli definitivamente per liberare spazio subito. Le eliminazioni agiscono sulla selezione corrente nel pannello attivo; se non è contrassegnato nulla, viene eliminato l'elemento sotto il cursore.

## Come eliminare i file

1. Nel pannello attivo, contrassegnate i file e le cartelle da rimuovere. Se non contrassegnate nulla, viene usato l'elemento sotto il cursore.
2. Premete **F8** (o il tasto **Delete**) per spostare la selezione nel Cestino. Per sceglierlo dal menu, usate **File > Elimina**.
3. Se appare una conferma, esaminate l'elenco degli elementi e fate clic su **Elimina** per continuare, oppure su **Annulla** per interrompere.

Gli elementi inviati al Cestino vi restano finché non lo svuotate, così potete ripristinarli dal Finder se cambiate idea.

## Come eliminare definitivamente

1. Contrassegnate i file e le cartelle da rimuovere.
2. Premete **Shift+F8**, oppure scegliete **File > Elimina definitivamente**.
3. Confermate l'eliminazione. Questo ignora il Cestino, quindi gli elementi scompaiono immediatamente e non possono essere recuperati.

Se alcuni elementi non possono essere rimossi — ad esempio perché sono bloccati o non avete i permessi — Peach Commander vi indica quali non sono riusciti e vi consente di riprovare oppure di saltarli e continuare con il resto.

## Scorciatoie

| Azione | Scorciatoia |
| --- | --- |
| Eliminare nel Cestino | F8 o Delete |
| Eliminare definitivamente | Shift+F8 |

## Note

- **Conferma.** Per impostazione predefinita Peach Commander vi chiede di confermare prima di eliminare. Potete disattivarlo in **Configurazione > Conferma** deselezionando **Conferma prima di eliminare**. Anche così, trattate le eliminazioni definitive con cautela, poiché non possono essere annullate.
- **Comportamento predefinito di F8.** Normalmente F8 sposta gli elementi nel Cestino. Se preferite che F8 elimini definitivamente per impostazione predefinita, modificate l'opzione di eliminazione nelle impostazioni **Configurazione > Operazioni**. Shift+F8 elimina sempre definitivamente indipendentemente da questa impostazione.
- **Eliminazione all'interno degli archivi.** Quando state navigando all'interno di un archivio supportato, l'eliminazione rimuove gli elementi selezionati dall'archivio. Le posizioni di sola lettura, come alcune cartelle di rete o di plugin, non possono essere modificate in questo modo.
- **Cartelle.** Eliminare una cartella rimuove tutto ciò che contiene. Assicuratevi di aver selezionato gli elementi giusti prima di confermare, soprattutto per un'eliminazione definitiva.
