---
title: Filverktøy
slug: file-utilities
section: Kraftverktøy
order: 94
related: [comparing-and-syncing]
---

Utover kopiering og flytting inkluderer Peach Commander et sett med hverdagslige filverktøy for å verifisere at filer er intakte, gjenvinne diskplass, dele opp store filer i mindre biter, og konvertere filer til og fra tekstsikre formater. Du når alle sammen fra **Fil**-menyen, og de handler på det du har merket i det aktive panelet (eller elementet under markøren når ingenting er merket). Dette emnet dekker sjekksummer, duplikatfinneren, del/kombiner, kod/dekod og beregning av opptatt plass.

## Opprett eller verifiser sjekksummer

Sjekksummer lar deg bekrefte at en fil ble lastet ned eller kopiert uten korrupsjon, eller gi en mottaker en måte å sjekke kopien de mottok på.

1. Merk filene du vil ta fingeravtrykk av.
2. Velg **Fil ▸ Opprett sjekksummer…**, velg en algoritme (CRC32, MD5, SHA-1, SHA-256 eller SHA-512), og lagre sjekksumfilen.
3. For å sjekke filer senere, merk sjekksumfilen og velg **Fil ▸ Verifiser sjekksummer…**. Peach Commander beregner hver hash på nytt og rapporterer enhver fil som ikke stemmer.

Sjekksummer strømmer direkte over gjeldende plassering, så du kan opprette eller verifisere dem selv for filer inne i arkiver eller på en FTP-server.

## Finn duplikatfiler

Duplikatfinneren finner identiske filer spredt over mapper slik at du kan fjerne de ekstra kopiene.

1. Merk mappene (eller filene) du vil skanne.
2. Velg **Fil ▸ Finn duplikater…**. Peach Commander sammenligner kandidater og grupperer filer som er byte-for-byte identiske.
3. Se gjennom hver gruppe, merk kopiene du ikke lenger trenger, og slett dem.

![Duplikatfinneren som lister opp grupper av identiske filer](screenshots/duplicate-finder.png)
*(Figur: Duplikatfinneren grupperer identiske filer slik at du kan beholde én og fjerne resten.)*

## Del og kombiner filer

Deling bryter én stor fil opp i en nummerert serie mindre deler — praktisk for lagrings- eller overføringsgrenser. Kombinering setter dem sammen igjen.

1. For å dele, merk en fil og velg **Fil ▸ Del fil…**, og sett deretter delstørrelsen. Delene skrives til det andre panelets mappe.
2. For å sette sammen igjen, merk den første delen og velg **Fil ▸ Kombiner filer…**. Originalfilen bygges opp igjen fra de nummererte bitene.

## Kod og dekod

Koding gjør en binærfil om til ren tekst slik at den overlever kanaler som bare bærer tekst (for eksempel eldre e-post eller innlimingsbokser). Dekoding reverserer det.

1. Merk en fil og velg **Fil ▸ Kod…**, og velg deretter et format — MIME (Base64), UUE (uuencode) eller XXE.
2. For å gjenopprette originalen, merk den kodede filen og velg **Fil ▸ Dekod…**. Formatet oppdages automatisk.

## Beregn opptatt plass

For å se hvor mye plass en mappe eller et utvalg faktisk bruker på disken, merk elementene og trykk **Ctrl+L** (**Fil ▸ Beregn opptatt plass…**). Peach Commander summerer hver fil inni, inkludert undermapper, og viser totalen.

## Snarveier

| Handling | Tast |
| --- | --- |
| Beregn opptatt plass | Ctrl+L |

## Merknader

- Sjekksummer, del/kombiner og kod/dekod er rettet mot mer avanserte oppgaver, men hver er en enkelt dialog med fornuftige standardverdier.
- Når et verktøy produserer nye filer (deler fra en oppdeling, en kodet fil, en sjekksumliste), skrives de til mappen som vises i det andre panelet — sett det panelet til ditt tiltenkte mål først.
- Å slette duplikater er permanent avhengig av sletteinnstillingene dine; se gjennom hver gruppe nøye og behold minst én kopi av alt du fortsatt trenger.
