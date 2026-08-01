---
title: Knappraden
slug: toolbar
section: Anpassning
order: 110
related: [keyboard-shortcuts, settings]
---

Knappraden är remsan med symbolknappar överst i fönstret. Varje knapp är en enklicks-genväg du själv definierar: kör ett inbyggt kommando, starta ett externt program eller en app, hoppa till en mapp, eller öppna en hel underrad med fler knappar. Det är det snabbaste sättet att ha de åtgärder du använder mest inom räckhåll, och du kan skräddarsy den precis efter hur du arbetar.

## Anpassa knappraden

1. Välj **Konfiguration > Anpassa verktygsrad…**, eller högerklicka på raden och välj **Redigera knappraden…**.
2. Listan till vänster visar de aktuella knapparna. Använd **+** för att lägga till en knapp, **—** för att lägga till en avdelare, **−** för att ta bort den markerade knappen, och **↑ / ↓** för att ordna om.
3. Markera en knapp och fyll i formuläret till höger:
   - **Kommando** — skriv ett inbyggt kommando, eller klicka på **Välj…** för att välja ett ur en lista. Du kan även ange sökvägen till ett program eller en app, en mapp att öppna, eller en annan knapprad att använda som underrad.
   - **Etikett** — namnet och verktygstipset som visas för knappen.
   - **Parametrar** och **Startsökväg** — skickas till externa program. Platshållare som `%P` (källmapp), `%N` (aktuell fil) och `%S` (markerade filer) fylls i när knappen körs.
   - **Symbol** — välj en SF Symbol eller använd en fils eller apps egen symbol; slå på **endast symbol** för att dölja etiketten.
4. Klicka på **Spara**. Remsan läses in på nytt direkt.

![Knappraden överst i fönstret med symbolknappar](screenshots/button-bar-crop.png)
*(Bild: Knappraden sitter ovanför filpanelerna; varje knapp kör ett kommando, program, en mapp eller en underrad.)*

## Underrader och spill

En knapp kan öppna en *underrad* — en andra uppsättning knappar lagd ovanpå den första. Klicka på den för att gå ned; en **◀**-knapp till vänster tar dig tillbaka till föregående rad. När det finns fler knappar än vad fönsterbredden rymmer, fälls de extra ihop bakom en **»**-pil längst till höger; klicka på den för att nå dem.

## Lägg till ett program genom att släppa det på raden

Du behöver inte öppna redigeraren för att lägga ett verktyg på raden. Dra ett program, en app eller ett skript från en panel — eller från Finder — till **ledigt utrymme** på raden. Ett streck visar var det hamnar; när du släpper skapas knappen där.

- **Program, appar och skript** blir en knapp som kör dem på ditt aktuella urval: den nya knappens parametrar är `%S`, de markerade filnamnen. Töm det fältet i redigeraren för ett verktyg som inte ska få några argument.
- **Mappar** blir en knapp som hoppar dit — och som kopierar filer dit när du senare släpper dem på den.
- Det som inte går att köra avvisas: ett vanligt dokument saknar körrättighet, och en knapp för det skulle bara misslyckas vid klick.

Att släppa på en **befintlig** knapp behåller dess betydelse: knappen körs med de släppta filerna. Bara ledigt utrymme skapar en ny.

## Släpp filer på en knapp

Du kan dra filer eller mappar rakt på en knapp:

- **Mappknapp** — de släppta objekten kopieras in i den mappen i bakgrunden.
- **Programknapp** — programmet körs med de släppta objekten som sin markering.
- **Kommandoknapp** — kommandot körs som vanligt.

## Dölj knappraden

Välj **Visa > Knapprad** för att dölja raden, och igen för att ta tillbaka den. Samma reglage finns på sidan **Layout** i inställningarna, och valet kommer ihåg.

## Vertikal knapprad

För att flytta remsan från fönstrets överkant till en kolumn längs vänster sida, välj **Visa > Vertikal knapprad**. Välj det igen för att växla tillbaka till den vågräta remsan.

## Anmärkningar

- Raden lagras i en standardknappradsfil som är kompatibel med Total Commander, så rader du redan har kan återanvändas.
- Inga kortkommandon är tilldelade dessa åtgärder som standard, men du kan lägga till egna — se [Kortkommandon](keyboard-shortcuts).
- En knapp utan symbol och utan kommando visas som en enkel avdelare, behändigt för att gruppera relaterade knappar.
