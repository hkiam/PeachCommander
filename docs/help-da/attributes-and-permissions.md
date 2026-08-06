---
title: Attributter og tilladelser
slug: attributes-and-permissions
section: Avancerede værktøjer
order: 96
related: [file-utilities]
---

Peach Commander lader dig inspicere og ændre de lavniveaumetadata for filer og mapper, som Finder for det meste holder uden for rækkevidde: POSIX-tilladelser til læsning/skrivning/kørsel, ejeren og gruppen, ændrings- og oprettelsesdatoerne, macOS-flag såsom skjult og låst samt udvidede attributter. Du kan også redigere en fils adgangskontrolliste (ACL) for finkornede regler pr. bruger eller pr. gruppe, oprette links og aliasser, der peger på andre emner, og vedhæfte dine egne kommentarer. Disse værktøjer er rettet mod avancerede brugere, der har brug for præcis kontrol over, hvordan emner opfører sig, og hvem der kan røre dem.

## Ændr attributter

1. Markér et eller flere emner i det aktive panel.
2. Vælg **Fil > Skift attributter…**.
3. Indstil det, du har brug for: slå felterne for læsning/skrivning/kørsel til og fra for ejer, gruppe og alle (eller indtast en oktalværdi direkte), skift ejer eller gruppe, vend de skjulte eller låste flag og indstil ændrings- eller oprettelsesdatoen. Brug **Brug aktuel** for det nuværende tidspunkt, eller kopiér en dato fra en anden fil.
4. For at anvende den samme ændring gennem en mappes indhold skal du slå den rekursive indstilling til og vælge, om den påvirker filer, mapper eller begge.
5. Klik på OK for at køre ændringen. Rekursive ændringer kører som en baggrundsopgave med en fremdriftsbjælke.

![Dialogen Skift attributter med tilladelsesgitteret, flagene og datofelterne](screenshots/attributes-dialog.png)
*(Figur: Dialogen Skift attributter. Blandede værdier på tværs af en markering med flere filer vises som en bindestreg, indtil du indstiller dem.)*

## Redigér en ACL

For regler ud over den grundlæggende model med ejer/gruppe/alle skal du redigere emnets adgangskontrolliste.

1. Åbn **Fil > Skift attributter…** og åbn ACL-redigeringen derfra.
2. Hver række er én regel: den bruger eller gruppe, den gælder for, om den tillader eller nægter, og hvilke tilladelser (læsning, skrivning, sletning og så videre) den giver.
3. Tilføj, fjern eller redigér rækker, og gem derefter for at skrive listen tilbage til emnet.

## Opret links, aliasser og kommentarer

- **Fil > Opret symbolsk link…** laver et symbolsk link (symlink), der peger på emnet under markøren via sti.
- **Fil > Opret hårdt link…** laver et hårdt link til de samme fildata. Hårde links virker kun for filer på samme diskenhed.
- **Fil > Opret alias…** laver et macOS-alias, som Finder også kan følge.
- **Fil > Redigér kommentar…** (Ctrl+Z) åbner en teksteditor til en kommentar pr. fil. Kommentarer kan vises i deres egen kolonne og i statustips.

## Genveje

| Handling | Genvej |
| --- | --- |
| Redigér kommentar | Ctrl+Z |

## Bemærkninger

- Ændring af ejeren eller gruppen kræver normalt privilegier, du ikke har som almindelig bruger; når det sker, rapporteres ændringen som mislykket i stedet for at blive anvendt, og resten af dine ændringer gennemføres stadig.
- Kommentarer gemmes i en `descript.ion`-fil ved siden af dine emner og kan også opbevares som Finder-kommentarer, afhængigt af dine indstillinger. Begge læses, når en kommentar vises. Formatet er det samme, som Total Commander og flere andre filhåndteringsprogrammer bruger, så en kommentar skrevet her kan læses der.
- **En kommentar følger filen.** Kopiering, flytning og omdøbning tager den med — til målmappens `descript.ion` ved flytning og kopiering, og til det nye navn ved omdøbning, også når du fortryder omdøbningen. Undtagelsen er at lægge en fil i forlængelse af en anden: filen, der bliver tilbage, beholder sin egen kommentar, fordi den fortsat er den fil.
- Er Noter-pluginet slået til, viser og redigerer dets sidebjælke den samme kommentar over notens tekst, så der ikke er to steder til det samme.
- Et symbolsk link og et alias peger begge på et mål, men et symbolsk link gemmer en almindelig sti, mens et alias gemmer en macOS-reference, der bliver ved med at virke, hvis målet flyttes eller omdøbes. Et hårdt link er et andet navn for de samme fildata, ikke en peger.
