---
title: Huvudfönstret
slug: interface-overview
section: Kom igång
order: 12
related: [navigating, panels-and-tabs]
---

Peach Commander visar två fillistor sida vid sida så att du samtidigt kan se var filer kommer ifrån och vart de är på väg. Det mesta av ditt arbete sker i dessa två paneler; fälten runt dem låter dig byta enhet, hoppa till en mapp, och köra de vanliga filkommandona utan att lämna tangentbordet. Den här rundturen namnger varje del av fönstret så att resten av hjälpen blir begriplig.

![Peach Commanders huvudfönster med sina två paneler och omgivande fält](screenshots/main-window.png)
*(Figur: Huvudfönstret – två paneler med knappfältet, enhetsfältet och sökvägsfälten ovanför och funktionstangentsfältet nedanför.)*

## De två panelerna och den aktiva panelen

Fönstret är delat i en vänster panel och en höger panel, som var och en visar innehållet i en mapp. Endast en panel är aktiv åt gången: den visar markören (en markerad rad) och dess sökvägsfält ritas med en färgad bakgrund. Kommandon som kopiera och flytta agerar alltid på den aktiva panelen och skickar filer till den andra.

1. Klicka var som helst i en panel för att göra den aktiv, eller tryck på Tab för att växla mellan dem.
2. Använd piltangenterna för att flytta markören upp och ned i den aktiva panelen.
3. Tryck på Enter på en mapp för att öppna den, eller på `..` högst upp i listan för att gå upp en nivå.

## Fält runt panelerna

- **Knappfält** (överst): en rad platta knappar för vanliga kommandon. Klicka på en knapp för att köra dess kommando; högerklicka på en knapp för att redigera fältet.
- **Enhetsrad**: en knapp per tillgänglig disk eller volym, var och en med sitt lediga utrymme. Klicka på en volym för att växla den panelen dit; högerklicka för att mata ut den — erbjuds för flyttbara volymer och monterade skivavbilder, nedtonat för startskivan och nätverksresurser. Insticksmoduler kan bidra med egna enheter — Task Manager är en av dem — och de beter sig som vilken annan volym som helst: panelen växlar dit, knappen förblir vald och fliken får enhetens namn. Varje knapp bär volymens eget symbol — samma som Finder visar — så att en hårddisk, ett USB-minne, en monterad skivavbild och en nätverksresurs går att skilja åt med en blick.
- **Sökvägsfält**: visar den aktuella mappen som en klickbar brödsmula. Klicka på ett segment för att hoppa direkt till den mappen, eller klicka på sökvägen för att skriva en plats.
- **Statusfält** (under varje lista): en löpande sammanfattning av panelen – hur många filer och mappar som är markerade och deras totala storlek.
- **Kommandorad** (nederst): ett textfält där du kan skriva ett skalliknande kommando som körs i den aktuella mappen.
- **Funktionstangentsfält** (allra nederst): sex knappar märkta F3 Visa, F4 Redigera, F5 Kopiera, F6 Flytta, F7 NyMapp och F8 Ta bort. Klicka på en knapp eller tryck på den matchande tangenten.

![Närbild av enhetsfältet som visar volymknappar och ledigt utrymme](screenshots/drive-bar-crop.png)
*(Figur: enhetsraden — en knapp per volym, med återstående ledigt utrymme; högerklicka på en volym för att mata ut den.)*

## Kortkommandon

| Åtgärd | Kortkommando |
|---|---|
| Byt aktiv panel | Tab |
| Öppna mapp/objekt under markören | Enter |
| Gå upp en mapp | Backspace |
| Visa fil | F3 |
| Redigera fil | F4 |
| Kopiera till den andra panelen | F5 |
| Flytta/byt namn till den andra panelen | F6 |
| Ny mapp | F7 |
| Ta bort (till papperskorgen) | F8 |

## Anteckningar

- Funktionstangentsfältet märker om sig självt live när du håller ned en modifierare. Att hålla ned Shift ändrar till exempel F6 till en åtgärd för att byta namn på plats, så att knapparna alltid visar vad tangenterna gör just nu.
- Nästan varje fält kan visas eller döljas. Titta under menyerna Visa och Konfiguration för att slå av och på knappfältet, enhetsfältet, kommandoraden eller funktionstangentsfältet, eller för att stapla de två panelerna överst och nederst istället för sida vid sida.
- På många Mac-tangentbord fungerar F-tangenterna som media- och ljusstyrkekontroller som standard. Håll ned Fn-tangenten tillsammans med F3–F8, eller slå på "Använd F1-, F2- osv. tangenter som standardfunktionstangenter" i Systeminställningar, för att använda dem direkt.
