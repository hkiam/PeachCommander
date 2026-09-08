---
title: Sammenligning og synkronisering
slug: comparing-and-syncing
section: Avancerede værktøjer
order: 90
related: [multi-rename]
---

Når du har to kopier af den samme mappe — en arbejdsmappe og en backup, en bærbar og et netværksdrev, et projekt og dets arkiv — hjælper Peach Commander dig med at se præcis, hvad der er ændret, og bringe de to sider i takt igen. Du kan synkronisere to mapper, sammenligne enkelte filer linje for linje og inspicere filer byte for byte, når du har brug for sikkerhed ned til det sidste tegn.

## Synkronisér to mapper

1. Åbn den mappe, du vil synkronisere, i venstre panel og den mappe, du vil sammenligne den med, i højre panel.
2. Vælg **Kommandoer ▸ Synkronisér mapper…**. De to mappestier udfyldes fra dine paneler.
3. Indstil, hvor grundig sammenligningen skal være: inkludér undermapper, sammenlign **efter indhold** (ikke kun efter dato og størrelse) eller ignorér ændringsdatoen.
4. Tilføj en filtermaske (for eksempel `*.jpg;*.png`), hvis du kun vil synkronisere bestemte filer.
5. Gennemgå resultatgitteret. Hver række viser en fil til venstre, en retningspil i midten og den matchende fil til højre. Pilene fortæller dig, hvad der vil ske: **→** kopierer fra venstre til højre, **←** kopierer fra højre til venstre, og **=** betyder, at de to er identiske.
6. Justér individuelle rækker, hvis du er uenig i en foreslået retning, og klik derefter på synkroniseringsknappen for at udføre ændringerne.

![Vinduet til synkronisering af mapper med to mappestier og et resultatgitter af filer med venstre-, lige- og højrepile](screenshots/sync-dialog.png)
*(Figur: Vinduet Synkronisér mapper sammenligner begge sider og foreslår en kopieringsretning for hver fil.)*

## Sammenlign to filer efter indhold

1. Markér én fil i hvert panel (eller to filer i samme panel).
2. Vælg **Fil ▸ Sammenlign efter indhold…**.
3. De to filer åbner side om side med deres forskelle fremhævet. Brug kontrollerne næste/forrige til at springe mellem ændrede blokke.
4. Hvis du slår redigeringstilstand til, kan du justere hver af filerne direkte og gemme dine ændringer.

![Sammenligningsvinduet, der viser to tekstfiler side om side med afvigende linjer fremhævet](screenshots/diff-window.png)
*(Figur: Sammenligning af to tekstfiler; ændrede linjer er fremhævet på begge sider.)*

## Sammenlign filer byte for byte

Når to filer ser ens ud, men du har brug for at bevise, at de virkelig er identiske (eller finde den ene byte, der afviger), skal du bruge den binære sammenligning. Den viser begge filer i en hex-visning med afvigende bytes markeret, hvilket er ideelt til at verificere overførsler, kontrollere kodede data eller bekræfte en nøjagtig kopi.

## Sammenlign mappelister

For at få øje på forskelle mellem to åbne mapper med et enkelt blik skal du vælge **Markér ▸ Sammenlign mapper** (Shift+F2). Peach Commander markerer de filer, der afviger eller mangler på den anden side, så du kan handle på dem med de sædvanlige kommandoer til kopiering, flytning og sletning.

## Begræns hvad en synkronisering omfatter

Maskefeltet rummer én medtag-liste over filnavne. Til det, den ikke kan udtrykke, åbner **Filter…** ved siden af et ark med tre faneblade. Hvad der sættes dér, gælder den *næste* sammenligning, og knappen siger så, hvor mange kriterier der er aktive — et filter, man ikke kan se, er sådan en sikkerhedskopi ender ufuldstændig, mens vinduet melder, at den er færdig.

- **Udelad** tager mønstre adskilt af `;` eller `|`. Et navn uden skråstreg passer i enhver dybde (`*.tmp`), en skråstreg til sidst betyder en mappe med alt i den (`node_modules/`), og et mønster med skråstreg passer på den relative sti (`src/*/generated`). Der ses ikke på store og små bogstaver.
- **Størrelse** og **dato** bedømmer et par som helhed: falder én side uden for intervallet, holdes hele parret ude. Det er med vilje. Anvendt på kun én side ville en udeladelse få parret til at se ensidigt ud og blive en kopiering i den forkerte retning.
- **Inden for de sidste N dage** måles fra hver sammenligning, ikke fra da forudindstillingen blev gemt — en gemt opgave betyder altså fortsat "den seneste måned".
- Fanebladet **Plugins** spørger et indholdsplugin om den side, en fil ville blive kopieret fra. Det kræver en rigtig fil, så det tilbydes kun, når begge sider er mapper på denne Mac.

En udeladt mappe slettes heller ikke i spejltilstand — et spejl fjerner kun det, det faktisk har sammenlignet. Statuslinjen siger, hvor mange punkter filteret holdt ude, ved siden af hvad kørslen vil gøre. Et filter gemmes og indlæses sammen med den synk-forudindstilling, det hører til.

## Hold to mapper ens, begge veje

De to oprindelige tilstande kan ikke skelne én ting: en fil, der kun findes på den ene side, er
enten **ny her** eller **slettet der**, og det ser ens ud. Den symmetriske tilstand kopierer den
derfor — slet noget på din bærbare, synkronisér, og den kommer tilbage fra sikkerhedskopien — og
spejltilstanden sletter, men kun i én retning.

**Tovejs (med hukommelse)** husker, hvordan begge mapper så ud, sidst de stemte. Med den optegnelse
kan en sletning på den ene side føres over til den anden.

- Den **første** kørsel for et par har ingen optegnelse: den opfører sig som før og sletter intet. Den
  skriver optegnelsen. Fra anden kørsel virker tilstanden.
- En overført sletning vises i sin egen farve med `⇒🗑` og er **ikke** markeret: det er den eneste
  række, der kommer fra appens hukommelse. Et klik på pilen tilbyder de andre svar: kopiér filen
  tilbage i stedet, eller lad begge sider være.
- Ændret på den ene side og slettet på den anden er en **konflikt**, aldrig en sletning. Det samme
  gælder en fil, der er ændret på begge sider.
- Intet slettes på grundlag af et fravær, som sammenligningen ikke kunne bekræfte.
- Kun to mapper på denne Mac, ikke en server og ikke et arkiv.

**Der findes ingen fortryd for en sletning.** På denne Mac ryger filen i Papirkurven og kan hentes
tilbage i Finder; det er hele nettet. Optegnelsen ligger sammen med indstillingerne: flytter du en af
mapperne, har parret ingen historie mere — og en kørsel uden historie sletter intet.

## Genveje

| Handling | Genvej |
| --- | --- |
| Sammenlign mappelister (markér afvigende filer) | Shift+F2 |
| Sammenlign efter indhold | Fil ▸ Sammenlign efter indhold… |
| Synkronisér mapper | Kommandoer ▸ Synkronisér mapper… |

## Bemærkninger

- **Efter indhold vs. efter dato/størrelse.** En hurtig sammenligning matcher filer efter størrelse og ændringsdato, hvilket er hurtigt, men kan narres, når tidsstempler afviger for identiske filer. Slå **efter indhold** til for et pålideligt resultat på bekostning af at læse hver fil.
- **Undermapper og filtre.** Synkroniseringsvinduet kan gå ned i undermapper og kan begrænses med en filtermaske, så du kun kan synkronisere de filtyper, du bekymrer dig om.
- **Du bevarer kontrollen.** Synkronisering kører aldrig af sig selv — du gennemgår de foreslåede retninger i resultatgitteret og kan ændre enhver af dem, før noget kopieres.
- **Forudindstillinger.** Ofte brugte synkroniseringsopsætninger kan gemmes og genbruges, så du ikke skal indtaste de samme indstillinger hver gang.

