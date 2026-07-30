---
title: Disk Map
slug: disk-map
section: Insticksprogram
order: 121
related: [plugins, deleting-files, settings]
---

Disk Map är ett inbyggt insticksprogram som med en blick visar vad som använder utrymme i en mapp eller på en hel volym. Det skannar mappen du väljer och ritar varje objekt dimensionerat i proportion till det utrymme det faktiskt upptar på disk, så att de största utrymmesslukarna sticker ut omedelbart. Du kan borra ned i mappar, se hur din skanning stämmer av mot volymens fria, rensbara och dolda utrymme, och städa upp direkt från kartan.

## Starta en skanning

1. Gå i den aktiva panelen till mappen (eller volymen) du vill mäta.
2. Välj **Kommandon ▸ Disk Map: Analysera aktuell mapp**.
3. Disk Map-vyn öppnas till höger och skannar i bakgrunden, och visar ett löpande antal objekt och byte. Stora mappar blir klara på några sekunder – skanningen läser katalogmetadata i bulk och arbetar över flera CPU-kärnor.

![Disk Map som visar en kvadratifierad treemap av en mapp, en volymstapel, en lista över de största filerna och en kategorilegend](screenshots/disk-map.png)
*(Figur: Treemap-vyn, färgad efter filkategori, med volymstapeln överst och listan över de största filerna till höger.)*

## Läs kartan

- Varje block (treemap) eller ringsegment (sunburst) dimensioneras efter objektets **faktiska storlek på disk**, så att bilden matchar vad Finder och systemet rapporterar.
- Block är **färgade efter filtyp** – video, bilder, ljud, dokument, kod, arkiv, appar, diskavbildningar – med en legend längs botten. Du kan växla till en storleks-**heatmap** i inställningarna.
- **Klicka på en mapp** för att borra ned i den; brödsmulan högst upp visar var du är, och knappen **◂** stegar tillbaka upp.
- Hovra över valfritt block för att se dess fullständiga sökväg, storlek och objektantal.

## Två vyer: treemap och sunburst

Disk Map erbjuder två visualiseringar, och du kan växla mellan dem med knappen **◎ / ▦** i rubriken eller på inställningssidan:

- **Treemap** – nästlade rektanglar, tätast för att upptäcka den enskilt största filen.
- **Sunburst** – koncentriska ringar (en per mappdjup) runt den aktuella mappen, bäst för att se hur utrymme fördelas över ett djupt träd.

![Disk Maps sunburst-vy som visar koncentriska ringar för mappdjup](screenshots/disk-map-sunburst.png)
*(Figur: Sunburst-vyn – den inre skivan är den aktuella mappen och varje ring är en nivå djupare.)*

## Volymstapeln

Stapeln överst stämmer av din skanning mot hela volymen:

- **Skannat / Den här mappen** – hur mycket den analyserade mappen upptar.
- **Dolt** (vid volymens rot) eller **Resten av volymen** (för en undermapp) – allt som inte ingår i denna skanning, inklusive systemskyddade mappar, andra användare och ögonblicksbilder.
- **Rensbart** – utrymme som macOS kan återvinna automatiskt, mestadels lokala Time Machine-ögonblicksbilder och cacheminnen.
- **Fritt** – utrymme som är tillgängligt just nu.

När volymen har lokala ögonblicksbilder visar stapeln en **· N ögonblicksbilder (ⓘ)**-hänvisning; klicka på den för en skrivskyddad lista, med ett tips om att hantera dem i Skivverktyg eller Time Machine. Disk Map tar aldrig bort ögonblicksbilder själv.

## Största filerna

Slå på **Visa listan över de största filerna** för att se de största filerna i den aktuella mappen rangordnade efter storlek, var och en med en färgbricka för sin kategori. Klicka på en för att lyfta fram den på kartan.

## Städa upp från kartan

Högerklicka på valfritt block för åtgärder:

- **Öppna i vänster panel** / **Öppna i höger panel** – visa objektet i en filpanel.
- **Visa i Finder**.
- **Flytta till papperskorgen** – ta bort bara det objektet; kartan uppdateras utan en fullständig omskanning.

För att ta bort flera objekt på en gång, använd **Samlaren**: högerklicka ▸ **Markera för samlaren** på varje objekt, och klicka sedan på knappen **🗑 N** i rubriken för att flytta allt du markerat till papperskorgen i ett bekräftat steg.

## Inställningar

Disk Map lägger till sin egen sida i inställningsfönstret (**Konfiguration ▸ Inställningar ▸ Disk Map**):

- **Diagramstil** – treemap eller sunburst.
- **Färgkodning** – efter filtyp (kategori) eller efter storlek (heatmap).
- **Stanna kvar på startvolymen** – korsa inte in i andra monterade diskar.
- **Visa volymstapeln** och **Visa listan över de största filerna**.

Ändringar tillämpas på en öppen Disk Map omedelbart.

## Anteckningar

- Disk Map mäter **allokerad** storlek (på disk) och räknar **hårdlänkade** filer endast en gång, så att dess summor stämmer med volymens använda utrymme snarare än att räknas dubbelt.
- Som standard stannar skanningen på startvolymen, så den vandrar inte in i andra monterade diskar eller nätverksresurser.
