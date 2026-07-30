---
title: Omdøbning af mange filer
slug: multi-rename
section: Avancerede værktøjer
order: 92
related: [moving-and-renaming]
---

Værktøjet til flerdobbelt omdøbning omdøber en hel bunke filer i én omgang. I stedet for at redigere navne ét ad gangen beskriver du ændringen én gang — et navnemønster, en søg-og-erstat, et nummereringsskema eller en ændring af bogstavstørrelse — og Peach Commander anvender den på hver valgt fil. En live forhåndsvisning viser præcis, hvad hver fil vil hedde, før noget sker, og en enkelt Fortryd sætter de oprindelige navne tilbage, hvis resultatet ikke var, som du ønskede.

## Omdøb en bunke filer

1. Vælg de filer, du vil omdøbe (se *Markering af filer*). Kun de valgte emner påvirkes.
2. Vælg **Kommandoer > Værktøj til flerdobbelt omdøbning…**, eller tryk på Ctrl+M.
3. Byg din omdøbningsregel ved hjælp af felterne beskrevet nedenfor. Forhåndsvisningsgitteret opdateres, mens du skriver, og viser hvert **Gammelt navn** ved siden af dets **Nye navn**.
4. Kontrollér forhåndsvisningen. En række vist i en fremhævningsfarve markerer et navn, der ikke kan bruges (for eksempel et duplikat eller et ulovligt navn), så du kan justere reglen.
5. Når forhåndsvisningen ser rigtig ud, klik på **Start**. Hvis du ombestemmer dig, klik på **Fortryd** for at gendanne de oprindelige navne.

![Vinduet til flerdobbelt omdøbning med maskefelterne, indstillinger og gammel-til-ny forhåndsvisningsgitteret](screenshots/multi-rename.png)
*(Figur: forhåndsvisningsgitteret opdateres live, mens du redigerer omdøbningsreglen; intet ændres på disken, før du klikker på Start.)*

## Opbygning af omdøbningsreglen

- **Omdøbningsmaske** og **Filtype** — mønstre der bygger det nye navn og filtype. Brug hurtigindsæt-knapperne, eller indtast pladsholdere direkte: `[N]` for det oprindelige navn, `[N1-9]` for et interval af tegn fra det, `[C]` for tælleren, `[d]` for dato- og tidsdele og `[P]` for navnet på den overordnede mappe.
- **Søg efter / Erstat med** — erstat tekst inde i navnene. Slå **Regex** til for mønstermatching, **Forskel på store/små** for at matche præcis bogstavstørrelse og **Gentag** for at erstatte hver forekomst.
- **Bogstavstørrelse** — konverter navne til små bogstaver, STORE BOGSTAVER, Første bogstav med stort eller Hvert Ord Med Stort.
- **Tæller** — angiv **Start**-nummeret, **Trin** mellem filer og hvor mange **Cifre** der skal udfyldes til (for eksempel 001, 002, 003), hvor som helst `[C]` optræder.

## Genveje

| Handling | Genvej |
| --- | --- |
| Åbn værktøjet til flerdobbelt omdøbning | Ctrl+M |
| Anvend omdøbningen | Retur |
| Luk vinduet | Esc |

## Tips

- Intet skrives til disken, før du klikker på **Start**, så du kan eksperimentere frit med reglen og se forhåndsvisningen.
- Efter en kørsel omgør **Fortryd** omdøbningen i ét trin.
- Gem en regel, du bruger ofte, som en **forudindstilling**, og vælg den derefter fra forudindstillingsmenuen næste gang for at udfylde alle felterne på én gang.
- For at omdøbe en enkelt fil eller omdøbe filer, mens du flytter dem, brug i stedet omdøbning på stedet eller flyt-dialogen (se *Flytning og omdøbning*).
