---
title: Filverktyg
slug: file-utilities
section: Kraftverktyg
order: 94
related: [comparing-and-syncing]
---

Utöver kopiering och flytt innehåller Peach Commander en uppsättning vardagliga filverktyg för att verifiera att filer är intakta, återvinna diskutrymme, bryta upp stora filer i mindre delar, och konvertera filer till och från textsäkra format. Du når dem alla från menyn **Arkiv**, och de agerar på det du har markerat i den aktiva panelen (eller objektet under markören när inget är markerat). Det här ämnet täcker kontrollsummor, dubblettsökaren, dela/kombinera, koda/avkoda, och beräkning av upptaget utrymme.

## Skapa eller verifiera kontrollsummor

Kontrollsummor låter dig bekräfta att en fil laddades ner eller kopierades utan skada, eller ge en mottagare ett sätt att kontrollera kopian de fick.

1. Markera filerna du vill ta fingeravtryck av.
2. Välj **Arkiv ▸ Skapa kontrollsummor…**, välj en algoritm (CRC32, MD5, SHA-1, SHA-256 eller SHA-512), och spara kontrollsummefilen.
3. För att kontrollera filer senare, markera kontrollsummefilen och välj **Arkiv ▸ Verifiera kontrollsummor…**. Peach Commander räknar om varje hash och rapporterar varje fil som inte matchar.

Kontrollsummor strömmar direkt över den aktuella platsen, så du kan skapa eller verifiera dem även för filer inuti arkiv eller på en FTP-server.

## Hitta dubblettfiler

Dubblettsökaren lokaliserar identiska filer utspridda över mappar så att du kan ta bort de extra kopiorna.

1. Markera mapparna (eller filerna) du vill skanna.
2. Välj **Arkiv ▸ Hitta dubbletter…**. Peach Commander jämför kandidater och grupperar filer som är byte-för-byte identiska.
3. Granska varje grupp, markera kopiorna du inte längre behöver, och ta bort dem.

![Dubblettsökaren som listar grupper av identiska filer](screenshots/duplicate-finder.png)
*(Figur: Dubblettsökaren grupperar identiska filer så att du kan behålla en och ta bort resten.)*

## Dela och kombinera filer

Delning bryter upp en stor fil i en numrerad serie mindre delar – praktiskt för lagrings- eller överföringsgränser. Kombinering sätter ihop dem igen.

1. För att dela, markera en fil och välj **Arkiv ▸ Dela fil…**, och ställ sedan in delstorleken. Delarna skrivs till den andra panelens mapp.
2. För att sätta ihop igen, markera den första delen och välj **Arkiv ▸ Kombinera filer…**. Originalfilen byggs om från de numrerade bitarna.

## Koda och avkoda

Kodning förvandlar en binärfil till vanlig text så att den överlever kanaler som bara bär text (till exempel äldre e-post eller inklistringsrutor). Avkodning vänder på det.

1. Markera en fil och välj **Arkiv ▸ Koda…**, och välj sedan ett format – MIME (Base64), UUE (uuencode) eller XXE.
2. För att återställa originalet, markera den kodade filen och välj **Arkiv ▸ Avkoda…**. Formatet upptäcks automatiskt.

## Beräkna upptaget utrymme

För att se hur mycket plats en mapp eller ett urval faktiskt använder på disk, markera objekten och tryck på **Ctrl+L** (**Arkiv ▸ Beräkna upptaget utrymme…**). Peach Commander summerar varje fil inuti, inklusive undermappar, och visar totalsumman.

## Kortkommandon

| Åtgärd | Tangent |
| --- | --- |
| Beräkna upptaget utrymme | Ctrl+L |

## Anteckningar

- Kontrollsummor, dela/kombinera och koda/avkoda är inriktade på mer avancerade uppgifter, men var och en är en enda dialog med förnuftiga standardvärden.
- När ett verktyg producerar nya filer (deldelar, en kodad fil, en kontrollsummelista) skrivs de till mappen som visas i den andra panelen – ställ in den panelen till ditt avsedda mål först.
- Att ta bort dubbletter är permanent beroende på dina borttagningsinställningar; granska varje grupp noga och behåll minst en kopia av allt du fortfarande behöver.
