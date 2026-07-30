---
title: Ta bort filer
slug: deleting-files
section: Filer och mappar
order: 28
related: [copying-files]
---

När du inte längre behöver filer eller mappar kan Peach Commander flytta dem till papperskorgen så att du kan återställa dem senare, eller ta bort dem permanent för att återvinna utrymme direkt. Borttagningar agerar på det aktuella urvalet i den aktiva panelen; om inget är markerat tas objektet under markören bort.

## Så tar du bort filer

1. Markera i den aktiva panelen filerna och mapparna du vill ta bort. Om du inte markerar något används objektet under markören.
2. Tryck på **F8** (eller **Delete**-tangenten) för att flytta urvalet till papperskorgen. För att välja det från menyn, använd **Arkiv > Ta bort**.
3. Om en bekräftelse visas, granska listan över objekt och klicka på **Ta bort** för att fortsätta, eller **Avbryt** för att stoppa.

Objekt som skickas till papperskorgen ligger kvar där tills du tömmer den, så du kan återställa dem från Finder om du ändrar dig.

## Så tar du bort permanent

1. Markera filerna och mapparna som ska tas bort.
2. Tryck på **Shift+F8**, eller välj **Arkiv > Ta bort permanent**.
3. Bekräfta borttagningen. Detta går förbi papperskorgen, så objekten är borta omedelbart och kan inte återställas.

Om vissa objekt inte kan tas bort – till exempel för att de är låsta eller för att du saknar behörighet – berättar Peach Commander vilka som misslyckades och låter dig försöka igen eller hoppa över dem och fortsätta med resten.

## Kortkommandon

| Åtgärd | Kortkommando |
| --- | --- |
| Ta bort till papperskorgen | F8 eller Delete |
| Ta bort permanent | Shift+F8 |

## Anteckningar

- **Bekräftelse.** Som standard ber Peach Commander dig att bekräfta innan borttagning. Du kan stänga av detta i **Konfiguration > Bekräftelse** genom att avmarkera **Bekräfta före borttagning**. Även då bör du behandla permanenta borttagningar med försiktighet, eftersom de inte kan ångras.
- **Standardbeteende för F8.** Normalt flyttar F8 objekt till papperskorgen. Om du föredrar att F8 tar bort permanent som standard, ändra borttagningsalternativet i inställningarna **Konfiguration > Operation**. Shift+F8 tar alltid bort permanent oavsett denna inställning.
- **Ta bort inuti arkiv.** När du bläddrar inuti ett arkiv som stöds tar borttagning bort de markerade posterna från arkivet. Skrivskyddade platser, som vissa nätverks- eller insticksmappar, kan inte ändras på detta sätt.
- **Mappar.** Att ta bort en mapp tar bort allt inuti den. Se till att du har markerat rätt objekt innan du bekräftar, särskilt vid en permanent borttagning.
