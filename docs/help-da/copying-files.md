---
title: Kopiering af filer
slug: copying-files
section: Filer og mapper
order: 24
related: [moving-and-renaming, background-transfers]
---

Peach Commander er bygget op omkring to paneler side om side: det ene indeholder de filer, du arbejder med, det andet er destinationen. Kopiering tager det, der er markeret i det aktive panel, og lægger en kopi i den mappe, der vises i det andet panel, mens originalerne bliver liggende. Dette er den hurtigste måde at duplikere filer og mapper mellem to placeringer på uden at trække.

## Kopiér en markering til det andet panel

1. Åbn i det ene panel den mappe, der indeholder de emner, du vil kopiere.
2. Åbn i det andet panel den mappe, hvor kopierne skal placeres.
3. Markér de filer og mapper, der skal kopieres. Hvis intet er markeret, bruges emnet under markøren.
4. Tryk på F5. Kopieringsdialogen åbner og viser destinationsstien allerede udfyldt.

![Kopieringsdialogen med destinationsstien og indstillinger](screenshots/copy-dialog.png)
*(Figur: Kopieringsdialogen. Målstien peger mod det andet panel; brug indstillingerne til at finjustere kopieringen.)*

5. Justér destinationen om nødvendigt, og bekræft derefter for at starte kopieringen.

## Kopieringsindstillinger

Inden du bekræfter, kan du ændre, hvordan kopieringen opfører sig:

- **Kun nyere filer** — springer ethvert emne over, hvis kopi allerede findes og er lige så gammel eller nyere, så kun ændrede filer opdateres.
- **Kør i baggrunden** — overdrager kopieringen til baggrundsoverførsels-håndteringen i stedet for at vise fremdriftsvinduet.
- **Sæt i kø til senere** — føjer kopieringen til baggrundskøen uden at starte den endnu.
- **Omdøbningsmaske** — indtast et jokertegnmønster i målfeltet (for eksempel `*.bak`) for at omdøbe emner, mens de kopieres.

To indstillinger gælder for alle kopieringer og findes under **Konfiguration ▸ Indstillinger… ▸ Kopier/slet**: bevarelse af datoer, tilladelser og andre attributter (slået til som standard) og en hastighedsgrænse, der forhindrer en stor kopiering i at overbelaste din disk eller netværksforbindelse. Om job i køen, se Baggrundsoverførsler.

## Fremdrift

Et fremdriftsvindue viser to bjælker — filen, der kopieres, og hele jobbet — med antal filer og bytes, overførselshastigheden og den resterende tid. Du kan når som helst sætte på pause og genoptage. Hastighedsmenuen ved siden af knapperne begrænser denne kopiering med det samme (1, 5 eller 20 MB/s eller fuld hastighed) uden at ændre grænsen i Konfiguration; **Standard** går tilbage til den grænse. **Baggrund** overdrager den igangværende kopiering til baggrundsoverførsels-håndteringen: vinduet lukkes, og kopieringen fortsætter der.

![Overførselsfremdriftsdialogen med en bjælke for den aktuelle fil og en for hele jobbet, fil- og byte-tællere, en hastighedsmenu samt knapperne Baggrund, Pause og Annullér](screenshots/progress-dialog.png)
*(Figur: Fremdriftsdialogen, der vises under en kopiering eller flytning.)*

## Håndtering af filer, der allerede findes

Hvis en kopiering ville erstatte en eksisterende fil, stopper Peach Commander og spørger, hvad der skal ske. En forhåndsvisning af begge filer hjælper dig med at beslutte.

![Overskrivningskonflikt-dialogen, der sammenligner to filer](screenshots/overwrite-dialog.png)
*(Figur: Overskrivningsdialogen sammenligner den eksisterende fil med den, der kopieres.)*

Dine valg omfatter:

- **Overskriv** den eksisterende fil, eller **Overskriv alle** for at anvende dette på hver resterende konflikt.
- **Spring over** denne fil, eller **Spring alle over** for de resterende konflikter.
- **Omdøb** den indkommende kopi automatisk, så begge filer beholdes.
- **Tilføj** de indkommende data til slutningen af den eksisterende fil.
- Overskriv kun, når kilden er **nyere** eller **større** end den eksisterende fil.

## Genveje

| Handling | Tast |
|---|---|
| Kopiér markering til det andet panel | F5 |
| Kopiér i samme mappe (lav en omdøbt kopi) | Shift+F5 |
| Åbn baggrundsoverførsels-håndteringen | Cmd+Shift+B |

## Bemærkninger

- Kopiering mellem to placeringer på samme disk bruger en hurtig klon, når disken understøtter det, så store filer kopieres næsten øjeblikkeligt og bruger kun lidt ekstra plads.
- Mapper kopieres med alt, hvad de indeholder.
- For at flytte filer i stedet for at kopiere dem, brug F6. For at holde øje med eller håndtere job i køen, åbn baggrundsoverførsels-håndteringen med Cmd+Shift+B.
