---
title: Arbeidsområder
slug: workspaces
section: Tilpasning
order: 118
related: [settings, panels-and-tabs]
---

Et arbeidsområde er en navngitt sammenheng du arbeider i: «Rydde opp i sikkerhetskopier», «Sortere søknadspapirer». Hvert av dem husker begge paneler, alle åpne faner, hvilken fane som er aktiv på hver side, visningsmodusen, mappetreet, frem/tilbake-historikken og hvilke filer du hadde merket, hurtigfilteret og vinduets oppsett — sidepanelet, dokken, linjene og hvor skillelinjen står. Et bytte koster ett klikk, og underveis går aldri noe tapt — et arbeidsområde lagres aldri, fordi det aldri tar slutt.

Til du lager nummer to, er det ingenting å se. Ingen linje, ingen meny, ingen hurtigtaster.

## Slik gjør du

1. Still inn begge panelene for oppgaven: åpne mappene, legg til fanene, velg visningen du vil ha.
2. Åpne menyen **Gå** og velg **Arbeidsområder…**, deretter **Nytt arbeidsområde…**. Gi det et navn.
3. Øverst i vinduet dukker det opp en linje med fargede brikker, og i menylinjen dukker menyen **Arbeidsområde** opp. Det nye arbeidsområdet starter som en kopi av oppsettet du var i.
4. Still inn det nye arbeidsområdet for sin egen oppgave. Det du kom fra, beholder det det hadde.
5. Klikk på en brikke for å bytte, eller trykk **Ctrl+1** til **Ctrl+9**. Alt bytter med.

## Tilbake til et utgangspunkt

Hvert arbeidsområde husker også oppsettet det ble satt opp som. **Arbeidsområde ▸ Lagre gjeldende tilstand i arbeidsområdet** (Cmd+Ctrl+S) gjør det gjeldende oppsettet til dette utgangspunktet, og **Tilbakestill til lagret tilstand** fører deg dit igjen etter en ettermiddag på avveie.

Dette er uavhengig av den løpende hukommelsen: du må aldri lagre for ikke å miste plassen din.

## Samlemappen

Hvert arbeidsområde har en samlemappe — for det som faktisk skjer under opprydding: tre mapper ned i
sikkerhetskopiene finner du noe som hører til en helt annen jobb. **Dra filer til et annet
arbeidsområdes brikke**, og de havner i *dets* samlemappe — du bytter ikke, og ingenting kopieres eller
flyttes; telleren på brikken stiger, og du fortsetter. Hold **⌥** mens du slipper for å kopiere inn i
det arbeidsområdets mappe i stedet, eller **⌘** for å flytte. **Ctrl+Cmd+A** legger utvalget i det
gjeldende arbeidsområdets samlemappe, siden **Samlemappe** i sidepanelet viser innholdet, og
**Arbeidsområde ▸ Kopier samlemappen til det andre panelet** tar hele mappen i én operasjon.

Filer som siden er slettet, eller som ligger på et volum som ikke er montert, vises som manglende i
stedet for å fjernes, og en masseoperasjon tilbyr å hoppe over dem eller ta dem ut først. En flytting
tømmer samlemappen for det som ble flyttet; en kopiering lar den være.

| Handling | Hurtigtast |
| --- | --- |
| Bytt til arbeidsområde 1 til 9 | Ctrl+1 … Ctrl+9 |
| Gjør gjeldende oppsett til utgangspunktet | Cmd+Ctrl+S |

## Tips

- Høyreklikk en brikke for å gi den nytt navn, gi den en farge eller slette den — eller klikk **✕** i høyre kant, som sletter arbeidsområdet etter et spørsmål. Fargen er det du skiller arbeidsområdene fra hverandre med i et blikk når vinduet er smalt og navnene ikke lenger får plass.
- Ni er grensen, slik at hver brikke forblir gjenkjennelig.
- **Vis ▸ Vis arbeidsområdelinjen** skjuler linjen uten å slå funksjonen av — for dem som bytter mellom arbeidsområder med tastaturet.
- Arbeidsområder kan slås helt av under **Innstillinger ▸ Faner**. Arbeidsområdene dine beholdes og kommer uendret tilbake når du slår funksjonen på igjen.

## Å begrense et arbeidsområde til en mappe

Et arbeidsområde kan få vite hva det handler om, og sjekker så før en operasjon rekker utenfor.
Høyreklikk brikken, **Begrens til mappe ▸ Sett til den aktive mappen**, og velg om operasjoner utenfor
skal tillates, spørres om eller avvises.

Det sjekkes før en sletting tar filer utenfra, før en kopiering eller flytting havner utenfor, og før en
omdøping eller en ny mappe skriver utenfor. **Navigering begrenses aldri** — en filbehandler som nekter
å vise en mappe, er ødelagt, og verdien ligger helt i øyeblikket før F8. Lagringer i redigereren er
heller ikke dekket; de skjer i sitt eget vindu.

## Journalen

Hvert arbeidsområde fører regnskap over hva som er gjort i det — besøkte mapper, utførte operasjoner,
skrevne skall-linjer, og alt en mappebegrensning har avvist. **Arbeidsområde ▸ Journal…** viser den,
nyeste dag først, med et filter **Problemer** for alt som mislyktes eller ble stoppet.

Retur gjentar den valgte raden etter samme regel som historikken: bare en kopiering eller flytting kan
gjentas med ett tastetrykk, og en skall-linje fylles inn i kommandolinjen i stedet for å kjøres.
Journalen er bevisst atskilt fra den globale historikken — den svarer på "hvor pleier jeg å være" og
rangerer etter hyppighet; denne svarer på "hva skjedde her" og beholder rekkefølgen. Den slettes sammen
med arbeidsområdet sitt, beholdes ellers uten tidsgrense, og kan slås av under **Innstillinger ▸ Faner**.

## Å gi et arbeidsområde videre

**Arbeidsområde ▸ Eksporter arbeidsområde…** skriver det gjeldende arbeidsområdet til en
`.pcworkspace`-fil du kan sende til noen eller ta vare på i en prosjektmappe. **Importer
arbeidsområde…** leser den inn igjen, og det gjør et dobbeltklikk i Finder også.

Det som følger med, er arbeidsområdets **lagrede utgangspunkt** — trykk ⌘⌃S først hvis det skal være
oppsettet du har foran deg — sammen med navn, farge, mappegrense og samlemappe. Mapper inne i
hjemmemappen din skrives forkortet, slik at filen åpner i den *andres* hjemmemappe og ikke i en mappe
oppkalt etter deg.

Det som bevisst ikke følger med:

- **Alt som kunne vært en pålogging.** Faner som peker på en tilkobling eller en montert programtilleggsstasjon, fjernes ved eksporten, og rapporten sier hvor mange. Det er ingenting å miste, for ingenting om en tilkobling skrives ned.
- **Journalen.** Den noterer hva *du* har gjort, og nevner mapper på maskinen din. Den blir her.
- Markørposisjoner, angrehistorikken, vindusstørrelsen samt åpne fremviser-, redigerings-, søke- eller synkroniseringsvinduer.
- Terminalfaner og samtaler med assistenten. De hører til denne Macen; en arbeidsområdefil bærer *hvor* det arbeides, ikke hva som kjører.

En import **legger** alltid til et arbeidsområde; den erstatter aldri det du står i, og bytter aldri
av seg selv — en fil noen har sendt, skal ikke flytte vinduet ditt. Mapper som ikke finnes på denne
Macen, åpner på den nærmeste som finnes, oppføringer i samlemappen beholder stiene sine og vises
nedtonet, og en mappegrense hvis mappe mangler, beholdes, men spør i stedet for å nekte. En rapport
nevner alt sammen.

## Merknader

- Et bytte spør aldri om lagring og lukker aldri noe. Pågående filoperasjoner fortsetter, og det samme gjør alt i en terminal: fanene i arbeidsområdet du forlater settes til side med levende skall, ikke lukkes. Assistentens samtaler følger også arbeidsområdet.
- Angre følger et arbeidsområde bare så lenge appen kjører: et angretrinn bærer handlingen som reverserer det, og den kan ikke skrives til disk.
- Et arbeidsområde husker mappeplasseringer, ikke filene i dem. Er en lagret mappe flyttet eller slettet, åpner den fanen i den nærmeste mappen som fortsatt finnes.
- Ved oppgradering fra en tidligere versjon: arbeidsområder du hadde lagret før, blir brikker, og økten du var i, blir det første. Ingenting går tapt, og den gamle `workspaces.ini` beholdes som `workspaces.ini.migrated`.
