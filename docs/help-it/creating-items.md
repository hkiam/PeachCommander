---
title: Nuove cartelle e file
slug: creating-items
section: File e cartelle
order: 30
related: [opening-files]
---

Quando organizzate i file, spesso vi serve un nuovo posto dove metterli o un documento nuovo da cui partire. Peach Commander vi permette di creare una nuova cartella o un nuovo file di testo direttamente nel pannello in cui state lavorando, senza passare al Finder. I nuovi elementi vengono creati nella cartella attualmente mostrata nel pannello attivo.

## Creare una nuova cartella

1. Fate clic sul pannello in cui volete che appaia la nuova cartella affinché diventi il pannello attivo.
2. Premete F7.
3. Digitate un nome nella casella che appare.
4. Premete Return (o fate clic su OK). La nuova cartella appare nel pannello, pronta all'uso.

Potete fare di più che creare una singola cartella in un solo passaggio:

- **Cartelle annidate in una volta.** Digitate un percorso con barre, come `a/b/c`, per creare una cartella `a` che contiene `b` che contiene `c`. Tutti i livelli che non esistono ancora vengono creati automaticamente.
- **Più cartelle contemporaneamente.** Separate i nomi con una barra verticale, come `d1|d2`, per creare sia `d1` sia `d2` affiancate. Potete combinare entrambi gli stili, ad esempio `reports/2026|archive`.

## Creare un nuovo file di testo

1. Fate clic sul pannello in cui volete che appaia il nuovo file.
2. Premete Shift+F4.
3. Digitate un nome per il file, inclusa la sua estensione (ad esempio `notes.txt`).
4. Premete Return. Il file vuoto viene creato e si apre nel vostro editor così potete iniziare subito a digitare.

Il file si apre nell'editor che Peach Commander è impostato a usare per quel tipo di file. Vedi **Apertura e visualizzazione dei file** per come funziona la modifica.

## Scorciatoie

| Azione | Tasto |
| --- | --- |
| Nuova cartella | F7 |
| Nuovo file di testo | Shift+F4 |

## Note

- Su macOS il nome di una cartella o di un file può contenere quasi qualsiasi carattere. Solo la barra `/` (usata come separatore di percorso per le cartelle annidate) e alcuni caratteri riservati non sono ammessi in un singolo nome.
- Usare i due punti `:` in un nome è possibile ma può risultare confuso nel Finder, quindi è meglio evitarlo.
- Se esiste già una cartella con lo stesso nome, Peach Commander mantiene semplicemente quella esistente — non viene sovrascritto nulla.
