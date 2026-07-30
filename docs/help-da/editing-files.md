---
title: Redigering af filer
slug: editing-files
section: Visning og redigering
order: 72
related: [viewing-files]
---

Når du har brug for at ændre en fil frem for blot at se på den, åbner Peach Commander den i en indbygget editor. Tekst- og kodefiler åbner i en fuld editor med syntaksfremhævning, søg og erstat, et overblik over symbolerne i din kode og et minikort til hurtig navigation. Binære filer kan åbnes i en separat hex-editor, hvor du kan inspicere og ændre individuelle bytes. Du behøver aldrig at forlade appen for at foretage en hurtig redigering.

## Redigér en tekst- eller kodefil

1. Flyt markøren i et af panelerne til den fil, du vil ændre.
2. Tryk på F4, eller vælg Fil ▸ Redigér. Filen åbner i editorvinduet.
3. Foretag dine ændringer. Hvis filen er et genkendt programmerings- eller dataformat, farves nøgleord, strenge og kommentarer automatisk.
4. Tryk på Cmd+S (eller klik på Gem) for at skrive dine ændringer. Den første lagring beholder en backup af originalen ved siden af filen, så du altid kan falde tilbage til den.

For at starte en helt ny tekstfil på den aktuelle placering skal du trykke på Shift+F4.

![Den indbyggede teksteditor med syntaksfremhævning, symboloverblikket og minikortet](screenshots/editor.png)
*(Figur: Editoren med syntaksfremhævning, symboloverblikket til venstre og minikortet til højre.)*

## Søg, erstat og naviger

- Tryk på Cmd+F for at åbne søgebjælken. For at erstatte tekst skal du åbne søgebjælken og skifte den til erstat-visningen eller klikke på Søg/Erstat i værktøjslinjen.
- Klik på Formatér JSON/XML for at genindrykke et JSON- eller XML-dokument til et rent, læsbart layout.
- Klik på Symboler (eller tryk på Cmd+Shift+O) for at vise en sidebjælke, der viser klasserne, funktionerne og metoderne i din kode. Klik på en post for at springe direkte til den.
- Tryk på Cmd+L for at springe til en bestemt linje.
- Tryk på Cmd+\ for at springe mellem en parentes og dens matchende makker.
- Klik på kortknappen for at vise eller skjule minikortet, et skaleret overblik over hele filen, som du kan klikke på for at rulle.
- Brug menuen Kodning i værktøjslinjen, hvis filen blev gemt i noget andet end standardtekstkodningen.

## Redigér en fil byte for byte

1. Markér filen i et panel.
2. Vælg Fil ▸ Redigér som hex (eller højreklik på filen og vælg Redigér som hex).
3. Skriv hexcifre for at overskrive bytes, eller brug piletasterne til at bevæge dig gennem filen. Backspace og Delete fjerner bytes.
4. Tryk på Cmd+S for at gemme. Som med teksteditoren beholdes en engangsbackup af originalen.

## Genveje

| Handling | Tast |
|---|---|
| Redigér fil | F4 |
| Opret og redigér en ny tekstfil | Shift+F4 |
| Gem | Cmd+S |
| Søg | Cmd+F |
| Vis/skjul symboloverblik | Cmd+Shift+O |
| Gå til linje | Cmd+L |
| Spring til matchende parentes | Cmd+\ |
| Fortryd / gentag (hex-editor) | Cmd+Z / Cmd+Shift+Z |

## Bemærkninger

- Syntaksfremhævning dækker JSON, C, C#, Java, JavaScript, TypeScript, Python og Rust. Andre filtyper åbner og redigeres stadig normalt med grundlæggende farvning, men detaljeret fremhævning og symboloverblikket er kun tilgængelige for de understøttede sprog.
- Symboloverblikket og funktionerne Gå til linje gælder for teksteditoren. Hex-editoren er beregnet til binær inspektion og redigering på byteniveau, ikke til tekst.
- Begge editorer beholder en backup af den oprindelige fil, første gang du gemmer, så en utilsigtet ændring er let at fortryde ved at gendanne den backup.
