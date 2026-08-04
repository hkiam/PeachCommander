---
title: Visningslägen och sortering
slug: view-modes-and-sorting
section: Organisera vyn
order: 42
related: [panels-and-tabs, quick-search-and-filter]
---

Varje panel kan visa sin mapp i den layout som passar uppgiften: en detaljerad lista med kolumner, en kompakt flerkolumnslista med namn, ett symbolrutnät, ett galleri med stora miniatyrer, eller ett mappträd. Du kan även sortera listan efter namn, filändelse, storlek eller datum, välja exakt vilka kolumner som visas, och slå på naturlig (numerisk) sortering så att namn med siffror ställer upp sig som du förväntar dig. Visningsläge, sorteringsordning och kolumner ställs in per panel, så de två sidorna kan se helt olika ut.

## Byt visningsläge

1. Klicka på panelen du vill ändra så att den blir aktiv.
2. Öppna Visa-menyn och välj ett läge: **Fullständig (detaljer)** för kolumnlistan, **Kort (kolumner)** för en tät flerkolumnslista med namn, **Symboler** för ett symbolrutnät, **Miniatyrer (galleri)** för stora förhandsvisningar, eller **Träd** för ett mappträd.
3. För att snabbt bläddra igenom lägena utan att öppna menyn, tryck på Cmd+Shift+M. Varje tryck går till nästa läge.

![En panel som visar de olika visningslägena: detaljer, kort, symboler och galleri](screenshots/view-modes.png)
*(Bild: Samma mapp visad som en detaljerad lista, en kort kolumnlista, ett symbolrutnät och ett galleri med miniatyrer.)*

## Sortera fillistan

1. I detaljvyn, klicka på en kolumnrubrik (Namn, Ändelse, Storlek eller Datum) för att sortera efter den. En liten pil i rubriken visar den aktuella sorteringskolumnen och riktningen.
2. Klicka på samma rubrik igen för att vända ordningen.
3. Du kan även välja Visa > Sortera efter och välja Namn, Filändelse, Storlek, Datum eller Osorterat.

Mappar sorteras alltid tillsammans överst, före filer, och `..`-posten som tar dig upp en nivå står kvar fäst först. Sortering efter namn eller filändelse är stigande (A till Ö) som standard; sortering efter storlek eller datum är nyast eller störst först som standard.

## Välj vilka kolumner som visas

1. Välj Konfiguration > Kolumner….
2. Slå på eller av kolumner och ställ in deras ordning. Tillgängliga kolumner är Namn, Ändelse, Storlek, Datum, Attr (attribut), Taggar och Kommentar.
3. Tillämpa dina ändringar. Kolumner påverkar den aktiva panelens detaljvy.

![Kolumnkonfigurationsfönstret med listan över tillgängliga kolumner](screenshots/columns-config.png)
*(Bild: Välj vilka kolumner som visas i detaljvyn och ställ in deras ordning.)*

## Kortkommandon

| Åtgärd | Kortkommando |
|---|---|
| Bläddra genom visningslägen | Cmd+Shift+M |
| Kort (kolumner)-vy | Ctrl+F1 |
| Fullständig (detaljer)-vy | Ctrl+F2 |
| Miniatyrer (galleri)-vy | Ctrl+Shift+F1 |
| Trädvy | Ctrl+F8 |
| Sortera efter namn | Ctrl+F3 |
| Sortera efter filändelse | Ctrl+F4 |
| Sortera efter storlek | Ctrl+F5 |
| Sortera efter datum | Ctrl+F6 |

## Tips

- Naturlig (numerisk) sortering är på som standard, så `file2` kommer före `file10` i stället för efter. Du kan stänga av den i Konfiguration > Alternativ under visningsinställningarna.
- Du kan bredda eller smalna av en kolumn i detaljvyn genom att dra i avdelaren mellan kolumnrubrikerna.
- Om du använder macOS' tangentbordsnavigering (Systeminställningar ▸ Tangentbord) tillhör raden Ctrl+F1 till Ctrl+F8 systemet — menyraden, Dock, verktygsfältet — och den når aldrig Peach Commander. Ställ tangentschemat på **macOS** i inställningarna, då ligger visningslägena på Cmd+1, Cmd+2 och Cmd+3 och sorteringen på Alt+Cmd+1 till Alt+Cmd+4.
- Visningsläge, sorteringsordning och kolumnval kommer ihåg per panel, så du kan ha den ena sidan som en detaljerad lista och den andra som ett fotogalleri.
