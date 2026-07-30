---
title: Sletning af filer
slug: deleting-files
section: Filer og mapper
order: 28
related: [copying-files]
---

Når du ikke længere har brug for filer eller mapper, kan Peach Commander flytte dem til papirkurven, så du kan gendanne dem senere, eller slette dem permanent for at frigøre plads med det samme. Sletninger handler på den aktuelle markering i det aktive panel; hvis intet er markeret, slettes emnet under markøren.

## Sådan sletter du filer

1. Markér i det aktive panel de filer og mapper, du vil fjerne. Hvis du ikke markerer noget, bruges emnet under markøren.
2. Tryk på **F8** (eller **Delete**-tasten) for at flytte markeringen til papirkurven. For at vælge det fra menuen skal du bruge **Fil > Slet**.
3. Hvis der vises en bekræftelse, skal du gennemgå listen over emner og klikke på **Slet** for at fortsætte eller **Annullér** for at stoppe.

Emner sendt til papirkurven bliver der, indtil du tømmer den, så du kan gendanne dem fra Finder, hvis du ombestemmer dig.

## Sådan sletter du permanent

1. Markér de filer og mapper, der skal fjernes.
2. Tryk på **Shift+F8**, eller vælg **Fil > Slet permanent**.
3. Bekræft sletningen. Dette omgår papirkurven, så emnerne er væk med det samme og kan ikke gendannes.

Hvis nogle emner ikke kan fjernes — for eksempel fordi de er låst, eller du ikke har tilladelse — fortæller Peach Commander dig, hvilke der mislykkedes, og lader dig prøve igen eller springe dem over og fortsætte med resten.

## Genveje

| Handling | Genvej |
| --- | --- |
| Slet til papirkurv | F8 eller Delete |
| Slet permanent | Shift+F8 |

## Bemærkninger

- **Bekræftelse.** Som standard beder Peach Commander dig om at bekræfte, før den sletter. Du kan slå dette fra i **Konfiguration > Bekræftelse** ved at fjerne **Bekræft før sletning**. Behandl alligevel permanente sletninger med omhu, da de ikke kan fortrydes.
- **Standardadfærd for F8.** Normalt flytter F8 emner til papirkurven. Hvis du foretrækker, at F8 sletter permanent som standard, skal du ændre sletteindstillingen i indstillingerne under **Konfiguration > Handling**. Shift+F8 sletter altid permanent uanset denne indstilling.
- **Sletning inde i arkiver.** Når du gennemser inde i et understøttet arkiv, fjerner sletning de markerede poster fra arkivet. Skrivebeskyttede placeringer, såsom nogle netværks- eller plugin-mapper, kan ikke ændres på denne måde.
- **Mapper.** Sletning af en mappe fjerner alt, hvad den indeholder. Sørg for, at du har markeret de rigtige emner, før du bekræfter, især ved en permanent sletning.
