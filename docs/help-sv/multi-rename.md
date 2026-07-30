---
title: Byta namn på många filer
slug: multi-rename
section: Kraftverktyg
order: 92
related: [moving-and-renaming]
---

Verktyget för massnamnbyte byter namn på en hel bunt filer i en enda omgång. Istället för att redigera namn ett i taget beskriver du ändringen en gång – ett namngivningsmönster, en sök-och-ersätt, ett numreringsschema eller en ändring av bokstävers skiftläge – och Peach Commander tillämpar den på varje markerad fil. En liveförhandsvisning visar exakt vad varje fil kommer att heta innan något händer, och ett enda Ångra sätter tillbaka de ursprungliga namnen om resultatet inte blev vad du ville.

## Byt namn på en bunt filer

1. Markera filerna du vill byta namn på (se *Markera filer*). Endast de markerade objekten påverkas.
2. Välj **Kommandon > Verktyg för massnamnbyte…**, eller tryck på Ctrl+M.
3. Bygg din namnbytesregel med hjälp av fälten som beskrivs nedan. Förhandsvisningsrutnätet uppdateras medan du skriver och visar varje **Gammalt namn** bredvid sitt **Nytt namn**.
4. Kontrollera förhandsvisningen. En rad som visas i en markeringsfärg flaggar ett namn som inte kan användas (till exempel en dubblett eller ett otillåtet namn) så att du kan justera regeln.
5. När förhandsvisningen ser rätt ut, klicka på **Starta**. Om du ändrar dig, klicka på **Ångra** för att återställa de ursprungliga namnen.

![Fönstret för massnamnbyte med maskfälten, alternativen och förhandsvisningsrutnätet gammalt-till-nytt](screenshots/multi-rename.png)
*(Figur: Förhandsvisningsrutnätet uppdateras live medan du redigerar namnbytesregeln; ingenting ändras på disk förrän du klickar på Starta.)*

## Bygga namnbytesregeln

- **Namnbytesmask** och **Filtillägg** – mönster som bygger det nya namnet och filtillägget. Använd snabbinsättningsknapparna, eller skriv platshållare direkt: `[N]` för det ursprungliga namnet, `[N1-9]` för ett intervall av tecken från det, `[C]` för räknaren, `[d]` för datum- och tidsdelar, och `[P]` för den överordnade mappens namn.
- **Sök efter / Ersätt med** – ersätt text inuti namnen. Slå på **Regex** för mönstermatchning, **Skiftlägeskänslig** för att matcha exakt skiftläge, och **Upprepa** för att ersätta varje förekomst.
- **Skiftläge** – konvertera namn till gemener, VERSALER, Första bokstaven versal, eller Varje Ord Versalt.
- **Räknare** – ställ in **Start**-numret, **Steget** mellan filer, och hur många **Siffror** att fylla ut till (till exempel 001, 002, 003) varhelst `[C]` förekommer.

## Kortkommandon

| Åtgärd | Kortkommando |
| --- | --- |
| Öppna Verktyget för massnamnbyte | Ctrl+M |
| Tillämpa namnbytet | Return |
| Stäng fönstret | Esc |

## Tips

- Ingenting skrivs till disk förrän du klickar på **Starta**, så du kan experimentera fritt med regeln och titta på förhandsvisningen.
- Efter en körning vänder **Ångra** namnbytet i ett steg.
- Spara en regel du använder ofta som en **Förinställning**, och välj den sedan från förinställningsmenyn nästa gång för att fylla i alla fält på en gång.
- För att byta namn på en enskild fil, eller för att byta namn på filer medan du flyttar dem, använd namnbyte på plats eller flyttdialogen istället (se *Flytta och byta namn*).
