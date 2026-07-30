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
- **Bevar metadata** — beholder datoer, tilladelser og andre filattributter på kopierne. Dette er slået til som standard.
- **Hastighedsgrænse** — begrænser overførselshastigheden, så en stor kopiering ikke overbelaster din disk eller netværksforbindelse.
- **Omdøbningsmaske** — indtast et jokertegnmønster i målfeltet (for eksempel `*.bak`) for at omdøbe emner, mens de kopieres.

Du kan også sende jobbet til baggrundskøen i stedet for at holde øje med det — se Baggrundsoverførsler.

## Fremdrift

Et fremdriftsvindue viser den aktuelle fil og det samlede job med separate bjælker samt overførselshastigheden. Du kan når som helst sætte på pause og genoptage eller sende den igangværende kopiering til baggrundsoverførsels-håndteringen for at arbejde videre, mens den fuldføres.

![Overførselsfremdriftsdialogen med en fremdriftsbjælke, fil- og byte-tællere samt knapperne Pause og Annullér](screenshots/progress-dialog.png)
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
