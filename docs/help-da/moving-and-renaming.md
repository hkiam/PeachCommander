---
title: Flytning og omdøbning
slug: moving-and-renaming
section: Filer og mapper
order: 26
related: [copying-files, multi-rename]
---

Flytning omplacerer filer og mapper i stedet for at duplikere dem, og omdøbning ændrer deres navne uden at røre deres indhold. Fordi Peach Commander viser to paneler side om side, er flytning bare et spørgsmål om at vælge det, du vil have, i ét panel og sende det til mappen, der er åben i det andet. Du kan også omdøbe et emne på stedet eller give flyttede emner nye navne undervejs ved hjælp af en jokertegnmaske.

## Flyt filer til det andet panel

1. I kildepanelet skal du åbne mappen med de emner, du vil flytte, og åbne målmappen i det andet panel.
2. Vælg filen eller mappen, der skal flyttes. For at flytte flere på én gang, vælg dem alle først (se *Markering af filer*).
3. Tryk på F6, eller vælg **Filer > Flyt**.
4. Kontrollér målmappen, der vises i dialogen, og klik på **OK** (eller tryk på Retur) for at starte flytningen.

![Flyt-dialogen der viser stifeltet, indstillinger og et køafkrydsningsfelt](screenshots/copy-dialog.png)
*(Figur: flyt-dialogen bruger samme målfelt som kopiering — indtast en sti, eller tilføj en jokertegnmaske for at omdøbe, mens du flytter.)*

Flytninger på samme drev sker næsten øjeblikkeligt. Når målet er på et andet drev, kopierer Peach Commander emnerne og fjerner først originalerne, efter hver fil er ankommet sikkert.

## Omdøb på stedet

1. Vælg en enkelt fil eller mappe.
2. Tryk på Shift+F6, eller vælg **Filer > Omdøb**.
3. Rediger navnet direkte i panelet, og tryk derefter på Retur for at bekræfte eller Esc for at annullere.

## Omdøb mens du flytter

Målfeltet i flyt-dialogen accepterer en jokertegnmaske, så du kan omdøbe emner, mens de flyttes:

1. Vælg emnerne og tryk på F6.
2. I målfeltet skal du tilføje en navnemaske efter målmappen, for eksempel `/Users/dig/Archive/*_backup.*`.
3. `*` står for det oprindelige navn og `.*` for den oprindelige filtype. Bekræft for at flytte og omdøbe i ét trin.

## Genveje

| Handling | Genvej |
| --- | --- |
| Flyt til det andet panel | F6 |
| Omdøb på stedet | Shift+F6 |

## Tips

- Flyt-dialogen tilbyder samme indstillingsknap og baggrundskø-afkrydsningsfelt som kopiering, så du kan sætte store flytninger i kø og lade dem køre i baggrunden.
- Flytning inden for samme drev er en hurtig handling på stedet, så den er sikker for meget store mapper. En flytning på tværs af drev tager længere tid, fordi dataene kopieres først, og derefter slettes kilden.
- For at omdøbe mange filer på én gang med nummerering, søg-og-erstat eller mønstre, brug i stedet værktøjet til flerdobbelt omdøbning (se *Flerdobbelt omdøbning*).
