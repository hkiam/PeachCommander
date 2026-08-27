---
title: Assistente AI
slug: ai-assistant
section: Plugin
order: 122
related: [plugins, settings, privacy-and-security]
---

L'assistente AI è un plugin facoltativo e rimovibile che vi aiuta a lavorare con i vostri file in linguaggio naturale. Può riassumere o spiegare un documento, proporre un nome migliore, tradurre o rileggere un testo, trasformare dati in una tabella e perfino riordinare una cartella — e può eseguire azioni sui file dopo avervi mostrato un piano. Arriva come due plugin: **AI On-Device** gira su Apple Intelligence e offre le azioni che propongono e poi applicano, mentre **AI Assistant** è la chat e richiede un modello cloud. Attivate l'uno, o entrambi. **Arrivano disattivati.** Attivateli in **Configurazione ▸ Plugin…** e riavviate, oppure lasciateli spenti e non comparirà nulla — nessun menu AI ▸, nessuna chat, nessuna colonna. È voluto finché la funzione è in beta: può rinominare, spostare ed eliminare file ed eseguire comandi shell per voi, ognuno dietro un piano che approvate, ed è molta libertà da concedere per impostazione predefinita a una novità. Senza una chiave API tutto avviene sul vostro Mac: si tratta quindi della portata, non di dati che lascerebbero la macchina. Il plugin **AI Column** mostra quello che quelle azioni hanno ricavato — un riassunto, un tipo, un argomento, una data — come colonne del pannello; non avvia alcun modello. Arriva spento insieme agli altri e resta facoltativo, e non mostra nulla finché non lo attivate e non aggiungete una delle sue colonne. Dalla stessa pagina potete anche rimuovere del tutto l'uno o l'altro.

**Sul dispositivo o nel cloud.** Il modello locale è privato e gratuito, ed è piccolo: accoglie qualche migliaio di parole per volta. Leggere un file lungo *per intero* funziona quindi diversamente — l'assistente lo legge a tratti e ricompone i risultati, il che richiede più tempo quanto più lungo è il file. Per lavori impegnativi su molti file, o per conversazioni lunghe, un modello cloud è più veloce e tiene insieme di più. Le azioni del menu contestuale girano sempre sul vostro Mac; è la chat la metà che vuole un endpoint, e **Impostazioni ▸ AI** è dove gliene date uno.

## Aprire l'assistente

Scegliete **Comandi ▸ Assistente AI** per mostrare l'assistente in un pannello agganciato a destra della finestra. Scrivete una richiesta e premete Invio; l'assistente può leggere file, cercare informazioni e — con la vostra conferma — apportare modifiche.

![La chat dell'assistente AI agganciata accanto ai pannelli dei file](screenshots/ai-chat.png)
*(Figura: l'assistente AI, agganciato a destra, mentre lavora a una richiesta.)*

## Azioni del menu contestuale (AI ▸)

Il modo più rapido di usare l'assistente è il sottomenu **AI ▸** del menu contestuale:

- **Su un file** — Riassumi, Spiega, Classifica, Proponi un nome, Proponi un commento, Traduci in inglese, Rileggi, Rileva attività e Crea una tabella.
- **Sullo sfondo del pannello** — Riordina questa cartella, Cerca per significato e Trova probabili duplicati.

**Riassumi**, **Spiega**, **Classifica**, **Proponi un nome**, **Proponi un commento**, **Crea una tabella** e **Riordina questa cartella** vengono dal plugin **AI On-Device** e fanno il loro lavoro senza aprire alcuna chat — anche su una scansione o su una schermata, perché le parole vengono prima lette dall'immagine: mostrano la proposta in un foglio, voi togliete la spunta a ciò che volete lasciare com'è, e sul disco non cambia nulla finché non approvate. Le azioni restanti appartengono al plugin **AI Assistant** e aprono una **chat propria e intitolata** (per esempio *Traduci – rapporto.txt*), così compiti diversi restano separati invece di accumularsi in un'unica lunga conversazione. Quando scrivete voi nel campo di immissione, quella richiesta prosegue la chat corrente.

**Più file insieme.** Marcate una selezione e l'azione viene eseguita su ogni file marcato, uno dopo l'altro. Le azioni che usano un foglio vi mostrano dentro l'avanzamento e **Annulla** si ferma tra un file e l'altro; quelle che aprono una chat mettono l'avanzamento nella barra di stato, dove **Interrompi** fa lo stesso. In entrambi i casi potete guardare i primi risultati e interrompere.

**Proponi un nome** finisce con un pulsante anziché con una frase: il nome proposto compare in una barra sotto la conversazione, con accanto un pulsante **Rinomina**. Premerlo è l'approvazione — non vi viene chiesto due volte.

### Le vostre formulazioni

Ciò che ogni azione chiede al modello è un file di testo che potete modificare: `aichat/skills.json` per le azioni sui file e `aichat/folder-skills.json` per quelle sulle cartelle, nella vostra cartella di configurazione. Entrambi vengono scritti con le formulazioni integrate al primo avvio dell'assistente, così ne vedete il formato. `{name}` e `{path}` stanno per il file. Eliminate un file per tornare alle formulazioni originali.

**Azioni vostre.** Aggiungete una voce con un `id` a vostra scelta, e potrà essere eseguita come qualsiasi altro comando indicando `plugin.ai.skill.<id>` — nel menu utente, sulla barra dei pulsanti o su una scorciatoia da tastiera. (Per un'azione su cartella, `plugin.ai.folderskill.<id>`.) Il sottomenu **AI ▸** elenca soltanto le azioni integrate: è costruito dal manifest del plugin senza caricarlo, così che un plugin disattivato non vi contribuisca nulla — ed è per questo che le vostre azioni le collocate voi anziché vederle comparire lì. Indicate un id che non esiste e l'assistente ve lo dice invece di non fare nulla.

## Chiedergli di trovare un file

Non dovete sapere dove si trova un file. Descrivetelo e l'assistente lo cerca nell'indice che macOS tiene già del vostro disco — non c'è quindi nulla da costruire né da aspettare che si aggiorni.

- *«Trova la fattura PDF del mese scorso»* — un tipo, una parola nel nome e una finestra temporale.
- *«Dove sono tutte le mie cartelle node_modules?»* — cartelle, per nome, ovunque nella vostra cartella home.
- *«Quale file cita il contratto di Aquisgrana?»* — parole **dentro** i file, cosa che la normale ricerca Trova file non sa fare se prima non le indicate una cartella.

Potete indirizzare la ricerca: la vostra cartella home per impostazione predefinita, l'intero computer, oppure solo la cartella mostrata in un pannello. L'assistente vi dice quale ha usato, così una risposta vuota si legge invece di sembrare un'alzata di spalle.

Due limiti da conoscere. macOS tiene alcuni luoghi fuori dal proprio indice — e fuori dalla portata di qualsiasi app senza Accesso completo al disco — quindi «non trovato» non prova che un file non esista; vedete [Risoluzione dei problemi](troubleshooting). E un file appena creato può non essere ancora indicizzato, nel qual caso **Trova file** (Alt+F7), che percorre le cartelle da sé, lo troverà comunque.

## Gestire le chat

- Usate il selettore di chat in cima al pannello per passare da una conversazione all'altra.
- Il menu **Elimina ▾** offre **Elimina questa chat** ed **Elimina tutte le chat**, così potete ripulire tutto in una volta quando l'elenco si allunga. Le chat vuote vengono ripulite automaticamente alla chiusura del pannello.

## Le modifiche vengono prima confermate

Per tutto ciò che modifica file — spostare, rinominare, scrivere, eliminare — l'assistente mostra un **piano e attende la vostra conferma** prima di agire. Potete cambiarlo nelle Impostazioni alzando l'autonomia dell'assistente, oppure abbassarla a sola lettura perché non modifichi mai nulla. Una copia o uno spostamento viene segnalato come concluso quando lo è: l'assistente attende la fine del trasferimento, e potete seguirlo nel Gestore trasferimenti come per qualsiasi altra operazione.

**Potete approvare solo una parte di un piano.** Quando un piano riguarda più file — rinominare una cartella intera, svuotare i Download — ognuno compare come una riga spuntata sopra i pulsanti. Togliete la spunta a quelli che volete lasciare stare e premete **Conferma ed esegui**: il resto procede, e ciò che avete deselezionato non viene toccato. Togliere la spunta a tutto equivale ad annullare, e l'assistente lo dice invece di riferire che non ha fatto nulla. Un piano che è una sola azione non ha elenco, perché Conferma e Annulla gli dicono già sì e no.

## Che cosa ha fatto l'assistente, e come riprenderlo

**Azioni ▾** nella chat ha due voci:

- **Mostra che cosa ha fatto l'assistente…** elenca ogni modifica, la più recente per prima, con ciò che gli era stato chiesto e com'è andata — comprese le richieste che l'impostazione di autonomia ha rifiutato. Un agente esterno collegato via MCP compare nello stesso elenco.
- **Annulla l'ultima modifica** riprende la modifica più recente che abbia un inverso: una rinomina viene rinominata indietro, uno spostamento rispostato. Dove nulla può essere ripreso, l'elenco dice perché — un file sovrascritto non è stato conservato da nessuna parte, e gli elementi nel Cestino si ripristinano dal Finder.

Potete anche semplicemente chiedere: *«annulla»* e *«che cosa hai modificato?»* raggiungono le stesse due funzioni.

## Colonne del pannello

Quello che le azioni hanno ricavato è disponibile come colonne. Aggiungetele dall'editor dei set di colonne: **Riepilogo IA** mostra la prima riga di un riassunto, e **Tipo IA**, **Argomento IA** e **Data IA** mostrano che cosa **Classifica** ha ricavato da un file — con questi nomi in italiano, tradotti in ogni lingua. Ognuna resta vuota finché un'azione non ha letto quel file — queste colonne mostrano lavoro già svolto e non avviano mai il modello da sole. **Lingua**, nello stesso plugin, riconosce in che lingua è scritto un file di testo, senza alcun modello.

Le stesse tre sono anche segnaposto di rinomina. `[=ai_column.ai_topic]-[Y]-[M].[E]` nella finestra di rinomina multipla (Ctrl+M) dà a una cartella di file `dokument1.pdf` il nome di ciò che sono: per questo non è stato costruito nulla, perché la maschera di rinomina ha sempre risolto `[=provider.field]` attraverso il sistema delle colonne. Prima classificate, poi rinominate. L'intestazione segue la vostra lingua; il `ai_column.ai_topic` dentro la maschera no — una maschera continua quindi a funzionare se cambiate lingua.

## Impostazioni

Aprite **Configurazione ▸ Impostazioni ▸ AI** per configurare l'assistente in un'unica pagina:

- **Modello della chat** — su che cosa gira la chat **AI Assistant**. Da quando le azioni locali sono diventate un plugin a sé, le risposte sono due e non tre: *L'endpoint cloud qui sotto, se ne avete indicato uno*, oppure *Niente — lasciare il lavoro al plugin AI On-Device*. La pagina è raggruppata allo stesso modo: prima le impostazioni della chat, sotto ciò che entrambe le metà possono fare.
- **Endpoint cloud, modello e chiave API** — per usare un modello compatibile con OpenAI al posto di quello locale. La chiave è conservata nel portachiavi di macOS, mai nei vostri file di configurazione.
- **Autonomia dell'assistente** — sola lettura, confermare le modifiche (predefinito) o autonomo.
- **Prompt di sistema personalizzato** — istruzioni facoltative che influenzano il modo in cui l'assistente risponde.
- **Server MCP** — un server facoltativo, solo locale, che consente a un agente esterno di guidare l'app; disattivato per impostazione predefinita e proteggibile con un token.

![La pagina AI delle Impostazioni con l'autonomia e le opzioni del server MCP](screenshots/settings-ai.png)
*(Figura: tutte le opzioni dell'assistente stanno in un'unica pagina AI delle Impostazioni.)*

## Privacy

- Con Apple Intelligence l'assistente gira **sul vostro Mac**; nulla lascia il dispositivo.
- Un modello cloud viene usato **solo se ne configurate uno**, e la sua chiave API resta nel portachiavi.
- Le azioni che modificano file vengono confermate prima di essere eseguite, a meno che non alziate deliberatamente il livello di autonomia.
