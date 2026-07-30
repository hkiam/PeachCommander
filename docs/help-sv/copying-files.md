---
title: Kopiera filer
slug: copying-files
section: Filer och mappar
order: 24
related: [moving-and-renaming, background-transfers]
---

Peach Commander är uppbyggt kring två paneler sida vid sida: den ena innehåller filerna du arbetar med, den andra är målet. Kopiering tar det som är markerat i den aktiva panelen och lägger en dubblett i mappen som visas i den andra panelen, medan originalen lämnas kvar. Det här är det snabbaste sättet att dubblera filer och mappar mellan två platser utan att dra.

## Kopiera ett urval till den andra panelen

1. Öppna i den ena panelen mappen som innehåller de objekt du vill kopiera.
2. Öppna i den andra panelen mappen dit kopiorna ska.
3. Markera filerna och mapparna som ska kopieras. Om inget är markerat används objektet under markören.
4. Tryck på F5. Kopieringsdialogen öppnas och visar målsökvägen redan ifylld.

![Kopieringsdialogen med målsökvägen och alternativ](screenshots/copy-dialog.png)
*(Figur: Kopieringsdialogen. Målsökvägen pekar mot den andra panelen; använd alternativen för att finjustera kopieringen.)*

5. Justera målet vid behov och bekräfta sedan för att starta kopieringen.

## Kopieringsalternativ

Innan du bekräftar kan du ändra hur kopieringen beter sig:

- **Endast nyare filer** – hoppar över objekt vars kopia redan finns och är lika gammal eller nyare, så att endast ändrade filer uppdateras.
- **Bevara metadata** – behåller datum, behörigheter och andra filattribut på kopiorna. Detta är påslaget som standard.
- **Hastighetsgräns** – begränsar överföringshastigheten så att en stor kopiering inte mättar din disk eller nätverksanslutning.
- **Namnbytesmask** – skriv ett jokermönster i målfältet (till exempel `*.bak`) för att byta namn på objekten allteftersom de kopieras.

Du kan också skicka jobbet till bakgrundskön istället för att titta på det – se Bakgrundsöverföringar.

## Förlopp

Ett förloppsfönster visar den aktuella filen och det övergripande jobbet med separata staplar, plus överföringshastigheten. Du kan pausa och återuppta när som helst, eller skicka den pågående kopieringen till hanteraren för bakgrundsöverföringar för att fortsätta arbeta medan den slutförs.

![Förloppsdialogen för överföring med en förloppsstapel, fil- och byteantal samt knapparna Pausa och Avbryt](screenshots/progress-dialog.png)
*(Figur: Förloppsdialogen som visas under en kopiering eller flytt.)*

## Hantera filer som redan finns

Om en kopiering skulle ersätta en befintlig fil stannar Peach Commander och frågar vad som ska göras. En förhandsvisning av båda filerna hjälper dig att bestämma.

![Konfliktdialogen för överskrivning som jämför två filer](screenshots/overwrite-dialog.png)
*(Figur: Överskrivningsdialogen jämför den befintliga filen med den som kopieras.)*

Dina val inkluderar:

- **Skriv över** den befintliga filen, eller **Skriv över alla** för att tillämpa det på varje återstående konflikt.
- **Hoppa över** den här filen, eller **Hoppa över alla** återstående konflikter.
- **Byt namn** på den inkommande kopian automatiskt så att båda filerna behålls.
- **Lägg till** inkommande data i slutet av den befintliga filen.
- Skriv över endast när källan är **nyare** eller **större** än den befintliga filen.

## Kortkommandon

| Åtgärd | Tangent |
|---|---|
| Kopiera urval till den andra panelen | F5 |
| Kopiera i samma mapp (skapa en omdöpt dubblett) | Shift+F5 |
| Öppna hanteraren för bakgrundsöverföringar | Cmd+Shift+B |

## Anteckningar

- Kopiering mellan två platser på samma disk använder en snabb klon när disken stöder det, så stora filer kopieras nästan omedelbart och använder lite extra utrymme.
- Mappar kopieras med allt som finns i dem.
- För att flytta filer istället för att kopiera dem, använd F6. För att titta på eller hantera köade jobb, öppna hanteraren för bakgrundsöverföringar med Cmd+Shift+B.
