---
title: Makron
slug: macros
section: Kraftverktyg
order: 99
related: [automation, toolbar, start-menu, keyboard-shortcuts]
---

Ett makro är en namngiven följd av filåtgärder — skapa en mapp, flytta markeringen dit, tagga det som blir kvar — som du kan köra igen med ett klick. Det är inte ett skriptspråk: det finns inga villkor och inga loopar, och det är avsiktligt. Ett makro är en lista du kan läsa, och läsa är vad du måste kunna göra innan du godkänner den.

Allt ett makro gör går genom samma maskineri som assistenten använder, så ett makro kan inte göra något du inte har tillåtit, varje steg syns i åtgärdsloggen, och ett steg som kan ångras kan det fortfarande.

## Ett fönster: Konfiguration ▸ Makron…

Allt om makron ligger bakom den enda posten: listan över dem, de två sätten att skapa ett, och vägen in i filen. Det finns inget annat att välja mellan i menyn.

## Snabbaste vägen: spela in ett

Du behöver inte skriva ett makro från grunden — och du behöver inte heller räkna ut efteråt var det började.

1. **Konfiguration ▸ Makron… ▸ Spela in makro…**. Fönstret drar sig undan och en liten panel dyker upp som säger att en inspelning pågår och räknar stegen efter hand.
2. Gör jobbet en gång — kopiera, flytta, byt namn, radera, skapa mappar och filer. Arbeta som vanligt; inspelningen är inte i vägen.
3. **Stoppa och spara…**.
4. Stegen kommer tillbaka redan ikryssade. Kryssa ur allt som bara förberedde, ge makrot ett namn och låt **Lägg även till en knapp för det** vara på.
5. Kryssa i **Följ panelerna i stället för just dessa filer** om makrot nästa gång ska arbeta med det som då är markerat. Raderna ändras medan du kryssar, så du ser vad du sparar.

**Spara makro**, och knappen finns i raden. Det är hela varvet.

**Kasta inspelningen** slänger inspelningen och sparar ingenting. Ingenting spelas in innan du trycker Spela in, och ingenting efter att du stoppat — det är just därför det finns två ändar.

En inspelning överlever en omstart. Om Peach Commander avslutas medan en pågår — du avslutar, eller den kraschar — kommer den tillbaka med inspelningen, säger till, och du fortsätter eller kastar den.

Vill du hellre ha det på en tangent eller en knapp heter kommandot `cm_MacroRecord`: det startar en inspelning och stoppar den som pågår.

## Den andra vägen: ur det som redan hänt

**Från senaste åtgärderna…** i samma fönster bygger ett makro av det senaste som hänt i stället för att spela in nytt — användbart när du *precis* gjort jobbet och först då tänker på ett makro.

![Bladet ”Makro från senaste åtgärder” med det du nyss gjorde som kryssbara steg](screenshots/macro-recorder.png)
*Det som redan har hänt, erbjudet som stegen i ett nytt makro.*

Listan innehåller båda: vad du har gjort i panelerna (F5, F6, F7, F8 och en omdöpning) och vad assistenten eller ett annat makro har gjort. Varje rad säger vilket av de två — efter en session med båda kan samma två filer dyka upp i var och en. Här börjar raderna okryssade: ”allt jag gjort den senaste halvtimmen” är sällan det makro man menar.

> **Den här vägen behöver historiken.** Det du gör för hand läses tillbaka ur den globala historiken; har du stängt av den (Inställningar ▸ Övrigt ▸ **Spela in en global historik**) finns ingenting av ditt i listan — och den säger det. **Spela in makro…** beror inte på den.

> **Vad som inte erbjuds.** Att packa ett arkiv, och allt annat appen bara håller reda på vid namn, kan inte bli ett steg — det finns ingen form att ge det. Sådana rader står gråa med sitt skäl i stället för att saknas, så att en lista på fem som erbjuder tre inte läses som om den missat två. Och om du inte ber om annat är sökvägarna de som faktiskt användes: ett inspelat makro upprepar *den* kopian, inte ”en kopia av det slaget”. Öppna det i redigeraren och sätt `%S` eller `%T` där det ska följa panelerna.

**Följ panelerna** är hur man ber om annat. Filer som alla kom från en mapp blir markeringen; en mapp som är en av de två panelerna blir den panelen, och en mapp inuti den behåller sin svans — ett inspelat ”flytta dessa fyra fakturor till Dokument/2026-08” blir ”flytta det som är markerat till *2026-08* på andra sidan”, och det fungerar i morgon i två andra mappar. Det som inte ligger under någon av panelerna förblir den sökväg det är, för det finns inget att vika in det i. Alternativet erbjuds bara när det skulle ändra något.

## Exemplen som följer med

Första gången du öppnar **Redigera fil…** skapas filen med åtta genomarbetade exempel. Det är helt vanliga makron — ändra dem, eller ta bort dem du inte vill ha — och vart och ett bär en kommentar som säger vad det gör och vad du kan ändra:

| Makro | Vad det gör |
| --- | --- |
| **Open today's folder** | Skapar dagens datummapp i den aktiva panelen och går in i den. Går att köra igen i morgon. |
| **File the selection into a dated folder** | Väljer alla PDF:er, skapar en år-månadsmapp på andra sidan och flyttar dit dem. |
| **Copy the selection to a dated backup folder** | Kopierar det *du* har markerat till en daterad mapp på andra sidan. |
| **Move the pictures into an Images subfolder** | En mask, en undermapp, i mappen du redan står i. |
| **Merge the CSV files into one and open it** | Visar hur ett steg använder det ett tidigare steg gav. |
| **File the selection into a folder you name** | Frågar dig efter mappen när det körs. |
| **Mark the file under the cursor as reviewed** | Etiketterar den och datumstämplar dess kommentar — en fil, inte markeringen. |
| **Put the temporary files in the Trash** | Ett raderande makro, och det rätta att pröva rättighetsfrågan på. |

Vart och ett av dem blir ett kommando, så du kan lägga vilket som helst på en knapp eller en tangent utan att skriva något.

## Att hantera dem

**Konfiguration ▸ Makron…** är listan: vad varje makro heter, vad dess kommando heter, hur många steg det har och vad behörighetsspärren kommer att fråga om — så ”det här raderar” syns innan du lägger det på en tangent. Därifrån kan du köra, byta namn, duplicera, ändra ordning, radera, exportera och importera. Håller du pekaren över en rad visas dess steg.

**Kör** är sättet att prova det du just spelat in, utan att först stänga fönstret för att leta rätt på kommandot. Det går genom samma plan och samma bekräftelse som varje annan körning — det här fönstret har inga egna rättigheter.

**Exportera…** skriver det valda makrot till en egen fil, och **Importera…** lägger till makron från filer som någon skickat dig — det är vad en fil per makro är till för. En import ersätter aldrig: ett makro vars id redan är taget får ett ledigt (en inkommande `backup` blir `backup-2` bredvid ditt eget), och du får veta vilka id:n de nya hamnade på, eftersom knappen du gör måste peka på rätt.

![Fönstret ”Hantera makron” med kommandonamn, antal steg och behörighet för varje makro](screenshots/macro-manager.png)
*Vad varje makro heter, vad det körs som och vad det kommer att be om lov till.*

Ordningen är ingen utsmyckning: filens ordning är den som Kommandoöversikten och knappradens väljare listar dem i.

**Vid radering erbjuds du att ta knapparna med**, och det är värt att veta även om du aldrig öppnar det här fönstret: ett makro som tas bort för hand lämnar kvar sin knapp och sin tangent, och ingendera gör då något — appen säger nu att makrot är borta i stället för att tiga, men knappen är fortfarande din sak. En tangent eller ett menyval måste tas bort där det sattes.

*Stegen* redigeras inte här. **Redigera fil…** lämnar över till redigeraren för det, av samma skäl som det inte finns något formulär: ett steg är ett verktygsnamn med sina argument, och det är precis vad JSON är.

## Redigera makron för hand

**Redigera fil…** öppnar det valda makrots egen fil — `macros/<id>.json` i din konfigurationsmapp, skapad första gången med exemplen ovan. Utan markering visas själva mappen i panelen, där F3 läser ett och F4 redigerar ett. Ett makro är en lista med steg, och varje steg namnger ett verktyg och dess argument:

```json
{
  "id": "stage-by-month",
  "title": "File the selection into a dated folder",
  "icon": "calendar",
  "steps": [
    { "tool": "set_selection", "arguments": { "mask": "*.pdf" } },
    { "tool": "make_directory", "arguments": { "path": "%T/%{date:yyyy-MM}" } },
    { "tool": "move", "arguments": { "sources": "%S", "destination": "%T/%{date:yyyy-MM}" } }
  ]
}
```

Att spara läser om makrona direkt — och säger till om något är fel: ett felstavat verktygsnamn, ett obligatoriskt argument som saknas, två makron med samma id. Ett makro med ett fel körs inte och hamnar inte på någon knapp; du får veta vilket det är och vad som är fel med det, medan redigeraren fortfarande är öppen.

Vilka verktyg som finns och vad de tar ser du i **Konfiguration ▸ Kommandoöversikt…**, eller fråga assistenten om `list_macros`.

### Platshållare

De enskilda bokstäverna är samma som knappraden och Start-menyn använder, så har du gjort en knapp finns inget nytt att lära här.

| Platshållare | Betyder |
| --- | --- |
| `%P` | Den aktiva panelens mapp |
| `%T` | Den andra panelens mapp |
| `%N` | Filen under markören |
| `%S` | De markerade filerna — en **lista**, vilket är precis vad `copy`, `move` och `move_to_trash` tar emot |
| `%{date:yyyy-MM}` | Datumet då makrot startade, i det formatet |
| `%{1.destination}` | Ett namngivet värde ur resultatet av steg 1 — här filen som `merge_files` skrev |
| `%{1}` | Hela resultatet av steg 1, när det steget direkt gav en sökväg eller en lista med sökvägar |
| `%{ask:Folder name}` | Frågar dig när makrot körs. `%{ask:Folder name=Archive}` fyller fältet med *Archive* |

Klammerparenteserna är till för tilläggen eftersom bokstäverna redan är tagna: `%M` betyder ”namnet under markören i den andra panelen” i hela resten av programmet, så en månad kunde inte skrivas så.

Använd den **namngivna** formen för stegresultat. De flesta verktyg rapporterar flera värden i stället för ett — `merge_files` rapporterar var det skrev, hur många filer det slog ihop och hur många rader det blev — så `%{2.destination}` är den vanliga skrivningen, och ett naket `%{2}` fungerar bara för ett verktyg som ger tillbaka en enda sökväg. Ett namn som inte finns, eller som inte är en sökväg, stoppar makrot i stället för att gissas.

Ett `%` i ett filnamn är ett `%`. Inget som ett steg ger, och inget namn från en panel, läses i sin tur som en platshållare — en fil som heter `50%Netto.pdf` går alltså oförändrad genom makron. Vill du ha ett bokstavligt `%` i en mall *du* skriver, dubblera det: `%%`.

### Att fråga efter ett värde

`%{ask:…}` är hur ett makro tar emot något det inte kan veta i förväg — det allra vanligaste makrot är ”flytta markeringen till en mapp som jag namnger”, och utan detta skulle mappen behöva skrivas fast i filen.

Du får frågan **innan** planen visas, och svaren står redan i den: raderna säger ”Flytta markeringen till ”Fakturor””, inte ”till det du strax ska skriva”. Att avbryta frågan avbryter makrot; ingenting har föreslagits, än mindre körts.

Samma fråga skriven två gånger ställs en gång och används på båda ställena, så att två steg som nämner samma mapp inte kan gå isär. Det som står efter det första `=` är vad fältet börjar med. Formuleringen är din: den visas precis som du skrev den, på det språk du skrev den på.

Ett svar är ett värde, aldrig en mall: skriver du `50%Netto` får du en mapp som heter `50%Netto`.

Ett makro som frågar kan inte köras av en extern agent över MCP — där finns ingen att fråga, och att tyst ta standardvärdena vore att svara i ditt ställe. Det avvisas, och säger det.


`%S` är det enda stället där ett makro skiljer sig från en knapp: på en knapp blir markeringen en lista ord för en kommandorad, här blir den listan av fullständiga sökvägar som filverktygen tar emot.

Ett steg vars `%S` eller `%{1}` blir **tomt stoppar makrot** i stället för att köra utan något. Ett `move` utan filer är inte ett mindre `move` — det är en begäran som inte längre säger något, och att rapportera lyckat vore en lögn.

## Köra ett makro

Varje makro blir ett kommando som heter `mc_<id>` och dyker därför upp av sig själv i:

- **Konfiguration ▸ Kommandoläsare…**
- **Konfiguration ▸ Redigera kortkommandon… — lägg det på en tangent**
- Kommandoväljaren i knappradens redigerare
- Din `.mnu`-menyfil och `usercmd.ini`, om du använder dem
- Assistenten, som kan köra det på namn

Innan ett makro som ändrar något körs visar det sina steg som en lista och väntar. Du kan stryka ett steg du inte vill ha; det som blir kvar är det som körs. Ett makro som bara läser körs utan att fråga. **Att stryka ett steg tar med sig de steg som beror på det** — ett makro är en följd, och steget som fyller mappen kan inte köra utan steget som skapar den: de raderna stänger av sig själva och gråas ut. Sätt tillbaka steget så kommer de tillbaka — utom de du själv strök, som förblir strukna.

![Makrots bekräftelsedialog, varje steg en kryssruta som namnger filerna](screenshots/macro-confirm.png)
*Stegen, upplösta mot dina paneler — vart och ett går att stryka.*

Allt som går att se är fel före starten — ett verktyg som inte finns, ett saknat argument, ett steg som skulle köra ett annat makro — stoppar makrot före första steget, inte efter det tredje. Misslyckas ett steg under körningen **stannar makrot där** i stället för att fortsätta: steg två förutsätter oftast att steg ett ägde rum, och att flytta filer till en mapp som inte skapades är ingen delvis framgång. Rapporten nämner steget, säger vad som gick fel och hur många steg som redan hade utförts; vart och ett av dem står i åtgärdsloggen, med sin väg tillbaka där en sådan finns.
## Vad ett makro får göra

Ett makro bedöms efter det mest krävande i det. Ett makro vars steg bara läser behandlas som en läsning; ett som slutar med en permanent radering hanteras som en permanent radering — innan något av det körs, inte fyra steg in.

Ett steg som kör ett *kommando* bedöms efter vad det kommandot gör, inte efter att det är ett kommando — ett makro som kör `cm_DeleteReal` är alltså ett raderande makro och visas för dig som ett sådant. Ett makro kan inte köra ett annat makro, i ingen av de två skrivningarna.

Att inte ge något extra är standard. Innehåller ett makro ett steg som dina behörigheter inte tillåter — ett skalkommando, ett skript — nekas hela makrot med sin orsak, och inget händer.

## Ångra

Varje steg loggas för sig, så **ångra** efter ett makro tar tillbaka dess *sista* steg, inte hela makrot. Det finns ingen ångra för hela makrot, eftersom flera verktyg inte har någon invers alls och en knapp som erbjöd den skulle ljuga om dem.

## Var allt sparas

- Dina makron ligger i `macros/` i konfigurationsmappen, ett per `<id>.json` — vanliga filer som du kan diffa, spara med dina dotfiles och skicka till någon. En `macros.json` från en tidigare version tas med vid första starten och byter namn till `macros.json.migrated`; därefter läser ingen den.
- Knappar ett makro lade till är vanliga knappradsposter i `default.bar`, så att ta bort en är detsamma som för vilken knapp som helst.

## Nästa steg

- [Automatisering (AppleScript och Genvägar)](automation.md) — Styra Peach Commander från ett skript, och köra dina egna skript som makrosteg.
- [Knappraden](toolbar.md) — Var knappen ett makro lade till hamnar.
- [Tangentbord och kortkommandon](keyboard-shortcuts.md) — Lägga ett makro på en tangent.
