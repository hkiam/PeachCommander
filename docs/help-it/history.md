---
title: Cronologia globale
slug: history
section: Organizzare la visualizzazione
order: 47
related: [favorites, navigating]
---

La cronologia globale è una finestra che ricorda il tuo lavoro: cartelle visitate, file aperti, operazioni eseguite e comandi lanciati. Premi Ctrl+Cmd+H da qualsiasi punto, inizia a digitare e torni alla cartella di ieri in un secondo — senza mouse.

## Aprire la cronologia

1. Premi Ctrl+Cmd+H oppure scegli **Vai > Cronologia…**. Non importa quale pannello sia attivo.
2. Digita qualche lettera. La corrispondenza non deve essere esatta né contigua: `proj rep` trova `~/Projects/annual-report.txt`.
3. Scorri i risultati con le frecce Su e Giù mentre continui a digitare.
4. Invio agisce sulla voce evidenziata, Esc chiude la finestra.

Le voci sono ordinate per quanto di recente *e* quanto spesso le hai usate, così i luoghi in cui lavori più spesso sono già in alto. Le voci fissate guidano sempre l’elenco.

## Filtrare per tipo

I pulsanti sotto il campo di ricerca limitano l’elenco a tutte le voci, alle cartelle, ai file, alle operazioni o ai preferiti. Option+1 fino a Option+5 li alternano da tastiera.

## Agire su una voce

| Azione | Scorciatoia |
| --- | --- |
| Aprire la voce evidenziata | Return |
| Mostrarla nel pannello, con il cursore sopra | Option+Return |
| Aprire una delle nove voci più rilevanti | Cmd+1 … Cmd+9 |
| Cambiare il pannello in cui si apre | Tab |
| Fissare o rilasciare la voce | Cmd+P |
| Rimuovere la voce dalla cronologia | Cmd+Delete |
| Copiare il percorso della voce | Option+Cmd+C |
| Mostrare la voce nel Finder | Cmd+Shift+R |
| Chiudere la cronologia | Esc |

Invio fa ciò che la voce merita: una cartella si apre nel pannello di destinazione, un file si apre come farebbe dal pannello e una riga di comando finisce nella riga di comando perché tu la controlli ed esegua. Il pannello di destinazione è indicato in fondo alla finestra e Tab lo cambia.

## Ripetere un’operazione

Una copia o uno spostamento compare sotto **Operazioni**, e Invio la esegue di nuovo: gli stessi elementi nella stessa cartella, attraverso la normale coda di trasferimento e le sue domande di sovrascrittura. Gli elementi che non esistono più vengono saltati e, se non ne resta nessuno, te lo si dice.

Eliminazioni e rinomine sono elencate ma non vengono mai ripetute: Invio mostra invece dove sono avvenute. Ripetere un’eliminazione non deve stare a un tasto di distanza in un elenco che stai solo scorrendo.

## Tenerla sotto controllo

Impostazioni ▸ Varie decide se tenere una cronologia, quante voci conservare e dopo quanti giorni dimenticarle. Le voci fissate sono escluse e 0 giorni conserva tutto; l’elenco vive in `history.ini` nella tua cartella di configurazione e sopravvive ai riavvii.

## Note

- Aprire qualcosa dalla cronologia conta come usarlo: per questo ciò a cui torni continua a salire.
- Le cartelle dentro un archivio, su un server o in un volume di un plugin non vengono ricordate: un percorso così non significa nulla senza il montaggio che l’ha prodotto, e la cronologia propria del pannello le conserva finché è aperto.
- Non è la cronologia delle cartelle del singolo pannello su Alt+Giù, che elenca soltanto dove è stato quel pannello, in ordine.
