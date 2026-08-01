---
title: Utseende
slug: appearance
section: Anpassning
order: 114
related: [settings]
---

Peach Commander kan matcha utseendet på resten av din Mac eller anta en egen stil. Du kan följa systemets ljusa eller mörka inställning (eller framtvinga en av dem), färgsätta filpanelerna på nytt, lyfta fram filer efter typ och justera listans teckenstorlek och datumformat så att panelerna ser ut exakt som du vill.

## Välj ett färgtema

Ett tema byter ut hela panelpaletten i ett enda steg.

1. Öppna inställningsfönstret genom att välja Konfiguration > Alternativ…, eller tryck på Cmd+,.
2. Välj sidan **Färger**.
3. Välj i menyn **Tema**:
   - **System (standard)** — inget tema. Panelerna följer inställningen Utseende nedan, precis som tidigare. Detta är standardvalet.
   - **Ljust** / **Mörkt** — lås den inbyggda ljusa eller mörka paletten oavsett vad macOS gör.
   - **Midnatt** — ett mörkt tema som inte bara är grått: djupt indigofärgade paneler med mjukt blågrå text, vit markörrad och bärnsten för markerade filer.
   - **Norton Commander** — den klassiska blå-cyana looken från den ursprungliga DOS-filhanteraren, i äkta CGA-färger: blå paneler, cyan text, ljust cyan markörrad och gult för markerade filer.

Ett tema har en egen ljus/mörk grund så att ark, rullningslister och standardkontroller passar ihop med det — därför är menyn **Utseende** nedtonad så länge ett tema är valt. Egna panelfärger (nedan) gäller fortfarande före temat.

![Peach Commander i Norton Commander-paletten](screenshots/theme-norton.png)
*(Figur: Norton Commander-paletten — det ursprungliga CGA-blå, -cyan och -gult.)*

Norton Commander-temat använder de äkta CGA-värdena från originalet 1986: `#0000AA` blått, `#00AAAA` cyan, `#55FFFF` för markörraden och `#FFFF55` för markerade filer. Markörraden inverteras till mörk text på cyan, så som originalet ritade den, medan markerade filer behåller sitt gula.

![Närbild på markörraden i Norton-paletten](screenshots/theme-norton-cursor-crop.png)
*(Figur: markörraden inverteras; markerade filer förblir gula.)*

![Inställningssidan Färger i Norton Commander-paletten](screenshots/theme-norton-settings.png)
*(Figur: även programmets egna fönster följer temat.)*

Teman handlar bara om färger. Panelernas layout, ramarna och typsnitten är oförändrade — Norton Commander tar inte tillbaka de dubbla linjeramarna eller DOS rasterteckensnitt.

## Skriv ett eget tema

Teman är vanliga textfiler, en per tema, i en mapp `themes` inuti din konfigurationsmapp.

1. Klicka på **Temamapp…** på sidan **Färger**. Mappen skapas om den saknas, och första gången den är tom lägger Peach Commander en kommenterad `example-norton.ini` där som listar varje färg du kan ange.
2. Kopiera filen, ge den ett nytt namn och redigera den. Filnamnet (utan `.ini`) är temats id; raden `Name` är det som menyn Tema visar.
3. Spara. Öppna menyn **Tema** igen — ditt tema finns i listan. Ingen omstart behövs.

Ett minimalt tema är tre rader:

```ini
[Theme]
Name = My Midnight
Base = dark

[Colors]
ListBackground = #101020
ListText       = #C0C0D0
```

![Peach Commander i ett egenskrivet tema](screenshots/theme-custom.png)
*(Figur: ett tema inläst från en fil i temamappen.)*

`Base` väljer den inbyggda paletten (`light` eller `dark`) som ger varje färg du inte anger, så du skriver bara det du vill ändra. Färger anges som `#RRGGBB`. Rader som börjar med `;` eller `#` är kommentarer.

Är något fel i filen hoppar Peach Commander över just den raden och behåller resten av ditt tema — filen avvisas inte. Orsaken skrivs till systemloggen och syns i Konsol om du filtrerar på `[theme]`.

Namnen `light`, `dark`, `norton` och `system` tillhör de inbyggda temana; en fil med ett sådant namn hoppas över så att den inte kan skugga ett medföljande tema. Raderar du filen för det valda temat faller Peach Commander tillbaka på **System (standard)**.
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

- Menyn Utseende verkar bara så länge temat är **System (standard)**; ett tema bestämmer sin egen grund.
- Ett tema färgar även programmets egna fönster. Systemfönster — Öppna, Spara, färg- och teckensnittsväljarna och varningar — behåller sitt standardutseende, liksom fönster som insticksmoduler öppnar själva.
- Inställningen Utseende formar filpanelerna. Systemdialoger, varningar och standardkontroller följer alltid macOS.
- Den inbyggda filvisaren använder matchande ljusa och mörka paletter för syntaxfärgning, så att färgad kod förblir läsbar i båda utseendena.
- Egna färger och filtypsregler sparas med dina inställningar och tillämpas på nytt varje gång du öppnar appen.
