---
title: Filværktøjer
slug: file-utilities
section: Avancerede værktøjer
order: 94
related: [comparing-and-syncing]
---

Ud over kopiering og flytning indeholder Peach Commander et sæt daglige filværktøjer til at verificere, at filer er intakte, frigøre diskplads, dele store filer op i mindre stykker og konvertere filer til og fra tekstsikre formater. Du når dem alle fra menuen **Fil**, og de handler på det, du har markeret i det aktive panel (eller emnet under markøren, når intet er markeret). Dette emne dækker kontrolsummer, dubletfinderen, opdel/kombinér, kod/afkod og beregning af optaget plads.

## Opret eller verificér kontrolsummer

Kontrolsummer lader dig bekræfte, at en fil er overført eller kopieret uden ødelæggelse, eller give en modtager en måde at kontrollere den kopi, de modtog.

1. Markér de filer, du vil tage fingeraftryk af.
2. Vælg **Fil ▸ Opret kontrolsummer…**, vælg en algoritme (CRC32, MD5, SHA-1, SHA-256 eller SHA-512), og gem kontrolsumsfilen.
3. For at kontrollere filer senere skal du markere kontrolsumsfilen og vælge **Fil ▸ Verificér kontrolsummer…**. Peach Commander genberegner hver hash og rapporterer enhver fil, der ikke matcher.

Kontrolsummer streames direkte over den aktuelle placering, så du kan oprette eller verificere dem selv for filer inde i arkiver eller på en FTP-server.

## Find duplikerede filer

Dubletfinderen finder identiske filer spredt over mapper, så du kan fjerne de ekstra kopier.

1. Markér de mapper (eller filer), du vil scanne.
2. Vælg **Fil ▸ Find dubletter…**. Peach Commander sammenligner kandidater og grupperer filer, der er byte-for-byte identiske.
3. Gennemgå hver gruppe, markér de kopier, du ikke længere har brug for, og slet dem.

![Dubletfinderen viser grupper af identiske filer](screenshots/duplicate-finder.png)
*(Figur: Dubletfinderen grupperer identiske filer, så du kan beholde én og fjerne resten.)*

## Opdel og kombinér filer

Opdeling bryder én stor fil op i en nummereret serie af mindre dele — praktisk til opbevarings- eller overførselsgrænser. Kombinering samler dem igen.

1. For at opdele skal du markere en fil og vælge **Fil ▸ Opdel fil…**, og derefter indstille delstørrelsen. Delene skrives til det andet panels mappe.
2. For at samle igen skal du markere den første del og vælge **Fil ▸ Kombinér filer…**. Den oprindelige fil genopbygges fra de nummererede stykker.

## Kod og afkod

Kodning omdanner en binær fil til almindelig tekst, så den overlever kanaler, der kun bærer tekst (for eksempel ældre e-mail eller indsætningsfelter). Afkodning vender det om.

1. Markér en fil og vælg **Fil ▸ Kod…**, og vælg derefter et format — MIME (Base64), UUE (uuencode) eller XXE.
2. For at gendanne originalen skal du markere den kodede fil og vælge **Fil ▸ Afkod…**. Formatet registreres automatisk.

## Beregn optaget plads

For at se, hvor meget plads en mappe eller markering faktisk bruger på disken, skal du markere emnerne og trykke på **Ctrl+L** (**Fil ▸ Beregn optaget plads…**). Peach Commander lægger hver fil indeni sammen, inklusive undermapper, og viser totalen.

## Genveje

| Handling | Tast |
| --- | --- |
| Beregn optaget plads | Ctrl+L |

## Bemærkninger

- Kontrolsummer, opdel/kombinér og kod/afkod er rettet mod mere avancerede opgaver, men hver er en enkelt dialog med fornuftige standardindstillinger.
- Når et værktøj producerer nye filer (opdelte dele, en kodet fil, en kontrolsumsliste), skrives de til den mappe, der vises i det andet panel — indstil det panel til din tilsigtede destination først.
- Sletning af dubletter er permanent afhængigt af dine sletteindstillinger; gennemgå hver gruppe omhyggeligt, og behold mindst én kopi af alt, du stadig har brug for.
