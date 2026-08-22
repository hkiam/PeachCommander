---
title: Bevæg dig rundt
slug: navigating
section: Kom godt i gang
order: 14
related: [interface-overview, favorites]
---

Peach Commander viser to mapper side om side, så du bruger det meste af din tid på at flytte ét panel fra mappe til mappe. Du kan åbne mapper, gå et niveau op, spore tilbage hvor du har været, indtaste en sti direkte og springe direkte til hverdagssteder som Hjem, Skrivebord og Overførsler. Alle handlinger virker på det *aktive* panel — det med den fremhævede stilinje.

## Åbn mapper og gå op

1. Flyt markeringslinjen med piletasterne, indtil en mappe er fremhævet.
2. Tryk på **Retur** (eller dobbeltklik) for at åbne den. Dette går også ind i arkiver og åbner filer med deres standardapp.
3. For at gå et niveau op til den overordnede mappe, tryk på **Ctrl+PageUp** (eller **Tilbage**).
4. For at springe til toppen af det aktuelle drev, vælg **Gå ▸ Rod**.

## Gå tilbage og frem

Peach Commander husker de mapper, du har besøgt i hvert panel, ligesom en webbrowser.

- Tryk på **Alt+Venstre** for at gå tilbage til den forrige mappe, og **Alt+Højre** for at gå frem igen.
- Tryk på **Alt+Ned** for at åbne en rulleliste med nylige mapper og springe til en af dem.

## Indtast en sti eller brug stilinjen

Stilinjen øverst i hvert panel viser, hvor du er, og fungerer også som en måde at komme hurtigt et sted hen.

![Redigerbar stilinje der viser den aktuelle mappe som klikbare segmenter](screenshots/path-bar-crop.png)
*(Figur: stilinjen. Klik på et segment for at springe til den mappe, eller til højre for stien for at indtaste en fuld sti.)*

- Klik på et segment af stien (for eksempel navnet på en overordnet mappe) for at springe direkte til den.
- Klik hvor som helst i det tomme område til højre for stien — blyanten inklusive — for at gøre linjen til et tekstfelt, indtast eller indsæt derefter en sti og tryk på Retur. Du behøver ikke ramme blyanten.
- Et klik på en stilinje gør også det panel aktivt.
- Eller vælg **Arkiv ▸ Gå til mappe…** (**Cmd+Shift+G**) for at indtaste en sti hvor som helst fra.

## Spring til almindelige steder

Menuen **Gå** fører det aktive panel til de mapper, du bruger mest:

- **Hjem**, **Skrivebord**, **Overførsler**, **Papirkurv** og **iCloud Drive**.
- **iCloud Drive** vises, når det er konfigureret på din Mac.

## Skift paneler og drev

- Tryk på **Tab** for at flytte fokus mellem venstre og højre panel.
- Drevlinjen over hvert panel viser dine monterede diske med ledig plads; klik på en disk for at skifte det panel til den.
- Tryk på **Ctrl+U** for at bytte de to paneler (deres mapper bytter side); **Ctrl+Shift+U** bytter dem sammen med deres faner.
- Tryk på **Ctrl+=** for at rette det andet panel mod samme mappe som det aktive (*mål = kilde*) — praktisk lige før en kopiering eller flytning.
- **Gå ▸ Venstre = højre** og **Gå ▸ Højre = venstre** gør det samme, men nævner siden direkte: den første viser højre panels mappe til venstre, den anden viser venstre panels mappe til højre. I modsætning til *mål = kilde* afhænger de ikke af, hvilket panel der er aktivt, så deres to knapper på knaplinjen betyder altid det samme.

## Genveje

| Handling | Genvej |
| --- | --- |
| Åbn mappe / fil under markøren | Retur |
| Gå til overordnet mappe | Ctrl+PageUp (eller Tilbage) |
| Tilbage / Frem i historik | Alt+Venstre / Alt+Højre |
| Rulleliste med historik | Alt+Ned |
| Gå til mappe… (indtast en sti) | Cmd+Shift+G |
| Hjem | Cmd+Shift+H |
| Skrivebord | Cmd+Shift+D |
| Overførsler | Option+Cmd+L |
| Skift aktivt panel | Tab |
| Global historik (uanset panel) | Ctrl+Cmd+H |

## Tips

- Et panel holder sig selv opdateret: en fil, som et andet program opretter, ændrer eller sletter i den viste mappe, kommer frem af sig selv, og markøren og dine markeringer bliver, hvor de var. Slå det fra under **Konfiguration ▸ Indstillinger ▸ Visning**, hvis en mappe, der skrives til hele tiden, bliver opdateret uafbrudt.
- Hvert panel har sin egen historik, så Tilbage og Frem påvirker kun den aktive side.
- Hvis en indtastet sti ikke er en gyldig mappe, bevarer stilinjen stille din seneste placering i stedet for at navigere.
- Papirkurv og iCloud Drive i Gå-menuen har ingen standardgenvej, men du kan tildele en i **Konfiguration ▸ Indstillinger ▸ Tastatur**.
