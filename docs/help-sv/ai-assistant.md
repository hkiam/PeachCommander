---
title: AI-assistent
slug: ai-assistant
section: Insticksprogram
order: 122
related: [plugins, settings, privacy-and-security]
---

AI-assistenten är ett valfritt, borttagbart insticksprogram som hjälper dig att arbeta med dina filer på vanligt språk. Den kan sammanfatta eller förklara ett dokument, föreslå ett bättre filnamn, översätta eller korrekturläsa text, förvandla data till en tabell och till och med organisera en mapp – och den kan utföra filåtgärder åt dig efter att först ha visat dig en plan. Den körs på enheten med Apple Intelligence när det är tillgängligt, eller så kan du rikta den mot en molnmodell. Eftersom det är ett insticksprogram kan du inaktivera eller ta bort det helt från **Konfiguration ▸ Insticksprogram…**.

## Öppna assistenten

Välj **Kommandon ▸ AI-assistent** för att visa assistenten i en dockad panel till höger i fönstret. Skriv en förfrågan och tryck på Return; assistenten kan läsa filer, slå upp saker och – med din bekräftelse – göra ändringar.

![AI-assistentens chatt dockad bredvid filpanelerna](screenshots/ai-chat.png)
*(Figur: AI-assistenten, dockad till höger, arbetar med en förfrågan.)*

## Högerklicksåtgärder (AI ▸)

Det snabbaste sättet att använda assistenten är undermenyn **AI ▸** i högerklicksmenyn:

- **På en fil** – Sammanfatta, Förklara, Föreslå ett namn, Översätt till engelska, Korrekturläs, Identifiera uppgifter och Skapa en tabell.
- **På panelens bakgrund** – Organisera den här mappen och Hitta troliga dubbletter.

Varje **AI ▸**-åtgärd öppnar sin **egen namngivna chatt** (till exempel *Sammanfatta – report.txt*), så att olika uppgifter hålls åtskilda istället för att staplas i en enda lång konversation. När du själv skriver i inmatningsfältet fortsätter den förfrågan den aktuella chatten.

## Hantera dina chattar

- Använd chattväxlaren högst upp i panelen för att flytta mellan konversationer.
- Menyn **Ta bort ▾** erbjuder **Ta bort den här chatten** och **Ta bort alla chattar**, så att du kan rensa allt på en gång när listan blir lång. Tomma chattar rensas bort automatiskt när du stänger panelen.

## Ändringar bekräftas först

För allt som ändrar filer – flytta, byta namn, skriva, ta bort – visar assistenten en **plan och väntar på din bekräftelse** innan den agerar. Du kan ändra detta i Inställningar genom att höja assistentens autonomi, eller sänka den till skrivskyddat läge så att den aldrig ändrar något.

## Inställningar

Öppna **Konfiguration ▸ Inställningar ▸ AI** för att konfigurera assistenten på en enda sida:

- **Föredragen modell** – Automatisk (moln om konfigurerat, annars på enheten), På enheten (Apple Intelligence) eller Moln.
- **Molnslutpunkt, modell och API-nyckel** – för att använda en OpenAI-kompatibel modell istället för den på enheten. Nyckeln lagras i macOS Keychain, aldrig i dina konfigurationsfiler.
- **Assistentens autonomi** – skrivskyddad, bekräfta ändringar (standard) eller autonom.
- **Anpassad systemprompt** – valfria instruktioner som formar hur assistenten svarar.
- **MCP-server** – en valfri, endast lokal server som låter en extern agent styra appen; avstängd som standard och kan skyddas med en token.

![AI-sidan i Inställningar med alternativen för autonomi och MCP-server](screenshots/settings-ai.png)
*(Figur: Alla assistentalternativ finns på en enda AI-sida i Inställningar.)*

## Integritet

- Med Apple Intelligence körs assistenten **på din Mac**; ingenting lämnar enheten.
- En molnmodell används **endast om du konfigurerar en**, och dess API-nyckel förvaras i Keychain.
- Filändrande åtgärder bekräftas innan de körs såvida du inte medvetet höjer autonominivån.
