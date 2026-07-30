---
title: Assistente AI
slug: ai-assistant
section: Plugin
order: 122
related: [plugins, settings, privacy-and-security]
---

L'assistente AI è un plugin opzionale e rimovibile che vi aiuta a lavorare con i vostri file usando il linguaggio naturale. Può riassumere o spiegare un documento, suggerire un nome di file migliore, tradurre o correggere un testo, trasformare i dati in una tabella e persino organizzare una cartella — e può eseguire azioni sui file al posto vostro dopo avervi mostrato prima un piano. Funziona sul dispositivo con Apple Intelligence quando disponibile, oppure potete indirizzarlo verso un modello nel cloud. Trattandosi di un plugin, potete disattivarlo o rimuoverlo completamente da **Configurazione ▸ Plugin…**.

## Aprire l'assistente

Scegliete **Comandi ▸ Assistente AI** per mostrare l'assistente in un pannello agganciato sul lato destro della finestra. Digitate una richiesta e premete Return; l'assistente può leggere i file, cercare informazioni e — con la vostra conferma — apportare modifiche.

![La chat dell'assistente AI agganciata accanto ai pannelli dei file](screenshots/ai-chat.png)
*(Figura: l'assistente AI, agganciato a destra, mentre lavora su una richiesta.)*

## Azioni del menu contestuale (AI ▸)

Il modo più rapido per usare l'assistente è il sottomenu **AI ▸** nel menu del clic destro:

- **Su un file** — Riassumi, Spiega, Suggerisci un nome, Traduci in inglese, Correggi, Rileva attività e Crea una tabella.
- **Sullo sfondo del pannello** — Organizza questa cartella e Trova probabili duplicati.

Ogni azione **AI ▸** apre una **propria chat con titolo** (ad esempio, *Riassumi – report.txt*), così le diverse attività restano separate invece di accumularsi in un'unica lunga conversazione. Quando digitate voi stessi nel campo di immissione, quella richiesta prosegue la chat corrente.

## Gestire le chat

- Usate il selettore di chat in cima al pannello per passare da una conversazione all'altra.
- Il menu **Elimina ▾** offre **Elimina questa chat** ed **Elimina tutte le chat**, così potete cancellare tutto in una volta quando l'elenco diventa lungo. Le chat vuote vengono ripulite automaticamente alla chiusura del pannello.

## Le modifiche vengono confermate prima

Per qualsiasi operazione che modifica i file — spostare, rinominare, scrivere, eliminare — l'assistente mostra un **piano e attende la vostra conferma** prima di agire. Potete cambiare questo comportamento nelle Impostazioni aumentando l'autonomia dell'assistente, oppure abbassarla a sola lettura in modo che non modifichi mai nulla.

## Impostazioni

Aprite **Configurazione ▸ Impostazioni ▸ AI** per configurare l'assistente in un'unica pagina:

- **Modello preferito** — Automatico (cloud se configurato, altrimenti sul dispositivo), Sul dispositivo (Apple Intelligence) o Cloud.
- **Endpoint cloud, modello e chiave API** — per usare un modello compatibile con OpenAI invece di quello sul dispositivo. La chiave è archiviata nel Portachiavi di macOS, mai nei vostri file di configurazione.
- **Autonomia dell'assistente** — sola lettura, conferma delle modifiche (impostazione predefinita) o autonoma.
- **Prompt di sistema personalizzato** — istruzioni facoltative che modellano il modo in cui l'assistente risponde.
- **Server MCP** — un server opzionale solo locale che consente a un agente esterno di pilotare l'app; disattivato per impostazione predefinita e proteggibile con un token.

![La pagina AI nelle Impostazioni con le opzioni di autonomia e del server MCP](screenshots/settings-ai.png)
*(Figura: tutte le opzioni dell'assistente si trovano in un'unica pagina AI nelle Impostazioni.)*

## Privacy

- Con Apple Intelligence l'assistente funziona **sul vostro Mac**; nulla lascia il dispositivo.
- Un modello nel cloud viene usato **solo se ne configurate uno**, e la sua chiave API è conservata nel Portachiavi.
- Le azioni che modificano i file vengono confermate prima di essere eseguite, a meno che non aumentiate deliberatamente il livello di autonomia.
