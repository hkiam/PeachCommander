---
title: Innstillinger
slug: settings
section: Tilpasning
order: 116
related: [appearance, keyboard-shortcuts]
---

Innstillinger-vinduet er der du skreddersyr Peach Commander til måten du arbeider på: hvilke linjer som vises, hvordan filer vises, hvordan kopierings- og slettingsoperasjoner oppfører seg, arkivformatet brukt når du pakker, faneatferd, FTP-standarder, visningsspråket og mer. Innstillinger er gruppert i sider slik at du raskt kan finne et valg, og hver endring lagres automatisk til din personlige konfigurasjonsmappe.

## Åpne Innstillinger

1. Velg **Peach Commander > Innstillinger…**, eller trykk Cmd+, (komma).
2. Du kan også åpne det samme vinduet fra **Konfigurasjon > Alternativer…**.
3. Velg en side fra listen til venstre; valgene for den siden vises til høyre.
4. Juster kontrollene. Endringer trer i kraft med en gang med mindre en merknad på siden sier noe annet.
5. Vil du rett til en innstilling, skriv i søkefeltet øverst i vinduet. Treff fra *alle* sider listes opp med siden hver av dem hører til, og velger du en, åpnes den siden med innstillingen uthevet. ↑/↓ flytter gjennom resultatene, Return åpner det uthevede, og Esc forlater søket og setter tilbake siden du kom fra.

![Innstillinger-vinduet som viser Oppsett-siden med avkrysningsruter for grensesnittlinjene](screenshots/settings-layout.png)
*(Figur: Oppsett-siden styrer hvilke linjer som vises rundt panelene.)*

## Sidene

Vinduet har disse sidene, i rekkefølge:

- **Oppsett** – vis eller skjul stasjonslinjen, fanelinjen, banelinjen og statuslinjen, og velg hvilke sider sidepanelet tilbyr.
- **Visning** – hvordan filer og mapper listes, inkludert datoformatet.
- **Ikoner** – ikonutseende i fillistene.
- **Betjening** – generell atferd, som hva som skjer når du skriver i et panel (hurtigsøk kontra kommandolinjen).
- **Farger** – egendefinerte panelfarger, eller la dem følge det gjeldende temaet.
- **Bekreftelse** – hvilke handlinger som ber deg bekrefte først, som sletting.
- **Rediger/Vis** – om lagring i redigeringsprogrammet beholder en `.bak`-sikkerhetskopi, programmene brukt til å redigere og vise filer, og assosiasjoner per type.
- **Kopier/Slett** – bevar filmetadata, bruk rask kloning, kopier bare nyere filer, verifiser etter kopiering, send slettinger til papirkurven, og sett en valgfri hastighetsgrense.
- **Zip/Pakker** – standard arkivformat og komprimeringsnivå brukt når du pakker.
- **Programtillegg** – slå installerte programtillegg på eller av.
- **Faner** – hvordan mappefaner åpnes og oppfører seg.
- **FTP** – nettverksstandarder som keep-alive-intervallet.
- **Tastatur** – se gjennom og endre tastatursnarveier.
- **Språk** – velg Systemstandard, Engelsk eller Deutsch.
- **AI** – sett opp AI-assistenten: foretrukket modell, skyendepunkt og -nøkkel, autonomi, og den valgfrie MCP-serveren (se [AI Assistant](ai-assistant.md)).
- **Diverse** – åpne konfigurasjonsmappen din i Finder.

Aktiverte programtillegg kan legge til sine egne sider etter de innebygde – for eksempel **Disk Map** og **System Monitor** – så valgene deres bor i det samme vinduet (se [Programtillegg](plugins.md)).

![Innstillinger-vinduet som viser Visning-sidens valg for hvordan filer listes](screenshots/settings-display.png)
*(Figur: Visning-siden styrer hvordan filer og mapper listes.)*

![Innstillinger-vinduet som viser Betjening-siden](screenshots/settings-operation.png)
*(Figur: Betjening-siden styrer hurtigsøk- og museatferd.)*

## Hvor innstillingene dine lagres

Konfigurasjonen din holdes i klartekstfiler inne i din personlige Application Support-mappe, på `~/Library/Application Support/PeachCommander`. For å åpne den, gå til **Diverse**-siden og klikk **Åpne konfigurasjonsmappe**. Lagrede FTP-passord lagres ikke i disse filene; de holdes trygt i macOS-nøkkelringen.

Innstillinger skrives etter hvert som du endrer dem. Du kan også tvinge en lagring når som helst med **Konfigurasjon > Lagre innstillinger**, og lagre den gjeldende vindusplasseringen og paneloppsettet med **Konfigurasjon > Lagre posisjon**.

## Ta med innstillinger fra Total Commander

Hvis du flytter fra Total Commander på Windows, kan du importere de lagrede FTP-stedene dine. Velg **Konfigurasjon > Importer wincmd.ini…** og velg Total Commander-FTP-konfigurasjonsfilen din. Tilkoblingene dine legges til i Peach Commander i den samme rekkefølgen de dukket opp der.

## Snarveier

| Handling | Snarvei |
| --- | --- |
| Åpne Innstillinger | Cmd+, |

## Merknader

- **Språk**-siden tilbyr Systemstandard, Engelsk og Deutsch. Å endre språket trer i kraft først etter at du starter Peach Commander på nytt.
- Farger satt på **Farger**-siden overstyrer temaet; bruk **Tilbakestill til standard** der for å gå tilbake til temaets farger.
- Peach Commander lagrer innstillingene sine bare i sin egen konfigurasjonsmappe, så endringene dine påvirker aldri andre apper og er enkle å sikkerhetskopiere ved å kopiere den mappen.
