---
title: Attribut och behörigheter
slug: attributes-and-permissions
section: Kraftverktyg
order: 96
related: [file-utilities]
---

Peach Commander låter dig granska och ändra den lågnivåmetadata för filer och mappar som Finder mest håller utom räckhåll: POSIX-behörigheter för läsning/skrivning/körning, ägare och grupp, ändrings- och skapelsedatum, macOS-flaggor som dold och låst, samt utökade attribut. Du kan även redigera en fils åtkomstkontrollista (ACL) för finkorniga regler per användare eller per grupp, skapa länkar och alias som pekar mot andra objekt, och bifoga dina egna kommentarer. Dessa verktyg riktar sig till avancerade användare som behöver exakt kontroll över hur objekt beter sig och vem som kan röra dem.

## Ändra attribut

1. Markera ett eller flera objekt i den aktiva panelen.
2. Välj **Arkiv > Ändra attribut…**.
3. Ställ in det du behöver: växla rutorna för läsa/skriva/köra för ägare, grupp och alla (eller skriv in ett oktalt värde direkt), ändra ägare eller grupp, växla flaggorna dold eller låst, och ställ in ändrings- eller skapelsedatum. Använd **Använd aktuellt** för aktuell tid, eller kopiera ett datum från en annan fil.
4. För att tillämpa samma ändring genom en mapps innehåll, slå på det rekursiva alternativet och välj om det ska påverka filer, mappar eller båda.
5. Klicka på OK för att köra ändringen. Rekursiva ändringar körs som en bakgrundsuppgift med en förloppsstapel.

![Dialogen Ändra attribut med behörighetsrutnätet, flaggorna och datumfälten](screenshots/attributes-dialog.png)
*(Figur: Dialogen Ändra attribut. Blandade värden i ett flerfilsurval visas som ett streck tills du ställer in dem.)*

## Redigera en ACL

För regler bortom den grundläggande modellen med ägare/grupp/alla redigerar du objektets åtkomstkontrollista.

1. Öppna **Arkiv > Ändra attribut…** och öppna ACL-redigeraren därifrån.
2. Varje rad är en regel: användaren eller gruppen den gäller för, om den tillåter eller nekar, och vilka behörigheter (läsa, skriva, ta bort och så vidare) den ger.
3. Lägg till, ta bort eller redigera rader, och spara sedan för att skriva tillbaka listan till objektet.

## Skapa länkar, alias och kommentarer

- **Arkiv > Skapa symbolisk länk…** skapar en symbolisk länk (symlink) som pekar mot objektet under markören via sökväg.
- **Arkiv > Skapa hård länk…** skapar en hård länk till samma fildata. Hårda länkar fungerar bara för filer på samma volym.
- **Arkiv > Skapa alias…** skapar ett macOS-alias som Finder också kan följa.
- **Arkiv > Redigera kommentar…** (Ctrl+Z) öppnar en textredigerare för en kommentar per fil. Kommentarer kan visas i en egen kolumn och i statustips.

## Kortkommandon

| Åtgärd | Kortkommando |
| --- | --- |
| Redigera kommentar | Ctrl+Z |

## Anteckningar

- Att ändra ägare eller grupp kräver vanligtvis behörigheter du inte har som vanlig användare; när det händer rapporteras ändringen som misslyckad snarare än tillämpad, och resten av dina ändringar går ändå igenom.
- Kommentarer lagras i en `descript.ion`-fil bredvid dina objekt och kan även behållas som Finder-kommentarer, beroende på dina inställningar. Båda läses när en kommentar visas. Formatet är detsamma som Total Commander och flera andra filhanterare använder, så en kommentar du skriver här går att läsa där.
- Kommentarer med **radbrytningar** och kommentarer i **UTF-16** läses och skrivs som Total Commander gör det: en radbrytning lagras som `\n` följt av de två markörbyte som TC fick registrerade för det, och en fil som var UTF-16 förblir UTF-16 när du ändrar en kommentar i den. Utan den markören är ett `\n` i någons kommentar två tecken som de skrev, och de lämnas i fred.
- **En kommentar följer filen.** Kopiering, flytt och namnbyte tar den med — till målmappens `descript.ion` vid flytt och kopiering, och till det nya namnet vid namnbyte, även när du ångrar namnbytet. Undantaget är att lägga en fil sist i en annan: filen som blir kvar behåller sin egen kommentar, eftersom den fortfarande är den filen.
- Med insticksmodulen Anteckningar påslagen visar och redigerar dess sidofält samma kommentar ovanför anteckningens text, så att det inte finns två ställen för samma sak.
- En symbolisk länk och ett alias pekar båda mot ett mål, men en symbolisk länk lagrar en vanlig sökväg medan ett alias lagrar en macOS-referens som fortsätter fungera om målet flyttas eller byter namn. En hård länk är ett andra namn för samma fildata, inte en pekare.
