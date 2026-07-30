---
title: Privacy e sicurezza
slug: privacy-and-security
section: macOS e privacy
order: 132
related: [ftp-and-sftp, troubleshooting]
---

Peach Commander è costruito per restare fuori dai piedi e mantenere i tuoi dati sul tuo Mac. Le password vengono affidate al portachiavi macOS, le informazioni sugli arresti anomali non lasciano mai il tuo computer senza il tuo consenso, e l'app non raccoglie alcuna analisi di utilizzo. Questo argomento spiega dove risiedono le tue informazioni sensibili e come concedere l'unica autorizzazione di sistema di cui un gestore di file ha bisogno per svolgere il suo lavoro.

## Dove sono conservate le password

Qualsiasi password o passphrase di chiave che salvi — per una connessione FTP o SFTP, o per aprire un archivio protetto da password — viene scritta nel **portachiavi** macOS, lo stesso archivio sicuro che il sistema usa per i tuoi accessi Wi-Fi e ai siti web. Le password non vengono mai scritte nelle impostazioni o nei file di connessione di Peach Commander in chiaro.

1. Quando salvi una password di connessione o di archivio, scegli l'opzione per ricordarla.
2. La password è conservata nel tuo portachiavi di accesso, protetto dal tuo account.
3. Per rivedere o rimuovere una password salvata più tardi, apri l'app **Accesso Portachiavi** (in Applicazioni ▸ Utility) e cerca il nome della connessione.

## Concedi l'Accesso completo al disco

macOS mantiene alcune posizioni private — i dati di Mail, Messaggi e altre app dentro la tua cartella Libreria — finché non consenti esplicitamente l'accesso. Poiché un gestore di file è pensato per raggiungere ogni file, Peach Commander richiede l'**Accesso completo al disco**. L'app continua a funzionare con accesso ridotto finché non glielo concedi; semplicemente non vedrai quelle cartelle protette.

1. Scegli **Comandi ▸ Accesso completo al disco…**, o fai clic su **Apri Impostazioni di Sistema** quando l'app si offre di guidarti all'avvio.
2. In **Impostazioni di Sistema ▸ Privacy e sicurezza ▸ Accesso completo al disco**, attiva l'interruttore accanto a Peach Commander.
3. Riavvia l'app se richiesto.

## I rapporti di arresto anomalo restano locali

Se l'app si chiude in modo inatteso, macOS scrive un rapporto di arresto anomalo nella tua cartella di diagnostica. Al lancio successivo Peach Commander lo nota e si offre di aiutarti a inviare una segnalazione di bug — ma solo con il tuo consenso.

- Puoi **Mostra nel Finder** per vedere il rapporto, o **Copia rapporto negli appunti** per incollarlo tu stesso in una segnalazione di bug.
- Nulla viene mai trasmesso automaticamente, e non è coinvolto alcun servizio di terze parti per la segnalazione degli arresti anomali.

## Note

- **Nessuna telemetria.** Peach Commander non traccia la tua attività né invia analisi di utilizzo da nessuna parte.
- **L'accesso ridotto è sicuro.** Se salti l'Accesso completo al disco, l'app sfoglia e gestisce comunque i file che normalmente puoi vedere; sono nascoste solo le posizioni protette dal sistema.
- **Tu controlli le password salvate.** Poiché le credenziali risiedono nel portachiavi, le gestisci e le revochi con gli strumenti standard di macOS invece che dentro l'app.
