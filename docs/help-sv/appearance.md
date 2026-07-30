---
title: Utseende
slug: appearance
section: Anpassning
order: 114
related: [settings]
---

Peach Commander kan matcha utseendet på resten av din Mac eller anta en egen stil. Du kan följa systemets ljusa eller mörka inställning (eller framtvinga en av dem), färgsätta filpanelerna på nytt, lyfta fram filer efter typ och justera listans teckenstorlek och datumformat så att panelerna ser ut exakt som du vill.

## Ställ in ljust, mörkt eller systemutseende

1. Öppna inställningsfönstret genom att välja Konfiguration > Alternativ…, eller tryck på Cmd+,.
2. Välj sidan **Färger**.
3. Välj ett av följande i menyn **Utseende**:
   - **System (följ macOS)** – matchar din Macs aktuella ljusa/mörka inställning automatiskt.
   - **Ljust** – använd alltid den ljusa paletten.
   - **Mörkt** – använd alltid den mörka paletten.

![Inställningssidan Färger med menyn Utseende och färgrutor för egna panelfärger](screenshots/settings-colors.png)
*(Figur: Sidan Färger: välj ett utseende och åsidosätt enskilda panelfärger.)*

## Anpassa panelfärger

På samma sida **Färger**, under **Egna panelfärger**, slår du på kryssrutan bredvid valfritt element och väljer en färg från rutan intill:

- **Text** – fil- och mappnamnen.
- **Bakgrund** – panelens bakgrund.
- **Markerad text** – färgen som används för markerade filer.
- **Markörram** – konturen runt det aktuella objektet.

Lämna en kryssruta avstängd för att behålla den inbyggda färgen för det elementet. Klicka på **Återställ till standard** för att rensa alla åsidosättningar på en gång.

## Färglägg filer efter typ

1. Öppna Konfiguration > Alternativ… och välj sidan **Visning**.
2. Klicka på **Filtypsfärger…**.
3. Lägg till en regel med en namnmask såsom `*.zip` eller `*.txt`, och välj sedan en färg för filer som matchar den.
4. Använd **Lägg till regel** för fler masker; klicka på **Klar** för att spara eller **Avbryt** för att förkasta.

Matchande filer visas sedan i din valda färg i båda panelerna.

## Justera teckenstorlek och datumformat

På sidan **Visning** kan du även:

- Välja panellistans **teckenstorlek** i punkter.
- Ange ett mönster för **datumformat** för att styra hur ändringsdatum visas; lämna det tomt för att använda din Macs regionala format. En liveförhandsvisning visas under fältet medan du skriver.
- Slå på **Växlande radbakgrund** för zebramönstring som gör långa listor lättare att överblicka.

## Kortkommandon

| Åtgärd | Kortkommando |
| --- | --- |
| Öppna inställningar | Cmd+, |

## Anteckningar

- Inställningen Utseende formar filpanelerna. Systemdialoger, varningar och standardkontroller följer alltid macOS.
- Den inbyggda filvisaren använder matchande ljusa och mörka paletter för syntaxfärgning, så att färgad kod förblir läsbar i båda utseendena.
- Egna färger och filtypsregler sparas med dina inställningar och tillämpas på nytt varje gång du öppnar appen.
