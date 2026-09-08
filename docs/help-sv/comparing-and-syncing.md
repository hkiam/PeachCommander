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

## Begränsa vad en synkronisering omfattar

Maskfältet innehåller en ta-med-lista över filnamn. För det som inte går att uttrycka där öppnar **Filter…** intill ett ark med tre flikar. Det som ställs in där gäller den *nästa* jämförelsen, och knappen säger sedan hur många kriterier som är aktiva — ett filter man inte ser är hur en säkerhetskopia slutar ofullständig medan fönstret rapporterar att den är klar.

- **Uteslut** tar mönster åtskilda med `;` eller `|`. Ett namn utan snedstreck träffar på varje djup (`*.tmp`), ett snedstreck sist betyder en mapp med allt i den (`node_modules/`), och ett mönster med snedstreck träffar den relativa sökvägen (`src/*/generated`). Skillnad på stora och små bokstäver görs inte.
- **Storlek** och **datum** bedömer ett par som helhet: faller en sida utanför intervallet hålls hela paret utanför. Det är avsiktligt. Tillämpad på bara en sida skulle en uteslutning få paret att se ensidigt ut och bli en kopiering i fel riktning.
- **Under de senaste N dagarna** mäts från varje jämförelse, inte från när en förinställning sparades — ett sparat jobb betyder alltså fortfarande "den senaste månaden".
- Fliken **Tillägg** frågar ett innehållstillägg om den sida en fil skulle kopieras från. Det behöver en verklig fil, så den erbjuds bara när båda sidorna är mappar på den här Mac-datorn.

En utesluten mapp tas inte bort i spegelläge heller — en spegel tar bara bort det den verkligen har jämfört. Statusraden säger hur många poster filtret undanhöll, intill vad körningen kommer att göra. Ett filter sparas och läses in med den synk-förinställning det hör till.

## Håll två mappar lika, i båda riktningarna

De två ursprungliga läggena kan inte skilja på en sak: en fil som bara finns på den ena sidan är
antingen **ny här** eller **borttagen där**, och det ser likadant ut. Det symmetriska läget kopierar
den därför — ta bort något på den bärbara, synkronisera, och den kommer tillbaka från säkerhets-
kopian — och spegelläget tar bort, men bara i en riktning.

**Tvåvägs (med minne)** minns hur båda mapparna såg ut senast de stämde. Med den uppgiften kan en
borttagning på den ena sidan föras över till den andra.

- Den **första** körningen för ett par har ingen uppgift: den beter sig som förut och tar inte bort
  något. Den skriver uppgiften. Från andra körningen gör läget sitt arbete.
- En överförd borttagning visas i egen färg med `⇒🗑` och är **inte** ikryssad: det är den enda raden
  som kommer från appens minne. Ett klick på pilen erbjuder de andra svaren: kopiera tillbaka filen i
  stället, eller låta båda sidor vara.
- Ändrad på den ena sidan och borttagen på den andra är en **konflikt**, aldrig en borttagning. Samma
  gäller en fil som ändrats på båda sidor.
- Inget tas bort på grund av en frånvaro som jämförelsen inte kunde bekräfta.
- Bara två mappar på den här Mac-datorn, inte en server och inte ett arkiv.

**Det finns ingen ångra för en borttagning.** På den här datorn hamnar filen i Papperskorgen och kan
hämtas tillbaka i Finder; det är hela skyddsnätet. Uppgiften ligger med inställningarna: flyttar du en
av mapparna har paret ingen historia längre — och en körning utan historia tar inte bort något.

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

