---
title: Global historik
slug: history
section: Organisera vyn
order: 47
related: [favorites, navigating]
---

Den globala historiken är ett fönster som minns ditt eget arbete: mappar du besökt, filer du öppnat, åtgärder du utfört och kommandon du kört. Tryck Ctrl+Cmd+H var du än är, börja skriva, och du är tillbaka i gårdagens mapp på en sekund — utan mus.

## Öppna historiken

1. Tryck Ctrl+Cmd+H eller välj **Gå > Historik…**. Vilken panel som är aktiv spelar ingen roll.
2. Skriv några bokstäver. Träffen behöver varken vara exakt eller sammanhängande: `proj rep` hittar `~/Projects/annual-report.txt`.
3. Gå genom resultaten med Upp- och Ner-tangenterna medan du fortsätter skriva.
4. Retur agerar på den markerade posten, Esc stänger fönstret.

Posterna rangordnas efter hur nyligen *och* hur ofta du använt dem, så platserna där du arbetar mest ligger redan högst upp. Fästa poster går alltid först.

![The global history window listing recently visited folders and opened files](screenshots/history-palette.png)
*(Figur: Den globala historiken — sökfältet har fokus och listan rangordnas efter hur nyligen och hur ofta du använt varje post.)*

## Filtrera efter typ

Knapparna under sökfältet begränsar listan till alla poster, mappar, filer, åtgärder eller favoriter. Option+1 till Option+5 växlar mellan dem från tangentbordet.

## Göra något med en post

| Åtgärd | Kortkommando |
| --- | --- |
| Öppna den markerade posten | Return |
| Visa den i panelen, med markören på den | Option+Return |
| Öppna en av de nio mest relevanta posterna | Cmd+1 … Cmd+9 |
| Byta panel som poster öppnas i | Tab |
| Fästa eller lossa posten | Cmd+P |
| Ta bort posten från historiken | Cmd+Delete |
| Kopiera postens sökväg | Option+Cmd+C |
| Visa posten i Finder | Cmd+Shift+R |
| Stänga historiken | Esc |

Retur gör det posten förtjänar: en mapp öppnas i målpanelen, en fil öppnas som den skulle från panelen, och en kommandorad läggs i kommandoraden så att du kan läsa igenom den och köra den. Målpanelen står längst ner i fönstret och Tab byter den.

## Upprepa en åtgärd

En kopiering eller flytt visas under **Åtgärder**, och Retur kör den igen — samma objekt till samma mapp, genom den vanliga överföringskön och dess frågor om överskrivning. Objekt som inte längre finns hoppas över, och finns inget kvar får du veta det.

Raderingar och namnbyten listas men upprepas aldrig: Retur visar i stället var de skedde. Att upprepa en radering ska inte ligga en tangent bort i en lista man bara skummar.

## Hålla den i schack

Inställningar ▸ Övrigt avgör om en historik förs, hur många poster den behåller och efter hur många dagar de glöms. Fästa poster är undantagna och 0 dagar behåller allt; listan finns i `history.ini` i din konfigurationsmapp och överlever omstarter.

## Anmärkningar

- Att öppna något ur historiken räknas som användning — därför fortsätter det du återvänder till att stiga.
- Mappar inne i ett arkiv, på en server eller i en pluginenhet minns inte: en sådan sökväg betyder ingenting utan den montering som gav den, och panelens egen historik behåller dem så länge den är öppen.
- Detta är inte panelens egen mapphistorik på Alt+Ner, som bara listar var just den panelen har varit, i ordning.
