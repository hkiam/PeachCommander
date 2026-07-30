---
title: Nya mappar och filer
slug: creating-items
section: Filer och mappar
order: 30
related: [opening-files]
---

När du organiserar filer behöver du ofta någonstans nytt att lägga dem, eller ett nytt dokument att utgå från. Peach Commander låter dig skapa en ny mapp eller en ny textfil direkt i panelen du arbetar i, utan att byta till Finder. Nya objekt skapas i mappen som för närvarande visas i den aktiva panelen.

## Skapa en ny mapp

1. Klicka på panelen där du vill att den nya mappen ska visas så att den blir den aktiva panelen.
2. Tryck på F7.
3. Skriv ett namn i rutan som visas.
4. Tryck på Return (eller klicka på OK). Den nya mappen visas i panelen, redo att användas.

Du kan göra mer än att skapa en enda mapp i ett steg:

- **Nästlade mappar på en gång.** Skriv en sökväg med snedstreck, såsom `a/b/c`, för att skapa en mapp `a` som innehåller `b` som innehåller `c`. Alla nivåer som inte finns ännu skapas åt dig.
- **Flera mappar samtidigt.** Separera namn med ett lodrätt streck, såsom `d1|d2`, för att skapa både `d1` och `d2` sida vid sida. Du kan kombinera båda stilarna, till exempel `reports/2026|archive`.

## Skapa en ny textfil

1. Klicka på panelen där du vill att den nya filen ska visas.
2. Tryck på Shift+F4.
3. Skriv ett namn för filen, inklusive dess filtillägg (till exempel `notes.txt`).
4. Tryck på Return. Den tomma filen skapas och öppnas i din redigerare så att du kan börja skriva direkt.

Filen öppnas i den redigerare som Peach Commander är inställt att använda för den sortens fil. Se **Öppna och visa filer** för hur redigering fungerar.

## Kortkommandon

| Åtgärd | Tangent |
| --- | --- |
| Ny mapp | F7 |
| Ny textfil | Shift+F4 |

## Anteckningar

- På macOS kan ett mapp- eller filnamn innehålla nästan vilket tecken som helst. Endast snedstrecket `/` (som används som sökvägsavgränsare för nästlade mappar) och några få reserverade tecken är inte tillåtna i ett enskilt namn.
- Att använda ett kolon `:` i ett namn är möjligt men kan se förvirrande ut i Finder, så det är bäst att undvika.
- Om en mapp med samma namn redan finns behåller Peach Commander helt enkelt den befintliga – ingenting skrivs över.
