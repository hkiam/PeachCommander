---
title: Trasferimenti in background
slug: background-transfers
section: File e cartelle
order: 32
related: [copying-files, downloading-from-url]
---

Le copie, gli spostamenti, le eliminazioni e i download di grandi dimensioni non devono per forza bloccare il vostro lavoro. Peach Commander può eseguirli in background e raccoglierli tutti in un unico posto: il Gestore trasferimenti in background. Da lì potete seguire l'avanzamento e la velocità di trasferimento di ogni operazione, metterla in pausa o riprenderla, annullarla, oppure metterle in coda per avviarle più tardi. Poiché un'operazione in background viene eseguita per conto proprio, non vi impedisce mai di sfogliare, aprire file o avviare il trasferimento successivo.

## Come fare

1. Avviate una copia, uno spostamento, un'eliminazione o un download e scegliete di eseguirlo in background. L'operazione appare nel Gestore trasferimenti in background.
2. Aprite il gestore in qualsiasi momento da **Comandi ▸ Gestore trasferimenti in background…** (oppure premete Cmd+Shift+B).
3. Ogni operazione mostra un titolo, una barra di avanzamento e una riga in tempo reale con i file completati, i byte trasferiti e la velocità corrente.
4. Usate i pulsanti per singola operazione per **Metti in pausa**, **Riprendi** o **Annulla** mentre un'operazione è in corso.
5. Un lavoro in corso ha anche un menu della velocità. Scegli un limite — 1, 5 o 20 MB/s, oppure piena velocità — per togliere un trasferimento di mezzo a un altro senza rallentare gli altri. Ha effetto subito; **Predefinito** restituisce il lavoro al limite impostato in Configurazione.
6. Per i lavori aggiunti ma non ancora avviati (lavori in attesa), fai clic su **Avvia** sul lavoro, o su **Avvia tutti** per l’intera lista d’attesa. Con **▲** e **▼** sposti un lavoro in attesa più avanti o più indietro nella coda; i pulsanti compaiono solo dove lo spostamento è possibile, così un lavoro in attesa non supera mai il trasferimento già in corso.
7. Quando tutto ciò che vi interessa è terminato, fate clic su **Cancella completati** per riordinare l'elenco.

![Il Gestore trasferimenti in background che elenca le operazioni attive e in attesa con barre di avanzamento e i pulsanti Metti in pausa, Riprendi e Annulla.](screenshots/transfer-manager.png)

*Ogni trasferimento è una riga che potete mettere in pausa, riprendere o annullare in modo indipendente.*

## Scorciatoie

| Azione | Scorciatoia |
| --- | --- |
| Aprire il Gestore trasferimenti in background | Cmd+Shift+B |

## Suggerimenti

- **Limitate la velocità.** Per evitare che un trasferimento di grandi dimensioni saturi la connessione o il disco, impostate un limite di velocità nella finestra di copia prima di avviare l'operazione. Il gestore mostra quindi in tempo reale la velocità limitata.
- **Mettete in coda per dopo.** Le operazioni in attesa restano nell'elenco senza essere eseguite finché non premete Avvia (o Avvia tutto), così potete preparare diversi trasferimenti e avviarli insieme.
- **Eseguitene diversi contemporaneamente.** Le operazioni vengono eseguite in modo indipendente, quindi potete metterne in pausa una mentre un'altra prosegue.

## Note

Poiché un'operazione in background viene eseguita senza che voi la seguiate, non può fermarsi a porre domande. Se un file esiste già nella destinazione, l'operazione in background lo sovrascrive; se un singolo elemento non può essere trasferito, quell'elemento viene saltato e l'operazione prosegue. Al termine dell'operazione, gli eventuali elementi saltati vengono raccolti in un registro degli errori così potete esaminare con precisione cosa è andato storto.
