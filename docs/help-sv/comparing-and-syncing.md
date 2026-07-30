---
title: Jämföra och synkronisera
slug: comparing-and-syncing
section: Kraftverktyg
order: 90
related: [multi-rename]
---

När du håller två kopior av samma mapp – en arbetsmapp och en säkerhetskopia, en bärbar dator och en nätverksresurs, ett projekt och dess arkiv – hjälper Peach Commander dig att se exakt vad som ändrats och få de två sidorna i takt igen. Du kan synkronisera två kataloger, jämföra enskilda filer rad för rad, och granska filer byte för byte när du behöver säkerhet ända ned till sista tecknet.

## Synkronisera två kataloger

1. Öppna mappen du vill synkronisera i den vänstra panelen och mappen att jämföra den mot i den högra panelen.
2. Välj **Kommandon ▸ Synkronisera kataloger…**. De två mappsökvägarna fylls i från dina paneler.
3. Ställ in hur noggrann jämförelsen ska vara: inkludera undermappar, jämför **efter innehåll** (inte bara efter datum och storlek), eller ignorera ändringsdatumet.
4. Lägg till en filtermask (till exempel `*.jpg;*.png`) om du bara vill synkronisera vissa filer.
5. Granska resultatrutnätet. Varje rad visar en fil till vänster, en riktningspil i mitten, och den matchande filen till höger. Pilarna berättar vad som kommer att hända: **→** kopierar vänster till höger, **←** kopierar höger till vänster, och **=** betyder att de två är identiska.
6. Justera enskilda rader om du inte håller med om en föreslagen riktning, och klicka sedan på synkroniseringsknappen för att genomföra ändringarna.

![Fönstret för att synkronisera kataloger med två mappsökvägar och ett resultatrutnät av filer med vänster-, likhets- och högerpilar](screenshots/sync-dialog.png)
*(Figur: Fönstret Synkronisera kataloger jämför båda sidorna och föreslår en kopieringsriktning för varje fil.)*

## Jämför två filer efter innehåll

1. Markera en fil i varje panel (eller två filer i samma panel).
2. Välj **Arkiv ▸ Jämför efter innehåll…**.
3. De två filerna öppnas sida vid sida med sina skillnader markerade. Använd kontrollerna för nästa/föregående för att hoppa mellan ändrade block.
4. Om du slår på redigeringsläge kan du justera endera filen direkt och spara dina ändringar.

![Jämförelsefönstret som visar två textfiler sida vid sida med avvikande rader markerade](screenshots/diff-window.png)
*(Figur: Jämförelse av två textfiler; ändrade rader är markerade på båda sidorna.)*

## Jämför filer byte för byte

När två filer ser likadana ut men du behöver bevisa att de verkligen är identiska (eller hitta den enda byte som skiljer sig), använd den binära jämförelsen. Den visar båda filerna i en hex-vy med avvikande byte markerade, vilket är idealiskt för att verifiera nedladdningar, kontrollera kodad data eller bekräfta en exakt kopia.

## Jämför kataloglistor

För att upptäcka skillnader mellan två öppna mappar med en blick, välj **Markera ▸ Jämför kataloger** (Shift+F2). Peach Commander markerar filerna som skiljer sig eller saknas på den andra sidan, så att du kan agera på dem med de vanliga kommandona för kopiera, flytta och ta bort.

## Kortkommandon

| Åtgärd | Kortkommando |
| --- | --- |
| Jämför kataloglistor (markera avvikande filer) | Shift+F2 |
| Jämför efter innehåll | Arkiv ▸ Jämför efter innehåll… |
| Synkronisera kataloger | Kommandon ▸ Synkronisera kataloger… |

## Anteckningar

- **Efter innehåll kontra efter datum/storlek.** En snabb jämförelse matchar filer efter storlek och ändringsdatum, vilket är snabbt men kan luras när tidsstämplar skiljer sig för identiska filer. Slå på **efter innehåll** för ett tillförlitligt resultat på bekostnad av att varje fil läses.
- **Undermappar och filter.** Synkroniseringsfönstret kan gå ned i undermappar och kan begränsas med en filtermask, så att du kan synkronisera bara de filtyper du bryr dig om.
- **Du behåller kontrollen.** Synkronisering körs aldrig av sig själv – du granskar de föreslagna riktningarna i resultatrutnätet och kan ändra vilken som helst av dem innan något kopieras.
- **Förinställningar.** Ofta använda synkroniseringsuppsättningar kan sparas och återanvändas så att du slipper ange samma alternativ varje gång.
