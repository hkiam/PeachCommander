---
title: AI-assistent
slug: ai-assistant
section: Insticksprogram
order: 122
related: [plugins, settings, privacy-and-security]
---

AI-assistenten är ett valfritt, borttagbart insticksprogram som hjälper dig att arbeta med dina filer på vanligt språk. Den kan sammanfatta eller förklara ett dokument, föreslå ett bättre filnamn, översätta eller korrekturläsa text, förvandla data till en tabell och till och med organisera en mapp – och den kan utföra filåtgärder åt dig efter att först ha visat dig en plan. Det består av två tillägg: **AI On-Device** körs på Apple Intelligence och ger dig åtgärderna som visar ett förslag och tillämpar det, medan **AI Assistant** är chatten och kräver en molnmodell. Slå på det ena, eller båda. Eftersom det är ett insticksprogram kan du inaktivera eller ta bort det helt från **Konfiguration ▸ Insticksprogram…**.

## Öppna assistenten

Välj **Kommandon ▸ AI-assistent** för att visa assistenten i en dockad panel till höger i fönstret. Skriv en förfrågan och tryck på Return; assistenten kan läsa filer, slå upp saker och – med din bekräftelse – göra ändringar.

![AI-assistentens chatt dockad bredvid filpanelerna](screenshots/ai-chat.png)
*(Figur: AI-assistenten, dockad till höger, arbetar med en förfrågan.)*

## Högerklicksåtgärder (AI ▸)

Det snabbaste sättet att använda assistenten är undermenyn **AI ▸** i högerklicksmenyn:

- **På en fil** – Sammanfatta, Förklara, Föreslå ett namn, Föreslå en kommentar, Översätt till engelska, Korrekturläs, Identifiera uppgifter och Skapa en tabell.
- **På panelens bakgrund** – Sök efter betydelse, Organisera den här mappen och Hitta troliga dubbletter.

**Sammanfatta**, **Förklara**, **Föreslå ett namn**, **Föreslå en kommentar** och **Ordna den här mappen** kommer från tillägget **AI On-Device** och gör sitt jobb utan att öppna någon chatt: de visar sitt förslag i ett blad, du avmarkerar det du vill lämna orört, och ingenting på disken ändras förrän du godkänner det. Övriga åtgärder hör till tillägget **AI Assistant** och öppnar sin egen namngivna chatt, så att olika uppgifter hålls isär. När du själv skriver i inmatningsfältet fortsätter den begäran den aktuella chatten.

## Hantera dina chattar

- Använd chattväxlaren högst upp i panelen för att flytta mellan konversationer.
- Menyn **Ta bort ▾** erbjuder **Ta bort den här chatten** och **Ta bort alla chattar**, så att du kan rensa allt på en gång när listan blir lång. Tomma chattar rensas bort automatiskt när du stänger panelen.

## Ändringar bekräftas först

För allt som ändrar filer – flytta, byta namn, skriva, ta bort – visar assistenten en **plan och väntar på din bekräftelse** innan den agerar. Du kan ändra detta i Inställningar genom att höja assistentens autonomi, eller sänka den till skrivskyddat läge så att den aldrig ändrar något.

## Inställningar

Öppna **Konfiguration ▸ Inställningar ▸ AI** för att konfigurera assistenten på en enda sida:

- **Föredragen modell** – vilken modell chatten **AI Assistant** använder. Sedan åtgärderna på enheten blev ett eget tillägg gäller detta bara chatten: *Moln* och *Automatiskt* använder båda slutpunkten nedan, och *På enheten* säger till chatten att den inte behövs.
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
