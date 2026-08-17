---
title: Impostazioni
slug: settings
section: Personalizzazione
order: 116
related: [appearance, keyboard-shortcuts]
---

La finestra Impostazioni è dove adatti Peach Commander al tuo modo di lavorare: quali barre compaiono, come vengono mostrati i file, come si comportano le operazioni di copia ed eliminazione, il formato di archivio usato quando comprimi, il comportamento delle schede, i valori predefiniti FTP, la lingua di visualizzazione e altro. Le impostazioni sono raggruppate in pagine così puoi trovare rapidamente un'opzione, e ogni modifica viene salvata automaticamente nella tua cartella di configurazione personale.

## Apri Impostazioni

1. Scegli **Peach Commander > Impostazioni…**, o premi Cmd+, (virgola).
2. Puoi anche aprire la stessa finestra da **Configurazione > Opzioni…**.
3. Scegli una pagina dall'elenco a sinistra; le opzioni di quella pagina compaiono a destra.
4. Regola i controlli. Le modifiche hanno effetto subito a meno che una nota sulla pagina non dica diversamente.
5. Per andare direttamente a un'opzione, digita nel campo di ricerca in cima alla finestra. Le impostazioni corrispondenti di *tutte* le pagine sono elencate con la pagina in cui si trovano, e sceglierne una apre quella pagina con l'impostazione evidenziata. ↑/↓ scorrono i risultati, Invio apre quello evidenziato ed Esc lascia la ricerca e riporta la pagina da cui venivi.

![La finestra Impostazioni che mostra la pagina Layout con caselle per le barre dell'interfaccia](screenshots/settings-layout.png)
*(Figura: la pagina Layout controlla quali barre sono mostrate attorno ai pannelli.)*

## Le pagine

La finestra ha queste pagine, in ordine:

- **Layout** — mostra o nascondi la barra dei dischi, la barra delle schede, la barra del percorso e la barra di stato.
- **Visualizzazione** — come vengono elencati file e cartelle, incluso il formato della data.
- **Icone** — l'aspetto delle icone negli elenchi dei file.
- **Funzionamento** — comportamento generale, come cosa succede quando digiti in un pannello (ricerca rapida contro riga di comando).
- **Colori** — colori personalizzati dei pannelli, o lasciali seguire il tema corrente.
- **Conferma** — quali azioni chiedono prima di confermare, come l'eliminazione.
- **Modifica/Visualizza** — se il salvataggio nell'editor conserva una copia di backup `.bak`, i programmi usati per modificare e visualizzare i file, e le associazioni per tipo.
- **Copia/Elimina** — preserva i metadati dei file, usa la clonazione rapida, copia solo i file più recenti, verifica dopo la copia, invia le eliminazioni al Cestino e imposta un limite di velocità opzionale.
- **Zip/Compressore** — il formato di archivio e il livello di compressione predefiniti usati quando comprimi.
- **Plugin** — attiva o disattiva i plugin installati.
- **Schede** — come le schede delle cartelle si aprono e si comportano.
- **FTP** — valori predefiniti di rete come l'intervallo keep-alive.
- **Tastiera** — rivedi e cambia le scorciatoie da tastiera.
- **Lingua** — scegli Predefinita di sistema, English o Deutsch.
- **AI** — configura l'assistente IA: modello preferito, endpoint e chiave cloud, autonomia e il server MCP opzionale (vedi [Assistente IA](ai-assistant.md)).
- **Varie** — apri la tua cartella di configurazione nel Finder.

I plugin abilitati possono aggiungere le proprie pagine dopo quelle integrate — per esempio **Disk Map** e **System Monitor** — così le loro opzioni risiedono nella stessa finestra (vedi [Plugin](plugins.md)).

![La finestra Impostazioni che mostra le opzioni della pagina Visualizzazione per come vengono elencati i file](screenshots/settings-display.png)
*(Figura: la pagina Visualizzazione controlla come vengono elencati file e cartelle.)*

![La finestra Impostazioni che mostra la pagina Funzionamento](screenshots/settings-operation.png)
*(Figura: la pagina Funzionamento governa la ricerca rapida e il comportamento del mouse.)*

## Dove sono conservate le tue impostazioni

La tua configurazione è conservata in file di testo semplice dentro la tua cartella Application Support personale, in `~/Library/Application Support/PeachCommander`. Per aprirla, vai alla pagina **Varie** e fai clic su **Apri cartella di configurazione**. Le password FTP salvate non sono conservate in questi file; sono conservate in modo sicuro nel portachiavi macOS.

Le impostazioni vengono scritte man mano che le modifichi. Puoi anche forzare un salvataggio in qualsiasi momento con **Configurazione > Salva impostazioni**, e memorizzare la posizione corrente della finestra e il layout dei pannelli con **Configurazione > Salva posizione**.

## Portare le impostazioni da Total Commander

Se stai passando da Total Commander su Windows, puoi importare i tuoi siti FTP salvati. Scegli **Configurazione > Importa wincmd.ini…** e seleziona il tuo file di configurazione FTP di Total Commander. Le tue connessioni vengono aggiunte a Peach Commander nello stesso ordine in cui comparivano lì.

## Scorciatoie

| Azione | Scorciatoia |
| --- | --- |
| Apri Impostazioni | Cmd+, |

## Note

- La pagina **Lingua** offre Predefinita di sistema, English e Deutsch. Cambiare la lingua ha effetto solo dopo aver riavviato Peach Commander.
- I colori impostati nella pagina **Colori** sovrascrivono il tema; usa **Ripristina predefiniti** lì per tornare ai colori del tema.
- Peach Commander conserva le sue impostazioni solo nella propria cartella di configurazione, così le tue modifiche non interessano mai altre app e sono facili da salvare copiando quella cartella.
