---
title: File CSV come tabella
slug: csv-lister
section: Plugins
order: 129
related: [plugins, viewing-files, log-viewer]
---

Premete **F3** su un file `.csv` o `.tsv` e si apre come una vera tabella — colonne, intestazioni, ordinamento e filtro — invece che come righe di testo con delle virgole.

È un plugin: potete disattivarlo o rimuoverlo in **Configurazione ▸ Plugin…**. Senza di esso, F3 mostra il file come testo semplice, il che per uno piccolo resta perfettamente leggibile.

## Il delimitatore viene dedotto, non presunto

Virgola, punto e virgola, tabulazione, barra verticale e due punti sono tutti candidati. Il plugin conta ciascuno di essi sulle prime venti righe e sceglie quello che compare lo stesso numero di volte sul maggior numero di righe: un file in cui ogni riga ha quattro punti e virgola è un file a punto e virgola, qualunque cosa dica l’estensione. Nella pratica conta: un `.csv` esportato da un foglio di calcolo su un sistema italiano è di solito separato da punti e virgola, e un `.tsv` non è sempre separato da tabulazioni.

La prima riga è trattata come riga di intestazione e diventa i titoli delle colonne.

## Ordinare e filtrare

Fate clic su un’intestazione di colonna per ordinare in base a essa, di nuovo per invertire. L’ordinamento è **numerico quando entrambi i valori sono numeri** e alfabetico altrimenti, così una colonna di dimensioni ordina 9 prima di 10 e non dopo.

Il campo di ricerca filtra mentre scrivete, senza distinguere maiuscole e minuscole. Per impostazione predefinita guarda in tutte le colonne; scegliete una colonna dal menu accanto per guardare solo lì.

## Ciò che non fa

L’analizzatore è volutamente minimo, e un limite vale la pena conoscerlo prima che vi sorprenda: **un delimitatore dentro un campo tra virgolette viene comunque trattato come delimitatore.** Una riga come

```
"Smith, John",42
```

diventa tre celle invece di due. Le virgolette esterne vengono rimosse quando racchiudono un campo intero, ma oltre a questo il quoting non viene interpretato. Per un file in cui la cosa conta, il visualizzatore integrato o un foglio di calcolo è lo strumento migliore.

Le righe vuote vengono saltate, e un campo che si estende su più righe non è supportato.
