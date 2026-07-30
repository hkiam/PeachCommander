---
title: Integritet och säkerhet
slug: privacy-and-security
section: macOS och integritet
order: 132
related: [ftp-and-sftp, troubleshooting]
---

Peach Commander är byggt för att hålla sig ur vägen och behålla dina data på din Mac. Lösenord lämnas till macOS nyckelring, kraschinformation lämnar aldrig din dator utan ditt medgivande, och appen samlar ingen användningsstatistik. Det här ämnet förklarar var din känsliga information finns och hur du beviljar den enda systembehörighet som en filhanterare behöver för att göra sitt jobb.

## Var lösenord lagras

Alla lösenord eller nyckellösenfraser du sparar — för en FTP- eller SFTP-anslutning, eller för att öppna ett lösenordsskyddat arkiv — skrivs till macOS **nyckelring**, samma säkra lager som systemet använder för dina Wi-Fi- och webbinloggningar. Lösenord skrivs aldrig i klartext till Peach Commanders egna inställningar eller anslutningsfiler.

1. När du sparar ett anslutnings- eller arkivlösenord, välj alternativet att komma ihåg det.
2. Lösenordet lagras i din inloggningsnyckelring, skyddad av ditt konto.
3. För att granska eller ta bort ett sparat lösenord senare, öppna appen **Nyckelhanterare** (i Program ▸ Verktygsprogram) och sök på anslutningens namn.

## Bevilja fullständig diskåtkomst

macOS håller vissa platser privata — Mail, Meddelanden och andra appars data i din biblioteksmapp — tills du uttryckligen tillåter åtkomst. Eftersom en filhanterare är tänkt att nå varje fil ber Peach Commander om **Fullständig diskåtkomst**. Appen fortsätter att fungera med begränsad åtkomst tills du beviljar den; du ser bara inte de skyddade mapparna.

1. Välj **Kommandon ▸ Fullständig diskåtkomst…**, eller klicka på **Öppna Systeminställningar** när appen erbjuder sig att vägleda dig vid start.
2. I **Systeminställningar ▸ Integritet och säkerhet ▸ Fullständig diskåtkomst**, slå på reglaget bredvid Peach Commander.
3. Starta om appen om du uppmanas.

## Kraschrapporter stannar lokalt

Om appen avslutas oväntat skriver macOS en kraschrapport till din egen diagnostikmapp. Vid nästa start upptäcker Peach Commander den och erbjuder sig att hjälpa dig att skicka in en felrapport — men bara med ditt medgivande.

- Du kan välja **Visa i Finder** för att se rapporten, eller **Kopiera rapport till urklipp** för att själv klistra in den i en felrapport.
- Ingenting överförs någonsin automatiskt, och ingen kraschrapporteringstjänst från tredje part är inblandad.

## Anmärkningar

- **Ingen telemetri.** Peach Commander spårar inte din aktivitet och skickar ingen användningsstatistik någonstans.
- **Begränsad åtkomst är säker.** Om du hoppar över Fullständig diskåtkomst bläddrar och hanterar appen fortfarande de filer du normalt kan se; endast systemskyddade platser döljs.
- **Du styr sparade lösenord.** Eftersom inloggningsuppgifter finns i nyckelringen hanterar och återkallar du dem med vanliga macOS-verktyg i stället för inuti appen.
