---
title: AI-assistent
slug: ai-assistant
section: Plugins
order: 122
related: [plugins, settings, privacy-and-security]
---

AI-assistenten er et valgfrit plugin, der kan fjernes, og som hjælper dig med at arbejde med dine filer på almindeligt sprog. Den kan opsummere eller forklare et dokument, foreslå et bedre filnavn, oversætte eller korrekturlæse tekst, omdanne data til en tabel og endda organisere en mappe — og den kan udføre filhandlinger for dig, efter at den først har vist dig en plan. Den kører på enheden med Apple Intelligence, når det er tilgængeligt, eller du kan pege den mod en cloud-model. Fordi den er et plugin, kan du deaktivere eller fjerne den helt fra **Konfiguration ▸ Plugins…**.

## Åbn assistenten

Vælg **Kommandoer ▸ AI-assistent** for at vise assistenten i et forankret panel til højre i vinduet. Skriv en anmodning, og tryk på Return; assistenten kan læse filer, slå ting op og — med din bekræftelse — foretage ændringer.

![AI-assistentens chat forankret ved siden af filpanelerne](screenshots/ai-chat.png)
*(Figur: AI-assistenten, forankret til højre, arbejder på en anmodning.)*

## Handlinger via højreklik (AI ▸)

Den hurtigste måde at bruge assistenten på er undermenuen **AI ▸** i højrekliksmenuen:

- **På en fil** — Opsummér, Forklar, Foreslå et navn, Foreslå en kommentar, Oversæt til engelsk, Korrekturlæs, Registrér opgaver og Lav en tabel.
- **På panelets baggrund** — Organisér denne mappe og Find sandsynlige dubletter.

Hver **AI ▸**-handling åbner sin **egen navngivne chat** (for eksempel *Opsummér – report.txt*), så forskellige opgaver holdes adskilt i stedet for at hobe sig op i én lang samtale. Når du selv skriver i inputfeltet, fortsætter den anmodning den aktuelle chat.

## Håndtér dine chats

- Brug chat-skifteren øverst i panelet til at bevæge dig mellem samtaler.
- Menuen **Slet ▾** tilbyder **Slet denne chat** og **Slet alle chats**, så du kan rydde alt på én gang, når listen bliver lang. Tomme chats ryddes op automatisk, når du lukker panelet.

## Ændringer bekræftes først

For alt, der ændrer filer — flytning, omdøbning, skrivning, sletning — viser assistenten en **plan og venter på din bekræftelse**, før den handler. Du kan ændre dette i Indstillinger ved at hæve assistentens selvstændighed eller sænke den til skrivebeskyttet, så den aldrig ændrer noget.

## Indstillinger

Åbn **Konfiguration ▸ Indstillinger ▸ AI** for at konfigurere assistenten på en enkelt side:

- **Foretrukken model** — Automatisk (cloud hvis konfigureret, ellers på enheden), På enheden (Apple Intelligence) eller Cloud.
- **Cloud-slutpunkt, model og API-nøgle** — for at bruge en OpenAI-kompatibel model i stedet for den på enheden. Nøglen gemmes i macOS-nøgleringen, aldrig i dine konfigurationsfiler.
- **Assistentens selvstændighed** — skrivebeskyttet, bekræft ændringer (standarden) eller selvstændig.
- **Tilpasset systemprompt** — valgfrie instruktioner, der former, hvordan assistenten svarer.
- **MCP-server** — en valgfri server, der kun er lokal, og som lader en ekstern agent styre appen; slået fra som standard og kan beskyttes med et token.

![AI-siden i Indstillinger med indstillingerne for selvstændighed og MCP-serveren](screenshots/settings-ai.png)
*(Figur: Alle assistentens indstillinger findes på én AI-side i Indstillinger.)*

## Privatliv

- Med Apple Intelligence kører assistenten **på din Mac**; intet forlader enheden.
- En cloud-model bruges **kun, hvis du konfigurerer en**, og dens API-nøgle opbevares i nøgleringen.
- Filændrende handlinger bekræftes, før de køres, medmindre du bevidst hæver selvstændighedsniveauet.
