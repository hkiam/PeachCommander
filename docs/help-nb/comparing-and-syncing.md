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
