---
title: AI Assistant
slug: ai-assistant
section: Programtillegg
order: 122
related: [plugins, settings, privacy-and-security]
---

AI-assistenten er et valgfritt programtillegg du kan fjerne, som hjelper deg å arbeide med filene dine i vanlig språk. Den kan oppsummere eller forklare et dokument, foreslå et bedre filnavn, oversette eller korrekturlese tekst, gjøre data om til en tabell og til og med organisere en mappe – og den kan utføre filhandlinger for deg etter først å ha vist deg en plan. Den kjører på enheten med Apple Intelligence når det er tilgjengelig, eller du kan peke den mot en skymodell. Fordi det er et programtillegg, kan du deaktivere eller fjerne det helt fra **Konfigurasjon ▸ Programtillegg…**.

## Åpne assistenten

Velg **Kommandoer ▸ AI Assistant** for å vise assistenten i et forankret panel til høyre i vinduet. Skriv en forespørsel og trykk Return; assistenten kan lese filer, slå opp ting og – med din bekreftelse – gjøre endringer.

![AI-assistentens chat forankret ved siden av filpanelene](screenshots/ai-chat.png)
*(Figur: AI-assistenten, forankret til høyre, arbeider med en forespørsel.)*

## Høyreklikkhandlinger (AI ▸)

Den raskeste måten å bruke assistenten på er undermenyen **AI ▸** i høyreklikkmenyen:

- **På en fil** – Oppsummer, Forklar, Foreslå et navn, Foreslå en kommentar, Oversett til engelsk, Korrekturles, Finn oppgaver og Lag en tabell.
- **På panelbakgrunnen** – Organiser denne mappen og Finn sannsynlige duplikater.

Hver **AI ▸**-handling åpner sin **egen navngitte chat** (for eksempel *Oppsummer – rapport.txt*), slik at ulike oppgaver holder seg atskilt i stedet for å hope seg opp i én lang samtale. Når du selv skriver i inndatafeltet, fortsetter forespørselen den gjeldende chatten.

## Behandle chattene dine

- Bruk chat-velgeren øverst i panelet for å bevege deg mellom samtaler.
- **Slett ▾**-menyen tilbyr **Slett denne chatten** og **Slett alle chatter**, så du kan tømme alt på én gang når listen blir lang. Tomme chatter ryddes automatisk bort når du lukker panelet.

## Endringer bekreftes først

For alt som endrer filer – flytting, navnebytte, skriving, sletting – viser assistenten en **plan og venter på din bekreftelse** før den handler. Du kan endre dette i Innstillinger ved å heve assistentens autonomi, eller senke den til skrivebeskyttet slik at den aldri endrer noe.

## Innstillinger

Åpne **Konfigurasjon ▸ Innstillinger ▸ AI** for å sette opp assistenten på én enkelt side:

- **Foretrukket modell** – Automatisk (sky hvis konfigurert, ellers på enheten), På enheten (Apple Intelligence) eller Sky.
- **Skyendepunkt, modell og API-nøkkel** – for å bruke en OpenAI-kompatibel modell i stedet for den på enheten. Nøkkelen lagres i macOS-nøkkelringen, aldri i konfigurasjonsfilene dine.
- **Assistentens autonomi** – skrivebeskyttet, bekreft endringer (standard) eller autonom.
- **Egendefinert systemledetekst** – valgfrie instruksjoner som former hvordan assistenten svarer.
- **MCP-server** – en valgfri, kun-lokal server som lar en ekstern agent styre appen; av som standard og kan beskyttes med et token.

![AI-siden i Innstillinger med autonomi og MCP-servervalgene](screenshots/settings-ai.png)
*(Figur: Alle assistentvalg bor på én AI-side i Innstillinger.)*

## Personvern

- Med Apple Intelligence kjører assistenten **på din Mac**; ingenting forlater enheten.
- En skymodell brukes **bare hvis du konfigurerer en**, og API-nøkkelen dens holdes i nøkkelringen.
- Filendrende handlinger bekreftes før de kjører, med mindre du bevisst hever autonominivået.
