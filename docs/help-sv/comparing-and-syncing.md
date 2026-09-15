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

Högerklicka på en rad för att titta på filerna bakom den. **Jämför** öppnar de två sidorna intill varandra, medan **Visa vänster fil** och **Visa höger fil** öppnar en sida för sig i visaren — det är svaret för en rad som bara finns på en sida, där det inte finns något att jämföra. Poster som inte går att använda på raden du klickade på är gråmarkerade i stället för att inte göra något. En fil inuti en `.zip` eller på en server packas upp eller hämtas först till en skrivskyddad tillfällig kopia, så originalet berörs aldrig. Detsamma gäller **Jämför**, så en mapp kan jämföras med ett arkiv eller en server — och knapparna för att slå samman och spara förblir avstängda för en sådan sida, eftersom det som är öppet där är kopian.

## Jämför två filer efter innehåll

1. Markera en fil i varje panel (eller två filer i samma panel).
2. Välj **Arkiv ▸ Jämför efter innehåll…**.
3. De två filerna öppnas sida vid sida med sina skillnader markerade. Använd kontrollerna för nästa/föregående för att hoppa mellan ändrade block.
4. Om du slår på redigeringsläge kan du justera endera filen direkt och spara dina ändringar.

![Jämförelsefönstret som visar två textfiler sida vid sida med avvikande rader markerade](screenshots/diff-window.png)
*(Figur: Jämförelse av två textfiler; ändrade rader är markerade på båda sidorna.)*

När de två filerna inte har några skillnader alls säger fönstret det i ett färgat fält längst upp, i stället för att låta dig sluta dig till det från en tabell där ingenting är markerat. Fältet visas också, i en varningsfärg, när en fil inte kunde läsas alls — då skulle varje utlåtande om skillnader vara ett påstående om en jämförelse som aldrig ägde rum. Jämförelsen byte för byte säger detsamma av samma skäl: två filer som den inte kan öppna är inte två identiska filer.

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
- Inget tas bort på grund av en frånvaro som jämförelsen inte kunde bekräfta — en oläsbar mapp,
  eller en som filtret höll tillbaka, bevisar ingenting om vad som finns i den.
- Bara två mappar på den här Mac-datorn. Inte en server och inte ett arkiv: en radering i ett arkiv
  skriver om det, en radering på en server är permanent, och det här läget är inte det att pröva
  det med.

**Det finns ingen ångra för en borttagning.** På den här datorn hamnar filen i Papperskorgen och kan
hämtas tillbaka i Finder; det är hela skyddsnätet. **Minne…** i fönstret listar varje par appen minns, markerar det du tittar på och låter dig glömma vilket som helst av dem — därefter beter sig nästa jämförelse av de mapparna som en första igen. Ingenting glöms av sig själv: en mapp på en avmonterad disk är inte borta, bara inte ansluten.

Uppgiften ligger med inställningarna: flyttar du en
av mapparna har paret ingen historia längre — och en körning utan historia tar inte bort något.

## Vad en körning gjorde, och vad av det som kan tas tillbaka

Varje synkronisering skrivs ned. **Körningar…** i fönstret listar dem med de senaste först — när, vilka två mappar, vilket läge, och hur många filer som kopierades, raderades eller hölls tillbaka — och visar vad som hände med varje fil i den körning du väljer.

Den listan är det som gör papperskorgen användbar. En fil som den här Mac-datorn raderade hamnade i papperskorgen, och körningen antecknade *var*, vilket betyder mer än det låter: papperskorgen döper om vid krock, så en andra `notes.txt` hamnar som `notes.txt 11-17-15-028.txt`, och att leta efter den på namn ger fel fil. **Visa i papperskorgen** pekar Finder rakt på objektet.

**Lägg tillbaka…** flyttar de filer en körning raderade ut ur papperskorgen till de sökvägar de raderades från. Varje enskild kontrolleras först, och det som inte håller avvisas med sitt skäl i stället för att tvingas igenom:

- Det ligger något på den sökvägen igen. Det lämnas i fred — ett tillbakaläggande får aldrig skriva över.
- Objektet finns inte i papperskorgen längre, eller det raderades permanent i stället för att läggas dit.
- Sidan var ett arkiv eller en server. Ett arkiv skrivs om i sin helhet, och en server har ingen
  papperskorg, så ingenting sparades.
- Mappen körningen skrev till är borta, eller är inte samma mapp längre — en återanvänd
  monteringspunkt, säg. Då avvisas hela körningen i stället för att någon del av den utförs.
- Det har redan lagts tillbaka. Noteringen minns det, så ett andra försök gör ingenting.
- Eller noteringen själv är en som den här versionen inte kan agera på — skriven av en nyare version
  av appen, eller så namnger den en sökväg utanför båda mapparna. Ovanligt, och avvisat i stället för
  gissat.

**En kopia kan inte tas tillbaka.** Att ta bort en skulle innebära att radera en fil du kan ha redigerat sedan dess, vilket är den omvända bytesaffären mot att lägga tillbaka en radering, så appen erbjuder det inte — körningen talar om vilka filer den kopierade och du kan radera dem själv. En fil som *skrevs över* är den enda riktiga luckan, och den är numera liten: på den här Mac-datorn hamnar den ersatta versionen i papperskorgen som en raderad fil, så **Visa i papperskorgen** hittar den. In i ett arkiv, upp på en server eller till en volym utan papperskorg går det inte, och bekräftelsen säger det före körningen.

De senaste 200 körningarna behålls, eller 64 MB av dem, vilket som kommer först; därutöver faller de äldsta bort en i taget allteftersom nya kommer till, och **Glöm** och **Glöm alla** rensar dem på stället. En mycket stor körning — mer än 20 000 filer — behåller varje problem och allt den lade i papperskorgen, men inte de kopior som gick igenom, och säger det i stället för att låta dig upptäcka det. Dess raderingar går fortfarande att lägga tillbaka: det som utelämnades är kopiorna, och en kopia hade ändå inte kunnat tas tillbaka.

Att glömma ändrar ingenting i mapparna; det som försvinner är noteringen om vad som gjordes, och med den erbjudandet att lägga tillbaka något. Till skillnad från tvåvägsminnet slängs detta automatiskt — att förlora minnet av ett *par* skulle ändra vad nästa körning gör, medan att förlora noteringen om en körning bara tar bort ett erbjudande.

## Kortkommandon

| Åtgärd | Kortkommando |
| --- | --- |
| Jämför kataloglistor (markera avvikande filer) | Shift+F2 |
| Jämför efter innehåll | Arkiv ▸ Jämför efter innehåll… |
| Synkronisera kataloger | Kommandon ▸ Synkronisera kataloger… |
| Visa den ena sidan av en synkroniseringsrad | Högerklicka på raden ▸ Visa vänster fil / Visa höger fil |

## Anteckningar

- **Efter innehåll kontra efter datum/storlek.** En snabb jämförelse matchar filer efter storlek och ändringsdatum, vilket är snabbt men kan luras när tidsstämplar skiljer sig för identiska filer. Slå på **efter innehåll** för ett tillförlitligt resultat på bekostnad av att varje fil läses.
- **Undermappar och filter.** Synkroniseringsfönstret kan gå ned i undermappar och kan begränsas med en filtermask, så att du kan synkronisera bara de filtyper du bryr dig om.
- **Du behåller kontrollen.** Synkronisering körs aldrig av sig själv – du granskar de föreslagna riktningarna i resultatrutnätet och kan ändra vilken som helst av dem innan något kopieras. **Esc** avbryter en pågående jämförelse och stänger fönstret när ingen pågår.
- **Förinställningar.** Ofta använda synkroniseringsuppsättningar kan sparas och återanvändas så att du slipper ange samma alternativ varje gång. En förinställning minns även vad resultatrutnätet visar — riktningsfiltret och **Dölj identiska** — och fönstret öppnas med den förinställning du använde senast. En förinställning **Standard** finns från första gången du öppnar fönstret; spara över den för att göra den till din egen.

