---
title: Arbeta med arkiv
slug: archives
section: Arkiv
order: 80
related: [copying-files]
---

Peach Commander behandlar arkiv som mappar. Du kan gå in i ett ZIP-, TAR- eller annat arkiv som stöds, bläddra bland innehållet och kopiera ut filer – allt utan att först packa upp till disk. När du vill skapa ett arkiv buntar Packa-kommandot ihop ditt urval till ett ZIP-, 7z-, TAR- eller annat format, med valfri kryptering och delade volymer. Det här är praktiskt för att bunta ihop filer att skicka, krympa en mapp för lagring, eller kika inuti en nedladdning innan du bestämmer dig för att packa upp den.

## Bläddra i ett arkiv som en mapp

1. Flytta markören till en arkivfil i en panel (till exempel en `.zip` eller `.tar.gz`).
2. Tryck på Enter eller Ctrl+PageDown för att gå in, precis som när du öppnar en mapp.
3. Navigera bland innehållet som vanligt. Tryck på Backspace eller Ctrl+PageUp för att gå upp igen och lämna arkivet.
4. För att dra ut filer, markera dem och kopiera (F5) till den andra panelen.

![Bläddring inuti ett arkiv som om det vore en mapp](screenshots/archive-browse.png)
*(Figur: Ett öppnat arkiv visas som en vanlig mapplista, med sina filer redo att kopieras ut.)*

ZIP, TAR och gzip-komprimerad TAR läses direkt. Andra format som CPIO, ISO, CAB, LZH, XAR och PAX läses via inbyggda systemverktyg. Krypterade ZIP-arkiv (både klassiska och AES) kan öppnas när du anger lösenordet.

## Packa filer till ett nytt arkiv

1. Markera filerna och mapparna du vill inkludera i den aktiva panelen.
2. Välj Arkiv ▸ Packa… eller tryck på Alt+F5. (För att packa och sedan ta bort originalen, använd Alt+Shift+F5.)
3. Välj arkivformat (ZIP, 7z, TAR, tar.gz, bzip2, xz eller RAR), komprimeringsnivå och var det ska sparas i dialogen.
4. Slå eventuellt på AES-256-kryptering och ange ett lösenord, eller dela upp arkivet i volymer med fast storlek.
5. Bekräfta för att skapa arkivet.

![Packa-dialogen med alternativ för format, komprimering, kryptering och delning](screenshots/pack-dialog.png)
*(Figur: Packa-dialogen, där du väljer format och ställer in alternativ för kryptering och delade volymer.)*

## Packa upp eller testa ett arkiv

1. Lägg arkivet du vill packa upp i den aktiva panelen och målmappen i den andra panelen.
2. Välj Arkiv ▸ Packa upp… eller tryck på Alt+F9, och bekräfta sedan målet.
3. För att kontrollera ett arkiv för skador utan att packa upp det, välj Arkiv ▸ Testa arkiv.

## Redigera en ZIP på plats

Du kan lägga till eller ta bort filer inuti en befintlig ZIP utan att packa upp den. Öppna ZIP-filen som en mapp, och kopiera sedan in filer eller ta bort filer som vanligt – ändringen skrivs direkt tillbaka till arkivet.

## Kortkommandon

| Åtgärd | Kortkommando |
| --- | --- |
| Gå in i arkivet under markören | Enter eller Ctrl+PageDown |
| Lämna arkivet (gå upp) | Backspace eller Ctrl+PageUp |
| Packa | Alt+F5 |
| Packa och ta bort originalen | Alt+Shift+F5 |
| Packa upp | Alt+F9 |

## Anteckningar

- Packning till 7z, xz, bzip2 och RAR förlitar sig på externa verktyg. RAR i synnerhet kräver att det proprietära RAR-programmet är installerat; utan det är formatet inte tillgängligt.
- Att redigera en ZIP på plats skriver om hela arkivet, så filändringstidsstämplar inuti det bevaras inte.
- Mycket stora enskilda medlemmar begränsas till 512 MiB vid uppackning. Uppackning kan avbrytas medan den körs.
- Extremt stora (ZIP64) arkiv stöds inte.
