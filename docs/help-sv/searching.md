---
title: Hitta filer
slug: searching
section: Hitta filer
order: 60
related: [selecting-files, quick-search-and-filter]
---

När du behöver spåra upp filer var som helst på din Mac — efter namn, efter innehåll, eller efter storlek och datum — använd fönstret Hitta filer. Det söker i en eller flera mappar (och deras undermappar), kan titta inuti textfiler och arkiv, och låter dig skicka allt det hittar direkt in i en panel så att du kan agera på resultaten som om de vore en vanlig mapp.

## Hitta filer efter namn

1. I panelen som visar mappen du vill söka i, välj **Kommandon > Hitta filer…** (eller tryck på Cmd+Shift+F).
2. På fliken **Allmänt**, skriv ett namnmönster i **Sök efter**. Du kan använda jokertecken som `*.pdf` eller `report_*.docx`. För att söka i flera mappar samtidigt, lista dem i startmappsfältet åtskilda med semikolon (`;`).
3. Klicka på **Starta**. Matchningar visas i resultatlistan nedan allteftersom de hittas.
4. Dubbelklicka på ett resultat för att hoppa till den filen i den aktiva panelen, eller markera ett resultat och klicka på **Visa** (F3) för att öppna det i den inbyggda visaren.

![Fönstret Hitta filer på fliken Allmänt, som visar namnmönster, mapp och resultatlista](screenshots/find-files-general.png)
*(Bild: Fliken Allmänt — sök efter namnmönster i en eller flera mappar.)*

## Sök efter innehåll, storlek och datum

1. För att söka inuti filer skriver du texten i **Sök text** på fliken Allmänt — det som står i fältet söks efter, och ett tomt fält söker bara på namn. Alternativ låter dig göra den **Skiftlägeskänslig**, matcha endast ett **Helt ord**, behandla texten som ett **Reguljärt uttryck**, göra en **Hexadecimal innehållssökning**, eller hitta filer som **Inte innehåller** texten.
2. Växla till fliken **Avancerat** för att smalna av resultaten efter **Storlek** (till exempel `10K` till `5M`), efter **ändringsdatum**-intervall, eller till filer ändrade de senaste N dagarna.
3. Slå på **Sök inuti arkiv** för att titta in i arkiven som hittas — samma format som du kan öppna med Retur, inklusive de som ett packar-tillägg lägger till. Arkiv som inte kunde öppnas rapporteras när sökningen är klar.
4. För att begränsa sökningen till det du redan valt, slå på **Sök endast i markerade objekt** innan du startar.
5. Slå på **Sök även i filkommentarer** och texten söks i varje fils kommentar utöver dess innehåll. Så hittar du en fil igen via det du skrev *om* den — ”kundens original”, ”ersatt av 2026-exporten” — när inget sådant står i själva filen. Ett träff som hittas så visar kommentaren i stället för en rad ur filen, och inget radnummer, eftersom träffen inte finns i filens text. Skiftläge, helt ord och reguljära uttryck gäller för en kommentar precis som för innehåll; en hex-sökning gör det inte, eftersom en kommentar är text någon skrivit. **Innehåller inte** förblir konsekvent: en fil listas när texten varken finns i innehållet eller i kommentaren. Är insticksmodulen Anteckningar påslagen finns dess anteckning som ett innehållsfält, som du kan filtrera på under **Plugins** — se [Arbeta med insticksmoduler](plugins.md).
6. Vissa insticksmoduler kan göra en fil till text som filen själv inte innehåller — dekompilator-modulen gör en `.class` till Java-källkod. Slå på **Sök i text som insticksmoduler tillhandahåller** och sådana filer söks som den texten i stället för som sina egna byte, så att en formulering ur källkoden hittas i en kompilerad klass. Alternativet visas bara när en sådan modul är installerad, och det är långsammare: att skapa texten kan innebära en dekompilator per fil.

![Fönstret Hitta filer på fliken Avancerat, som visar storleks- och datumfilter](screenshots/find-files-advanced.png)
*(Bild: Fliken Avancerat — filtrera efter storlek, datum och andra attribut.)*

Om du har insticksprogram som lägger till innehållsfält (som bildmått) låter fliken **Insticksprogram** dig kräva att ett fält matchar ett villkor — till exempel endast bilder bredare än 1000 pixlar.

![Fönstret Hitta filer på fliken Insticksprogram, som visar ett innehållsfältvillkor](screenshots/find-files-plugins.png)
*(Bild: Fliken Insticksprogram — matcha på innehållsfält från insticksprogram.)*

## Snabba sökningar med Spotlight

För lokala mappar som macOS redan har indexerat, slå på **Använd Spotlight** på fliken Allmänt för nästan omedelbara resultat. Spotlight söker i indexet i stället för att söka igenom filer, så det ignorerar reguljära uttryck, undermappsdjupgränser och endast-markerade-omfånget.

## Återanvänd och lämna över dina resultat

- **Skicka till lista** placerar varje resultat i den aktiva panelen som en tillfällig lista, så att du kan kopiera, flytta eller radera hela uppsättningen på en gång.
- På fliken **Läs in / Spara**, välj **Spara som mall…** för att lagra den aktuella sökningen (mönster och alternativ) och välja den igen senare från mall-listan.
- **Sök efter** och **Sök text** kommer vardera ihåg de 20 senaste posterna du sökt med, senast använda först — klicka på pilen i slutet av fältet för att välja en igen. Ett uttryck som används två gånger flyttas överst i stället för att stå med två gånger, och listorna överlever både att fönstret stängs och att appen avslutas. **Rensa historiken…** på fliken **Läs in / Spara** glömmer bort båda; sparade mallar påverkas inte.

## Kortkommandon

| Åtgärd | Kortkommando |
| --- | --- |
| Öppna Hitta filer | Cmd+Shift+F eller Option+F7 |
| Starta / stoppa sökningen | Starta-knappen i fönstret |
| Visa det markerade resultatet | F3 |

## Anmärkningar

- Innehållssökning läser hela filer för lokala mappar och för arkiv; på nätverksplatser läses mycket stora filer bara delvis (ungefär 16 MB, eller 64 MB med ett reguljärt uttryck).
- Sökning inuti arkiv går ner upp till fyra nivåer av nästlade arkiv.
- **Inkludera mappar i resultaten** listar även mappar vars namn matchar, inte bara filer.
- Spotlight täcker endast indexerade lokala mappar; för nätverksplatser eller mönsterbaserad matchning, lämna det av och låt Hitta filer söka igenom.
