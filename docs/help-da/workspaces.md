---
title: Arbejdsområder
slug: workspaces
section: Tilpasning
order: 118
related: [settings, panels-and-tabs]
---

Et arbejdsområde er en navngivet sammenhæng, du arbejder i: “Ryd op i backups”, “Sortér ansøgninger”. Hvert enkelt husker begge paneler, alle åbne faneblade, hvilket faneblad der er aktivt i hver side, visningstilstanden, mappetræet, frem/tilbage-historikken og hvilke filer du havde markeret, hurtigfilteret og vinduets opsætning — sidepanelet, dokken, linjerne og delelinjens placering. Et skift koster ét klik, og undervejs går der aldrig noget tabt — et arbejdsområde gemmes aldrig, fordi det aldrig slutter.

Indtil du opretter nummer to, er der intet at se. Ingen linje, ingen menu, ingen tastaturgenveje.

## Sådan gør du

1. Indret begge paneler til opgaven: åbn mapperne, tilføj fanebladene, vælg den visning, du vil have.
2. Åbn menuen **Gå** og vælg **Arbejdsområder…**, derefter **Nyt arbejdsområde…**. Giv det et navn.
3. Øverst i vinduet dukker en linje med farvede chips op, og i menulinjen dukker menuen **Arbejdsområde** op. Det nye arbejdsområde begynder som en kopi af den opsætning, du var i.
4. Indret det nye arbejdsområde til sin egen opgave. Det, du kom fra, beholder, hvad det havde.
5. Klik på en chip for at skifte, eller tryk **Ctrl+1** til **Ctrl+9**. Alt skifter med.

## Tilbage til et udgangspunkt

Hvert arbejdsområde husker også den opsætning, det blev indrettet som. **Arbejdsområde ▸ Gem nuværende tilstand i arbejdsområdet** (Cmd+Ctrl+S) gør den nuværende opsætning til dette udgangspunkt, og **Gendan gemt tilstand** fører dig tilbage dertil efter en eftermiddag på afveje.

Det er uafhængigt af den løbende hukommelse: du skal aldrig gemme for ikke at miste din plads.

## Samlemappen

Hvert arbejdsområde har en samlemappe — til det, der faktisk sker under oprydning: tre mapper nede i
backupperne finder du noget, der hører til et helt andet job. **Træk filer over på et andet
arbejdsområdes chip**, og de lander i *dets* samlemappe — du skifter ikke, og intet kopieres eller
flyttes; tælleren på chippen stiger, og du fortsætter. Hold **⌥** nede ved slip for i stedet at kopiere
ind i det arbejdsområdes mappe, eller **⌘** for at flytte. **Ctrl+Cmd+A** lægger markeringen i det
aktuelle arbejdsområdes samlemappe, siden **Samlemappe** i sidepanelet viser indholdet, og
**Arbejdsområde ▸ Kopiér samlemappen til det andet panel** klarer hele mappen i én handling.

Filer, der siden er slettet, eller som ligger på et ikke-monteret volumen, vises som manglende i stedet
for at blive fjernet, og en massehandling tilbyder at springe dem over eller tage dem ud først. En
flytning tømmer samlemappen for det flyttede; en kopiering lader den være.

| Handling | Genvej |
| --- | --- |
| Skift til arbejdsområde 1 til 9 | Ctrl+1 … Ctrl+9 |
| Gør den nuværende opsætning til udgangspunktet | Cmd+Ctrl+S |

## Tip

- Højreklik på en chip for at omdøbe den, give den en farve eller slette den — eller klik på **✕** i dens højre ende, som sletter arbejdsområdet efter et spørgsmål. Farven er det, du kender arbejdsområderne fra hinanden på med et blik, når vinduet er smalt, og navnene ikke længere er plads til.
- Ni er grænsen, så hver chip forbliver genkendelig.
- **Vis ▸ Vis arbejdsområdelinje** skjuler linjen uden at slå funktionen fra — for dem, der skifter mellem arbejdsområder med tastaturet.
- Arbejdsområder kan slås helt fra under **Indstillinger ▸ Faneblade**. Dine arbejdsområder bevares og kommer uændret tilbage, når du slår funktionen til igen.

## At begrænse et arbejdsområde til en mappe

Et arbejdsområde kan få at vide, hvad det handler om, og tjekker så, før en handling rækker udenfor.
Højreklik på dets chip, **Begræns til mappe ▸ Sæt til den aktive mappe**, og vælg, om handlinger
udenfor skal tillades, spørges om eller afvises.

Der tjekkes, før en sletning tager filer udefra, før en kopiering eller flytning lander udenfor, og før
en omdøbning eller en ny mappe skriver udenfor. **Navigation begrænses aldrig** — en filhåndtering, der
nægter at vise en mappe, er i stykker, og værdien ligger helt i øjeblikket før F8. Gemninger i editoren
er heller ikke dækket; de sker i deres eget vindue.

## Journalen

Hvert arbejdsområde fører regnskab med, hvad der er gjort i det — besøgte mapper, udførte handlinger,
indtastede shell-linjer, og alt hvad en mappebegrænsning har afvist. **Arbejdsområde ▸ Journal…** viser
den, nyeste dag først, med et filter **Problemer** for alt, der mislykkedes eller blev stoppet.

Retur gentager den valgte række efter samme regel som historikken: kun en kopiering eller flytning kan
gentages med ét tastetryk, og en shell-linje sættes ind i kommandolinjen i stedet for at blive kørt.
Journalen er bevidst adskilt fra den globale historik — den svarer på "hvor plejer jeg at være" og
rangerer efter hyppighed; denne svarer på "hvad skete der her" og bevarer rækkefølgen. Den slettes
sammen med sit arbejdsområde, bevares ellers uden tidsgrænse, og kan slås fra under **Indstillinger ▸
Faneblade**.

## At give et arbejdsområde videre

**Arbejdsområde ▸ Eksportér arbejdsområde…** skriver det aktuelle arbejdsområde til en
`.pcworkspace`-fil, som du kan sende til nogen eller gemme i en projektmappe. **Importér
arbejdsområde…** læser den ind igen, og det gør et dobbeltklik i Finder også.

Det, der følger med, er arbejdsområdets **gemte udgangspunkt** — tryk ⌘⌃S først, hvis det skal være
den opstilling, du har foran dig — sammen med navn, farve, mappegrænse og samlemappe. Mapper inde i
din hjemmemappe skrives forkortet, så filen åbner i den *andens* hjemmemappe og ikke i en mappe
opkaldt efter dig.

Det, der bevidst ikke følger med:

- **Alt, der kunne være et login.** Faneblade, der peger på en forbindelse eller et monteret plugin-drev, fjernes ved eksporten, og rapporten siger hvor mange. Der er intet at miste, for der skrives intet ned om en forbindelse.
- **Journalen.** Den noterer, hvad *du* har gjort, og nævner mapper på din maskine. Den bliver her.
- Markørpositioner, fortryd-historikken, vinduets størrelse samt åbne fremviser-, redigerings-, søge- eller synkroniseringsvinduer.
- Terminalfaneblade og samtaler med assistenten. De hører til denne Mac; en arbejdsområdefil bærer *hvor* der arbejdes, ikke hvad der kører.

En import **tilføjer** altid et arbejdsområde; den erstatter aldrig det, du står i, og skifter aldrig
af sig selv — en fil, nogen har sendt, skal ikke flytte dit vindue. Mapper, der ikke findes på denne
Mac, åbner på den nærmeste, der gør, poster i samlemappen beholder deres stier og vises nedtonet, og
en mappegrænse, hvis mappe mangler, beholdes, men spørger i stedet for at nægte. En rapport nævner
det hele.

## Bemærkninger

- Et skift spørger aldrig, om der skal gemmes, og lukker aldrig noget. Igangværende filhandlinger fortsætter, og det samme gør alt i en terminal: fanebladene i det arbejdsområde, du forlader, sættes til side med levende skaller, ikke lukkes. Assistentens samtaler følger også arbejdsområdet.
- Fortryd følger et arbejdsområde, kun så længe appen kører: et fortryd-trin bærer den handling, der vender det om, og den kan ikke skrives til disken.
- Et arbejdsområde husker mappeplaceringer, ikke filerne i dem. Er en gemt mappe flyttet eller slettet, åbner det faneblad i den nærmeste mappe, der stadig findes.
- Ved opgradering fra en tidligere version: arbejdsområder, du havde gemt før, bliver til chips, og den session, du var i, bliver det første. Intet går tabt, og den gamle `workspaces.ini` bevares som `workspaces.ini.migrated`.
