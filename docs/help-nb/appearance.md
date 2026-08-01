---
title: Utseende
slug: appearance
section: Tilpasning
order: 114
related: [settings]
---

Peach Commander kan matche utseendet til resten av din Mac eller ta en stil helt for seg selv. Du kan følge systemets lyse eller mørke innstilling (eller tvinge en), fargelegge filpanelene på nytt, fremheve filer etter type og justere listens skriftstørrelse og datoformat slik at panelene leser akkurat slik du liker det.

## Velg et fargetema

Et tema bytter ut hele panelpaletten i ett steg.

1. Åpne innstillingsvinduet ved å velge Konfigurasjon > Alternativer…, eller trykk Cmd+,.
2. Velg **Farger**-siden.
3. Velg i menyen **Tema**:
   - **System (standard)** — ingen tema. Panelene følger innstillingen Utseende nedenfor, akkurat som før. Dette er standardvalget.
   - **Lyst** / **Mørkt** — lås den innebygde lyse eller mørke paletten uansett hva macOS gjør.
   - **Norton Commander** — det klassiske blå-cyan utseendet fra den opprinnelige DOS-filbehandleren, i ekte CGA-farger: blå paneler, cyan tekst, lys cyan markørrad og gult for merkede filer.

Et tema har sitt eget lyse/mørke grunnlag, slik at ark, rullefelt og standardkontroller passer til det — derfor er menyen **Utseende** nedtonet så lenge et tema er valgt. Egne panelfarger (nedenfor) gjelder fortsatt foran temaet.

![Peach Commander i Norton Commander-paletten](screenshots/theme-norton.png)
*(Figur: Norton Commander-paletten — det opprinnelige CGA-blå, -cyan og -gult.)*

Norton Commander-temaet bruker de ekte CGA-verdiene fra originalen fra 1986: `#0000AA` blå, `#00AAAA` cyan, `#55FFFF` for markørraden og `#FFFF55` for merkede filer. Markørlinjen snus til mørk tekst på cyan, slik originalen tegnet den, mens merkede filer beholder sin gule farge.

![Nærbilde av markørraden i Norton-paletten](screenshots/theme-norton-cursor-crop.png)
*(Figur: markørlinjen snus; merkede filer forblir gule.)*

![Innstillingssiden Farger i Norton Commander-paletten](screenshots/theme-norton-settings.png)
*(Figur: programmets egne vinduer følger også temaet.)*

Temaer handler bare om farger. Paneloppsettet, rammene og skriftene er uendret — Norton Commander tar ikke tilbake de doble linjerammene eller DOS-rasterskriften.

## Skriv ditt eget tema

Temaer er vanlige tekstfiler, én per tema, i mappen `themes` inne i konfigurasjonsmappen din.

1. Klikk **Temamappe…** på siden **Farger**. Mappen opprettes hvis den mangler, og første gang den er tom legger Peach Commander en kommentert `example-norton.ini` der som lister opp hver farge du kan angi.
2. Kopier filen, gi den et nytt navn og rediger den. Filnavnet (uten `.ini`) er temaets id; linjen `Name` er det menyen Tema viser.
3. Lagre. Åpne menyen **Tema** igjen — temaet ditt står i listen. Omstart er ikke nødvendig.

Et minimalt tema er tre linjer:

```ini
[Theme]
Name = Midnight
Base = dark

[Colors]
ListBackground = #101020
ListText       = #C0C0D0
```

![Peach Commander i et selvskrevet tema](screenshots/theme-custom.png)
*(Figur: et tema lest inn fra en fil i temamappen.)*

`Base` velger den innebygde paletten (`light` eller `dark`) som leverer alle fargene du ikke nevner, så du skriver bare det du vil endre. Farger skrives som `#RRGGBB`. Linjer som begynner med `;` eller `#`, er kommentarer.

Er noe galt i filen, hopper Peach Commander over akkurat den linjen og beholder resten av temaet — filen avvises ikke. Årsaken skrives til systemloggen og vises i Konsoll hvis du filtrerer på `[theme]`.

Navnene `light`, `dark`, `norton` og `system` tilhører de innebygde temaene; en fil med et slikt navn hoppes over, så den ikke kan skygge for et medfølgende tema. Sletter du filen for det valgte temaet, faller Peach Commander tilbake til **System (standard)**.
## Angi lyst, mørkt eller systemutseende

1. Åpne innstillingsvinduet ved å velge Konfigurasjon > Alternativer…, eller trykk Cmd+,.
2. Velg **Farger**-siden.
3. Fra **Utseende**-menyen, velg ett av:
   - **System (følg macOS)** – matcher automatisk din Macs gjeldende lyse/mørke innstilling.
   - **Lyst** – bruk alltid den lyse paletten.
   - **Mørkt** – bruk alltid den mørke paletten.

![Fargeinnstillingssiden som viser Utseende-menyen og egendefinerte panelfargebrønner](screenshots/settings-colors.png)
*(Figur: Farger-siden: velg et utseende og overstyr enkelte panelfarger.)*

## Tilpass panelfarger

På den samme **Farger**-siden, under **Egendefinerte panelfarger**, slå på avkrysningsruten ved siden av et element og velg en farge fra brønnen ved siden av:

- **Tekst** – fil- og mappenavnene.
- **Bakgrunn** – panelbakgrunnen.
- **Merket tekst** – fargen brukt for merkede filer.
- **Markørramme** – omrisset rundt det gjeldende elementet.

La en avkrysningsrute være av for å beholde den innebygde fargen for det elementet. Klikk **Tilbakestill til standard** for å fjerne alle overstyringer på én gang.

## Fargelegg filer etter type

1. Åpne Konfigurasjon > Alternativer… og velg **Visning**-siden.
2. Klikk **Filtypefarger…**.
3. Legg til en regel med en navnemaske som `*.zip` eller `*.txt`, og velg deretter en farge for filer som matcher den.
4. Bruk **Legg til regel** for flere masker; klikk **Ferdig** for å lagre eller **Avbryt** for å forkaste.

Matchende filer vises da i fargen du valgte i begge paneler.

## Juster skriftstørrelse og datoformat

På **Visning**-siden kan du også:

- Velge panellistens **Skriftstørrelse** i punkter.
- Skrive inn et **Datoformat**-mønster for å styre hvordan endringsdatoer vises; la det være tomt for å bruke din Macs regionale format. En direkte forhåndsvisning vises under feltet mens du skriver.
- Slå på **Vekslende radbakgrunn** for sebrastriper som gjør lange lister lettere å skanne.

## Snarveier

| Handling | Snarvei |
| --- | --- |
| Åpne innstillinger | Cmd+, |

## Merknader

- Menyen Utseende virker bare så lenge temaet er **System (standard)**; et tema bestemmer sitt eget grunnlag.
- Et tema farger også programmets egne vinduer. Systemvinduer — Åpne, Lagre, farge- og skriftvelgerne og varsler — beholder standardutseendet, det samme gjør vinduer som tillegg åpner selv.
- Utseende-innstillingen styler filpanelene. Systemdialoger, varsler og standardkontroller følger alltid macOS.
- Den innebygde filfremviseren bruker matchende lyse og mørke paletter for syntaksutheving, så uthevet kode holder seg lesbar i begge utseender.
- Egendefinerte farger og filtyperegler lagres med innstillingene dine og brukes på nytt hver gang du åpner appen.
