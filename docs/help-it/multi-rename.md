---
title: Rinominare molti file
slug: multi-rename
section: Strumenti avanzati
order: 92
related: [moving-and-renaming]
---

Lo strumento di rinomina multipla rinomina un intero gruppo di file in un solo passaggio. Invece di modificare i nomi uno alla volta, descrivi la modifica una sola volta — uno schema di denominazione, un cerca-e-sostituisci, uno schema di numerazione o un cambio di maiuscole/minuscole — e Peach Commander lo applica a ogni file selezionato. Un'anteprima in tempo reale mostra esattamente come si chiamerà ogni file prima che accada qualcosa, e un singolo Annulla riporta i nomi originali se il risultato non era quello che volevi.

## Rinomina un gruppo di file

1. Seleziona i file da rinominare (vedi *Selezione dei file*). Sono interessati solo gli elementi selezionati.
2. Scegli **Comandi > Strumento di rinomina multipla…**, o premi Ctrl+M.
3. Costruisci la tua regola di rinomina usando i campi descritti sotto. La griglia di anteprima si aggiorna mentre digiti, mostrando ogni **Vecchio nome** accanto al suo **Nuovo nome**.
4. Controlla l'anteprima. Una riga mostrata in un colore di evidenziazione segnala un nome che non può essere usato (per esempio, un duplicato o un nome non valido) così puoi regolare la regola.
5. Quando l'anteprima sembra corretta, fai clic su **Avvia**. Se cambi idea, fai clic su **Annulla** per ripristinare i nomi originali.

![La finestra di rinomina multipla con i campi della maschera, le opzioni e la griglia di anteprima da vecchio a nuovo](screenshots/multi-rename.png)
*(Figura: la griglia di anteprima si aggiorna in tempo reale mentre modifichi la regola di rinomina; nulla viene modificato sul disco finché non fai clic su Avvia.)*

## Costruire la regola di rinomina

- **Maschera di rinomina** ed **Estensione** — schemi che costruiscono il nuovo nome e la nuova estensione. Usa i pulsanti di inserimento rapido, o digita i segnaposto direttamente: `[N]` per il nome originale, `[N1-9]` per un intervallo di caratteri da esso, `[C]` per il contatore, `[d]` per parti di data e ora e `[P]` per il nome della cartella superiore.
- **Cerca / Sostituisci con** — sostituisce il testo dentro i nomi. Attiva **Regex** per la corrispondenza di schemi, **Distingui maiuscole** per corrispondere esattamente al caso delle lettere e **Ripeti** per sostituire ogni occorrenza.
- **Maiuscole/minuscole** — converti i nomi in minuscolo, MAIUSCOLO, Prima lettera maiuscola o Ogni Parola Maiuscola.
- **Contatore** — imposta il numero di **Inizio**, il **Passo** tra i file e a quante **Cifre** allineare (per esempio, 001, 002, 003) ovunque compaia `[C]`.

## Scorciatoie

| Azione | Scorciatoia |
| --- | --- |
| Apri lo strumento di rinomina multipla | Ctrl+M |
| Applica la rinomina | Invio |
| Chiudi la finestra | Esc |

## Suggerimenti

- Nulla viene scritto sul disco finché non fai clic su **Avvia**, così puoi sperimentare liberamente con la regola e osservare l'anteprima.
- Dopo un'esecuzione, **Annulla** inverte la rinomina in un solo passaggio.
- Salva una regola che usi spesso come **Preimpostazione**, poi scegliela dal menu delle preimpostazioni la volta successiva per riempire tutti i campi in una volta.
- Per rinominare un singolo file, o rinominare file mentre li sposti, usa invece la rinomina sul posto o la finestra di spostamento (vedi *Spostamento e rinomina*).
