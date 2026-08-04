---
title: Bevege seg rundt
slug: navigating
section: Komme i gang
order: 14
related: [interface-overview, favorites]
---

Peach Commander viser to mapper side om side, så det meste av tiden din brukes på å flytte det ene panelet fra mappe til mappe. Du kan åpne mapper, gå tilbake opp i hierarkiet, gå tilbake dit du har vært, skrive inn en sti direkte og hoppe rett til hverdagslige steder som Hjem, Skrivebord og Nedlastinger. Alle handlinger virker på det *aktive* panelet — det med den uthevede stilinjen.

## Åpne mapper og gå tilbake opp

1. Flytt utvalgslinjen med piltastene til en mappe er uthevet.
2. Trykk **Enter** (eller dobbeltklikk) for å åpne den. Dette går også inn i arkiver og åpner filer med standardappen deres.
3. For å gå opp ett nivå til overordnet mappe, trykk **Ctrl+PageUp** (eller **Backspace**).
4. For å hoppe til toppen av gjeldende disk, velg **Gå ▸ Rot**.

## Gå tilbake og fremover

Peach Commander husker mappene du har besøkt i hvert panel, akkurat som en nettleser.

- Trykk **Alt+Venstre** for å gå tilbake til forrige mappe, og **Alt+Høyre** for å gå fremover igjen.
- Trykk **Alt+Ned** for å åpne en nedtrekksliste over nylige mapper og hoppe til hvilken som helst av dem.

## Skriv inn en sti eller bruk stilinjen

Stilinjen øverst i hvert panel viser hvor du er og fungerer også som en måte å komme raskt et sted på.

![Redigerbar stilinje som viser gjeldende mappe som klikkbare segmenter](screenshots/path-bar-crop.png)
*(Figur: Stilinjen. Klikk på et segment for å hoppe til den mappen, eller på blyanten for å skrive inn en full sti.)*

- Klikk på et segment av stien (for eksempel navnet på en overordnet mappe) for å hoppe rett til den.
- Klikk på blyanten til høyre i stilinjen for å gjøre den om til et tekstfelt, og skriv eller lim deretter inn en hvilken som helst sti og trykk Enter.
- Eller velg **Fil ▸ Gå til mappe…** (**Cmd+Shift+G**) for å skrive inn en sti hvor som helst fra.

## Hopp til vanlige steder

**Gå**-menyen tar det aktive panelet til mappene du bruker mest:

- **Hjem**, **Skrivebord**, **Nedlastinger**, **Papirkurv** og **iCloud Drive**.
- **iCloud Drive** vises når det er satt opp på Macen din.

## Bytt paneler og disker

- Trykk **Tab** for å flytte fokus mellom venstre og høyre panel.
- Disklinjen over hvert panel lister opp de monterte volumene dine med ledig plass; klikk på et volum for å bytte panelet til det.
- Trykk **Ctrl+U** for å bytte om de to panelene (mappene deres bytter side); **Ctrl+Shift+U** bytter dem om sammen med fanene deres.
- Trykk **Ctrl+=** for å peke det andre panelet mot samme mappe som det aktive (*mål = kilde*) — praktisk rett før en kopiering eller flytting.

## Snarveier

| Handling | Snarvei |
| --- | --- |
| Åpne mappe / fil under markøren | Enter |
| Gå til overordnet mappe | Ctrl+PageUp (eller Backspace) |
| Tilbake / Fremover i historikken | Alt+Venstre / Alt+Høyre |
| Historikk-nedtrekksliste | Alt+Ned |
| Gå til mappe… (skriv inn en sti) | Cmd+Shift+G |
| Hjem | Cmd+Shift+H |
| Skrivebord | Cmd+Shift+D |
| Nedlastinger | Option+Cmd+L |
| Bytt aktivt panel | Tab |

## Tips

- Et panel holder seg selv oppdatert: en fil som et annet program oppretter, endrer eller sletter i mappen du ser på, kommer fram av seg selv, og markøren og merkingene dine blir stående. Slå det av under **Konfigurasjon ▸ Innstillinger ▸ Visning** hvis en mappe det skrives til hele tiden oppdateres ustanselig.
- Hvert panel beholder sin egen historikk, så Tilbake og Fremover påvirker bare den aktive siden.
- Hvis en innskrevet sti ikke er en gyldig mappe, beholder stilinjen stille din forrige plassering i stedet for å navigere.
- Papirkurv og iCloud Drive i Gå-menyen har ingen standardsnarvei, men du kan tildele én i **Konfigurasjon ▸ Alternativer ▸ Tastatur**.
