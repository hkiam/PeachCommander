---
title: Uninstaller
slug: uninstaller
section: Plugin
order: 126
related: [plugins, deleting-files]
---

Trascinare un'app nel Cestino lascia i suoi file di supporto, le cache, le preferenze e i container sparsi nelle vostre cartelle Libreria. Il plugin Uninstaller rimuove un'applicazione **e** quei residui: trova tutto ciò che l'app ha lasciato dietro di sé, vi mostra l'elenco con una dimensione per ciascun elemento e sposta il tutto nel Cestino dopo la vostra conferma. Trattandosi di un plugin, potete disattivarlo o rimuoverlo da **Configurazione ▸ Plugin…**.

## Disinstallare un'app sotto il cursore

1. Posizionate il cursore su un'applicazione (`.app`) in un pannello.
2. Scegliete **File ▸ Disinstalla applicazione…**, oppure clic destro ▸ **Disinstalla applicazione…**, oppure premete **Cmd+Shift+U**.
3. Si apre la finestra di revisione, che elenca l'app più ogni file correlato trovato, ciascuno etichettato con la sua categoria, il percorso e la dimensione.
4. Deselezionate ciò che volete conservare, poi fate clic su **Sposta nel Cestino** (o **Elimina definitivamente**).

![La finestra di revisione della disinstallazione che elenca i file residui di un'app con caselle di selezione e dimensioni](screenshots/uninstaller.png)
*(Figura: rivedete esattamente cosa verrà rimosso prima che qualcosa venga eliminato.)*

## Sfogliare tutte le app installate

Scegliete **Comandi ▸ Disinstalla applicazione…** per aprire un elenco ricercabile delle app installate sul vostro Mac, con nome, dimensione e data di installazione di ciascuna app. Selezionatene una (o diverse), fate clic su **Disinstalla…** e arriverete alla stessa finestra di revisione. Potete filtrare l'elenco digitando nel campo di ricerca.

## Trovare i file residui

Scegliete **Comandi ▸ Trova file residui…** per cercare i file di supporto, le cache e le preferenze che appartengono ad app che avete **già** eliminato. Rivedeteli allo stesso modo e ripuliteli. Se non viene trovato nulla, il plugin ve lo dice.

## Quanto approfondire la scansione

La finestra di revisione ha un controllo di confidenza:

- **Precise** — file ancorati all'identificatore di bundle dell'app. Alta confidenza; preselezionati.
- **Enhanced** — aggiunge i file corrispondenti per nome; lasciati deselezionati così potete decidere.
- **Deep** — Enhanced più una scansione Spotlight per qualsiasi altra cosa che menziona l'app; anch'essi lasciati deselezionati.

## Note

- Nulla viene eliminato direttamente dal plugin — gli elementi passano per il Cestino o l'eliminazione definitiva dell'app, esattamente come qualsiasi altra operazione sui file. La rimozione di file in `/Library` o `/var` può richiedere una password di amministratore.
- Prima della rimozione, il plugin chiude l'app in esecuzione e scarica i suoi elementi in background (launchd), poi propone di riordinare eventuali cartelle di fornitori ora vuote.
- Se l'app è stata installata con **Homebrew**, il plugin vi avvisa e suggerisce `brew uninstall --cask` così Homebrew resta sincronizzato. Anche le app dell'App Store vengono segnalate.
- Le corrispondenze Enhanced e Deep sono a confidenza inferiore per progettazione e partono deselezionate — rivedetele prima di rimuoverle. Alcuni elementi in background installati tramite la moderna API degli elementi di login non possono essere rimossi qui.
