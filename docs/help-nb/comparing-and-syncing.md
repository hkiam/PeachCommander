---
title: Sammenligne og synkronisere
slug: comparing-and-syncing
section: Kraftverktøy
order: 90
related: [multi-rename]
---

Når du beholder to kopier av samme mappe — en arbeidsmappe og en sikkerhetskopi, en bærbar og en nettverksdeling, et prosjekt og dets arkiv — hjelper Peach Commander deg å se nøyaktig hva som endret seg og bringe de to sidene tilbake i takt. Du kan synkronisere to kataloger, sammenligne enkeltfiler linje for linje, og inspisere filer byte for byte når du trenger visshet ned til siste tegn.

## Synkroniser to kataloger

1. Åpne mappen du vil synkronisere i venstre panel og mappen du vil sammenligne den mot i høyre panel.
2. Velg **Kommandoer ▸ Synkroniser kataloger…**. De to mappestiene fylles inn fra panelene dine.
3. Angi hvor grundig sammenligningen skal være: inkluder undermapper, sammenlign **etter innhold** (ikke bare etter dato og størrelse), eller ignorer endringsdatoen.
4. Legg til en filtermaske (for eksempel `*.jpg;*.png`) hvis du bare vil synkronisere visse filer.
5. Se gjennom resultatrutenettet. Hver rad viser en fil til venstre, en retningspil i midten og den samsvarende filen til høyre. Pilene forteller deg hva som vil skje: **→** kopierer fra venstre til høyre, **←** kopierer fra høyre til venstre, og **=** betyr at de to er identiske.
6. Juster enkeltrader hvis du er uenig i en foreslått retning, og klikk deretter synkroniser-knappen for å gjennomføre endringene.

![Synkroniser kataloger-vinduet med to mappestier og et resultatrutenett av filer med venstre-, likhets- og høyrepiler](screenshots/sync-dialog.png)
*(Figur: Synkroniser kataloger-vinduet sammenligner begge sider og foreslår en kopieringsretning for hver fil.)*

## Sammenlign to filer etter innhold

1. Merk én fil i hvert panel (eller to filer i samme panel).
2. Velg **Fil ▸ Sammenlign etter innhold…**.
3. De to filene åpnes side om side med forskjellene uthevet. Bruk neste/forrige-kontrollene for å hoppe mellom endrede blokker.
4. Hvis du slår på redigeringsmodus, kan du justere begge filene direkte og lagre endringene dine.

![Sammenligningsvinduet som viser to tekstfiler side om side med avvikende linjer uthevet](screenshots/diff-window.png)
*(Figur: Sammenligning av to tekstfiler; endrede linjer uthevet på begge sider.)*

## Sammenlign filer byte for byte

Når to filer ser like ut, men du trenger å bevise at de virkelig er identiske (eller finne den ene byten som avviker), bruk den binære sammenligningen. Den viser begge filene i en heksadesimalvisning med ikke-samsvarende bytes markert, noe som er ideelt for å verifisere nedlastinger, sjekke kodede data eller bekrefte en nøyaktig kopi.

## Sammenlign kataloglister

For å oppdage forskjeller mellom to åpne mapper med ett blikk, velg **Merk ▸ Sammenlign kataloger** (Shift+F2). Peach Commander merker filene som avviker eller mangler på den andre siden, slik at du kan handle på dem med de vanlige kopier-, flytt- og slett-kommandoene.

## Begrens hva en synkronisering omfatter

Maskefeltet inneholder én ta-med-liste over filnavn. For det den ikke får sagt, åpner **Filter…** ved siden av et ark med tre faner. Det som settes der, gjelder den *neste* sammenligningen, og knappen sier så hvor mange kriterier som er aktive — et filter man ikke ser, er slik en sikkerhetskopi ender ufullstendig mens vinduet melder at den er ferdig.

- **Utelat** tar mønstre skilt med `;` eller `|`. Et navn uten skråstrek treffer i enhver dybde (`*.tmp`), en skråstrek til slutt betyr en mappe med alt i den (`node_modules/`), og et mønster med skråstrek treffer den relative stien (`src/*/generated`). Store og små bokstaver teller ikke.
- **Størrelse** og **dato** vurderer et par som helhet: faller én side utenfor området, holdes hele paret utenfor. Det er tilsiktet. Brukt på bare én side ville en utelatelse få paret til å se ensidig ut og bli en kopiering i gal retning.
- **I løpet av de siste N dagene** måles fra hver sammenligning, ikke fra da oppsettet ble lagret — en lagret jobb betyr altså fortsatt "den siste måneden".
- Fanen **Programtillegg** spør et innholdstillegg om den siden en fil ville bli kopiert fra. Det trenger en virkelig fil, så den tilbys bare når begge sider er mapper på denne Mac-en.

En utelatt mappe slettes heller ikke i speilmodus — et speil fjerner bare det det faktisk har sammenlignet. Statuslinjen sier hvor mange oppføringer filteret holdt utenfor, ved siden av hva kjøringen vil gjøre. Et filter lagres og hentes sammen med synk-oppsettet det hører til.

## Hold to mapper like, begge veier

De to opprinnelige modusene kan ikke skille én ting: en fil som bare finnes på den ene siden, er
enten **ny her** eller **slettet der**, og det ser likt ut. Den symmetriske modusen kopierer den
derfor — slett noe på den bærbare, synkronisér, og den kommer tilbake fra sikkerhetskopien — og
speilmodusen sletter, men bare i én retning.

**Toveis (med hukommelse)** husker hvordan begge mappene så ut sist de stemte. Med den oppføringen kan
en sletting på den ene siden føres over til den andre.

- Den **første** kjøringen for et par har ingen oppføring: den oppfører seg som før og sletter
  ingenting. Den skriver oppføringen. Fra andre kjøring virker modusen.
- En overført sletting vises i sin egen farge med `⇒🗑` og er **ikke** avkrysset: det er den eneste
  raden som kommer fra appens hukommelse. Et klikk på pilen tilbyr de andre svarene: kopiér filen
  tilbake i stedet, eller la begge sider være.
- Endret på den ene siden og slettet på den andre er en **konflikt**, aldri en sletting. Det samme
  gjelder en fil som er endret på begge sider.
- Ingenting slettes på grunnlag av et fravær sammenligningen ikke kunne bekrefte.
- Bare to mapper på denne Mac-en, ikke en tjener og ikke et arkiv.

**Det finnes ingen angre for en sletting.** På denne Mac-en havner filen i Papirkurven og kan hentes
tilbake i Finder; det er hele nettet. Oppføringen ligger sammen med innstillingene: flytter du en av
mappene, har paret ingen historie lenger — og en kjøring uten historie sletter ingenting.

## Snarveier

| Handling | Snarvei |
| --- | --- |
| Sammenlign kataloglister (merk avvikende filer) | Shift+F2 |
| Sammenlign etter innhold | Fil ▸ Sammenlign etter innhold… |
| Synkroniser kataloger | Kommandoer ▸ Synkroniser kataloger… |

## Merknader

- **Etter innhold kontra etter dato/størrelse.** En rask sammenligning samsvarer filer etter størrelse og endringsdato, noe som er raskt, men kan lures når tidsstempler avviker for identiske filer. Slå på **etter innhold** for et pålitelig resultat på bekostning av å lese hver fil.
- **Undermapper og filtre.** Synkroniseringsvinduet kan stige ned i undermapper og kan begrenses med en filtermaske, slik at du kan synkronisere bare filtypene du bryr deg om.
- **Du har kontrollen.** Synkronisering kjører aldri av seg selv — du ser gjennom de foreslåtte retningene i resultatrutenettet og kan endre hvilken som helst av dem før noe kopieres.
- **Forhåndsinnstillinger.** Ofte brukte synkroniseringsoppsett kan lagres og gjenbrukes slik at du ikke skriver inn de samme alternativene hver gang.

