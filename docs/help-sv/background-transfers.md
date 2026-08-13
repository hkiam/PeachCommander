---
title: Bakgrundsöverföringar
slug: background-transfers
section: Filer och mappar
order: 32
related: [copying-files, downloading-from-url]
---

Stora kopieringar, flyttar, borttagningar och nedladdningar behöver inte hålla upp ditt arbete. Peach Commander kan köra dem i bakgrunden och samla dem alla på ett ställe: hanteraren för bakgrundsöverföringar. Därifrån ser du varje jobbs förlopp och överföringshastighet, pausar eller återupptar det, avbryter det, eller ställer upp jobb för att starta senare. Eftersom ett bakgrundsjobb körs för sig självt hindrar det dig aldrig från att bläddra, öppna filer eller starta nästa överföring.

## Så gör du

1. Starta en kopiering, flytt, borttagning eller nedladdning och välj att köra den i bakgrunden. Jobbet visas i hanteraren för bakgrundsöverföringar.
2. Öppna hanteraren när som helst från **Kommandon ▸ Hanterare för bakgrundsöverföringar…** (eller tryck på Cmd+Shift+B).
3. Varje jobb visar en titel, en förloppsstapel och en liverad med klara filer, överförda byte och aktuell hastighet.
4. Använd knapparna per jobb för att **Pausa**, **Återuppta** eller **Avbryta** medan ett jobb körs.
5. Ett pågående jobb har också en hastighetsmeny. Välj en gräns — 1, 5 eller 20 MB/s, eller full hastighet — för att få en överföring ur vägen för en annan utan att bromsa de övriga. Det gäller direkt; **Standard** lämnar tillbaka jobbet till gränsen i Konfiguration.
6. För jobb du lagt till men ännu inte startat (hållna jobb) klickar du på **Starta** vid jobbet, eller på **Starta alla** för hela väntelistan. Med **▲** och **▼** flyttar du ett väntande jobb tidigare eller senare i kön; knapparna visas bara där flytten är möjlig, så ett väntande jobb kör aldrig om överföringen som redan pågår.
7. När allt du bryr dig om har slutförts, klicka på **Rensa slutförda** för att städa upp listan.

![Hanteraren för bakgrundsöverföringar som listar aktiva och väntande jobb med förloppsstaplar och knapparna Pausa, Återuppta och Avbryt.](screenshots/transfer-manager.png)

*Varje överföring är en rad som du kan pausa, återuppta eller avbryta oberoende av de andra.*

## Kortkommandon

| Åtgärd | Kortkommando |
| --- | --- |
| Öppna hanteraren för bakgrundsöverföringar | Cmd+Shift+B |

## Tips

- **Begränsa hastigheten.** För att förhindra att en stor överföring mättar din anslutning eller disk, ställ in en hastighetsgräns i kopieringsdialogen innan du startar jobbet. Hanteraren visar sedan den strypta hastigheten live.
- **Köa för senare.** Vilande jobb ligger i listan utan att köras tills du trycker på Starta (eller Starta alla), så att du kan förbereda flera överföringar och sätta igång dem tillsammans.
- **Kör flera samtidigt.** Jobb körs oberoende av varandra, så du kan pausa ett medan ett annat fortsätter.

## Anteckningar

Eftersom ett bakgrundsjobb körs utan att du tittar på kan det inte stanna för att ställa frågor. Om en fil redan finns på målet skriver bakgrundsjobbet över den; om ett enskilt objekt inte kan överföras hoppas det objektet över och jobbet fortsätter. När jobbet är klart samlas eventuella överhoppade objekt i en fellogg så att du kan granska exakt vad som gick fel.
