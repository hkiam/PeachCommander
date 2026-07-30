---
title: Felsökning
slug: troubleshooting
section: Hjälp och felsökning
order: 140
related: [privacy-and-security, known-limitations]
---

Det här ämnet täcker de problem folk oftast stöter på: macOS som blockerar åtkomst till vissa mappar, en mapp som verkar fastna på gammalt innehåll, en säker FTP-server som vägrar ansluta, och packning till RAR. Varje avsnitt berättar vad som händer och hur du åtgärdar det.

## macOS ber om behörighet, eller mappar ser tomma ut

Vissa platser — som din `~/Library`-mapp, andra användares mappar och systemområden — skyddas av macOS och förblir dolda tills du beviljar åtkomst. Peach Commander upptäcker när detta händer och erbjuder sig att vägleda dig till rätt inställning.

1. Vid uppmaningen, välj att öppna Systeminställningar, eller öppna det själv.
2. Gå till Integritet och säkerhet och sedan Fullständig diskåtkomst.
3. Slå på reglaget bredvid Peach Commander. Om det inte finns med, använd knappen Lägg till för att lägga till det.
4. Avsluta och öppna Peach Commander igen så att den nya behörigheten träder i kraft.

Peach Commander körs inte i en begränsad sandlåda, så när Fullständig diskåtkomst har beviljats kan det bläddra och hantera filer precis som Finder.

## En mapp visar inte de senaste ändringarna

Paneler uppdaterar sig normalt själva när filer ändras på disken. Om en mapp ändrades av ett annat program, ligger på en nätverksvolym eller helt enkelt ser inaktuell ut, uppdatera den manuellt.

1. Klicka på panelen du vill uppdatera.
2. Tryck på F2 (eller Ctrl+R) för att läsa om den mappen.

Nätverks- och monterade volymer rapporterar inte alltid ändringar till macOS, så där är en manuell uppdatering den pålitliga lösningen.

## En FTPS-server ansluter inte

Om en säker FTP-anslutning misslyckas, kontrollera dessa inställningar i anslutningsuppgifterna:

- Matcha serverns säkerhetsläge: explicit FTPS (AUTH TLS) och implicit FTPS (port 990) är inte utbytbara.
- Om anslutningen hänger sig efter inloggning, växla mellan passivt och aktivt överföringsläge — de flesta servrar bakom en brandvägg behöver passivt.
- Om servern använder ett självsignerat certifikat måste du uttryckligen tillåta det; annars nekas anslutningen.
- Bekräfta värd, port, användarnamn och lösenord, samt om en SOCKS5-proxy krävs i ditt nätverk.

## Packning till RAR gör ingenting

Peach Commander kan skapa ZIP-, 7z-, TAR-, TAR.GZ-, BZ2- och XZ-arkiv på egen hand. RAR är annorlunda: eftersom RAR är ett proprietärt format kräver skapandet av RAR-arkiv ett separat RAR-kommandoradsverktyg installerat på din Mac. Utan det är RAR inte tillgängligt när du packar filer (Option+F5). För att läsa befintliga RAR-arkiv kan du ändå öppna dem som en mapp. Om du inte specifikt behöver RAR, välj ZIP eller 7z i stället — båda stöder stark AES-256-kryptering och delade volymer.

## Kortkommandon

| Åtgärd | Kortkommando |
| --- | --- |
| Uppdatera den aktiva mappen | F2 eller Ctrl+R |
| Anslut till en FTP/FTPS-server | Ctrl+F |
| Montera en nätverksresurs | Cmd+K |
| Packa de markerade filerna | Option+F5 |

## Anmärkningar

- Lösenord och andra inloggningsuppgifter lagras endast i macOS nyckelring, aldrig i klartextkonfigurationsfiler.
- Att montera en nätverksresurs (Cmd+K, eller Nätverk-menyn ▸ Montera nätverksresurs…) använder samma anslutning som macOS självt använder, så den visas även i Finder.
- Om ett problem kvarstår efter en uppdatering och en omstart kan det vara en känd begränsning snarare än ett fel — se Kända begränsningar.
