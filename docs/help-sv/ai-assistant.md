---
title: AI-assistent
slug: ai-assistant
section: Insticksprogram
order: 122
related: [plugins, settings, privacy-and-security, macros]
---

AI-assistenten är ett valfritt, borttagbart insticksprogram som hjälper dig att arbeta med dina filer på vanligt språk. Den kan sammanfatta eller förklara ett dokument, föreslå ett bättre filnamn, översätta eller korrekturläsa text, göra om data till en tabell och till och med städa upp en mapp — och den kan utföra filåtgärder åt dig efter att först ha visat dig en plan. Den kommer som två insticksprogram: **AI On-Device** körs på Apple Intelligence och ger dig de åtgärder som visar ett förslag och tillämpar det, medan **AI Assistant** är chatten och behöver en molnmodell. Slå på det ena, eller båda. **De kommer avstängda.** Slå på dem i **Konfiguration ▸ Insticksprogram…** och starta om, eller låt dem vara av så syns ingenting — ingen AI ▸-meny, ingen chatt, ingen kolumn. Det är avsiktligt så länge detta är i beta: den kan byta namn på, flytta och radera filer och köra skalkommandon åt dig, var och en bakom en plan som du godkänner, och det är mycket räckvidd att ge en nyhet som standard. Utan API-nyckel sker allt på din Mac, så det här handlar om räckvidden och inte om något som lämnar maskinen. Insticksprogrammet **AI Column** visar vad de åtgärderna kom fram till — en sammanfattning, en sort, ett ämne, ett datum — som kolumner i panelen; det startar ingen egen modell. Det kommer avstängt tillsammans med dem och förblir valfritt, och visar ingenting förrän du slår på det och lägger till någon av dess kolumner. Från samma sida kan du också ta bort vilket som helst av dem helt.

**På enheten eller i molnet.** Den lokala modellen är privat och gratis, och den är liten: den tar in några tusen ord i taget. Att läsa en *hel* lång fil fungerar därför annorlunda — assistenten läser den i stycken och fogar samman resultaten, vilket tar längre tid ju längre filen är. För tungt arbete över många filer, eller för långa samtal, är en molnmodell snabbare och håller mer på en gång. Åtgärderna i högerklicksmenyn körs alltid på din Mac; det är chatten som är den halvan som vill ha en slutpunkt, och **Inställningar ▸ AI** är där du ger den en.

## Öppna assistenten

Välj **Kommandon ▸ AI-assistent** för att visa assistenten i en panel dockad till höger i fönstret. Skriv en förfrågan och tryck på Retur; assistenten kan läsa filer, slå upp saker och — med din bekräftelse — göra ändringar.

![AI-assistentens chatt dockad bredvid filpanelerna](screenshots/ai-chat.png)
*(Bild: AI-assistenten, dockad till höger, arbetar med en förfrågan.)*

## Åtgärder i högerklicksmenyn (AI ▸)

Snabbaste sättet att använda assistenten är undermenyn **AI ▸** i högerklicksmenyn:

- **På en fil** — Sammanfatta, Förklara, Klassificera, Föreslå ett namn, Föreslå en kommentar, Översätt till engelska, Korrekturläs, Hitta uppgifter och Gör en tabell.
- **På panelens bakgrund** — Städa den här mappen, Sök efter betydelse och Hitta troliga dubbletter.

**Sammanfatta**, **Förklara**, **Klassificera**, **Föreslå ett namn**, **Föreslå en kommentar**, **Gör en tabell** och **Städa den här mappen** kommer från insticksprogrammet **AI On-Device** och gör sitt arbete utan att öppna någon chatt alls — även på en inskanning eller en skärmbild, eftersom orden först läses av från bilden: de visar sitt förslag i ett blad, du bockar ur det du vill lämna i fred, och ingenting på disken ändras förrän du godkänner. Övriga åtgärder hör till insticksprogrammet **AI Assistant** och öppnar sin **egen chatt med rubrik** (till exempel *Översätt – rapport.txt*), så att olika uppgifter hålls isär i stället för att staplas i ett enda långt samtal. När du själv skriver i inmatningsfältet fortsätter den förfrågan den aktuella chatten.

**Flera filer på en gång.** Markera ett urval så körs åtgärden över varje markerad fil, en efter en. Åtgärderna som använder ett blad visar sitt förlopp i det och **Avbryt** stannar mellan filer; de som öppnar en chatt lägger förloppet i statusraden, där **Stoppa** gör detsamma. I båda fallen kan du titta på de första resultaten och avbryta.

**Föreslå ett namn** slutar i en knapp i stället för i en mening: det föreslagna namnet visas i en rad under samtalet, med en knapp **Byt namn** bredvid. Att trycka på den är godkännandet — du tillfrågas inte två gånger. **Klassificera** slutar med ett eget erbjudande: **Lägg i mappar…** föreslår ett mål för varje fil den just klassificerat — en mapp uppkallad efter dess sort, och ett år under den när dokumentet anger ett datum — och flyttar ingenting förrän du godkänt listan. Varje rad anger ämnet som hittades, så en sort som blivit för bred syns innan något läggs undan. Ångra tar tillbaka en målmapp i taget.

### Dina egna formuleringar

Vad varje åtgärd ber modellen om är en textfil som du kan redigera: `aichat/skills.json` för filåtgärderna och `aichat/folder-skills.json` för mappåtgärderna, i din konfigurationsmapp. Båda skrivs ut med de inbyggda formuleringarna första gången assistenten körs, så att du ser formatet. `{name}` och `{path}` står för filen. Radera en fil för att gå tillbaka till den inbyggda formuleringen.

**Egna åtgärder.** Lägg till en post med ett `id` du väljer själv, så kan den köras som vilket annat kommando som helst genom att du anger `plugin.ai.skill.<id>` — i användarmenyn, på knappraden eller på ett tangentbordskommando. (För en mappåtgärd, `plugin.ai.folderskill.<id>`.) Undermenyn **AI ▸** listar bara de inbyggda åtgärderna: den byggs från insticksprogrammets manifest utan att ladda det, så att ett avstängt insticksprogram inte bidrar med något — därför placerar du dina egna åtgärder själv i stället för att de dyker upp där. Ange ett id som inte finns och assistenten säger det i stället för att inte göra någonting.

## Be den hitta en fil

Du behöver inte veta var en fil finns. Beskriv den så slår assistenten upp den i det index som macOS redan håller över din disk — det finns alltså ingenting att bygga och ingen väntan på att det ska hinna ikapp.

- *"Hitta PDF-fakturan från förra månaden"* — en sort, ett ord i namnet och ett tidsfönster.
- *"Var finns alla mina node_modules-mappar?"* — mappar, efter namn, var som helst i din hemmapp.
- *"Vilken fil nämner Aachen-kontraktet?"* — ord **inuti** filer, vilket den vanliga sökningen Sök filer inte klarar om du inte först pekar ut en mapp.

Du kan styra var den letar: din hemmapp som standard, hela datorn, eller bara den mapp en panel visar. Den talar om vilken av dem den använde, så att ett tomt svar går att läsa i stället för att likna en axelryckning.

Två gränser värda att känna till. macOS håller vissa platser utanför sitt index — och utom räckhåll för varje app utan Full diskåtkomst — så "hittade ingenting" är inget bevis för att en fil inte finns; se [Felsökning](troubleshooting). Och en nyss skapad fil kanske ännu inte är indexerad, och då hittar **Sök filer** (Alt+F7), som går igenom mapparna själv, den ändå.

## Hantera dina chattar

- Använd chattväljaren högst upp i panelen för att växla mellan samtal.
- Menyn **Radera ▾** erbjuder **Radera den här chatten** och **Radera alla chattar**, så att du kan rensa allt på en gång när listan blir lång. Tomma chattar rensas automatiskt när du stänger panelen.

## Ändringar bekräftas först

För allt som ändrar filer — flytta, byta namn, skriva, radera — visar assistenten en **plan och väntar på din bekräftelse** innan den handlar. Du kan ändra det i Inställningar genom att höja assistentens självständighet, eller sänka den till skrivskyddad så att den aldrig ändrar något. En kopiering eller flytt rapporteras som klar när den är klar: assistenten väntar på att överföringen ska bli färdig, och du kan följa den i Överföringshanteraren som vilken annan åtgärd som helst.

**Du kan godkänna en del av en plan.** När en plan omfattar flera filer — byta namn på en hel mapp, rensa ut dina Hämtade filer — visas var och en som en ikryssad rad ovanför knapparna. Kryssa ur dem du vill lämna i fred och tryck på **Bekräfta och kör**: resten går igenom, och det du kryssat ur rörs inte. Att kryssa ur allt är samma sak som att avbryta, och assistenten säger det i stället för att rapportera att den inte gjorde något. En plan som är en enda åtgärd har ingen lista, eftersom Bekräfta och Avbryt redan säger ja och nej till den.

## Vad assistenten gjorde, och hur du tar tillbaka det

**Åtgärder ▾** i chatten har två poster:

- **Visa vad assistenten gjorde…** listar varje ändring, den senaste först, med vad som begärdes och hur det gick — inklusive försök som självständighetsinställningen nekade. En extern agent ansluten över MCP finns i samma lista.
- **Ångra senaste ändringen** tar tillbaka den senaste ändringen som har en motsats: ett namnbyte byts tillbaka, en flytt flyttas tillbaka. Där ingenting kan tas tillbaka säger listan varför — en överskriven fil sparades ingenstans, och objekt i Papperskorgen återställs från Finder.

Du kan också bara fråga: *"ångra det"* och *"vad har du ändrat?"* når samma två funktioner.

Den listan är också där ett makro kommer ifrån: **Konfiguration ▸ Makro från senaste åtgärder…** erbjuder det assistenten just gjorde som stegen i ett makro du kan köra igen, från en knapp eller en tangent. Se [Makron](macros.md).

## Kolumner i panelen

Vad åtgärderna kom fram till finns som kolumner. Lägg till dem från kolumnuppsättningsredigeraren: **AI-sammanfattning** visar första raden i en sammanfattning, och **AI-typ**, **AI-ämne** och **AI-datum** visar vad **Klassificera** gjorde av en fil — under de namnen på svenska, översatta i varje språk. Var och en förblir tom tills en åtgärd har läst just den filen — de här kolumnerna visar redan utfört arbete och startar aldrig modellen själva. **Språk** i samma insticksprogram känner igen vilket språk en textfil är skriven på, helt utan modell.

Samma tre är också namnbytesplatshållare. `[=ai_column.ai_topic]-[Y]-[M].[E]` i dialogrutan för flerfilsnamnbyte (Ctrl+M) ger en mapp full av `dokument1.pdf` namn efter vad de är: ingenting byggdes för det, eftersom namnbytesmasken alltid har löst upp `[=provider.field]` genom kolumnsystemet. Klassificera först, byt namn sedan. Rubriken följer ditt språk; `ai_column.ai_topic` inuti masken gör det inte — en mask fortsätter alltså fungera om du byter språk.

## Inställningar

Öppna **Konfiguration ▸ Inställningar ▸ AI** för att ställa in assistenten på en enda sida:

- **Chattmodell** — vad chatten **AI Assistant** kör på. Sedan de lokala åtgärderna blev ett eget insticksprogram finns det två svar, inte tre: *Molnslutpunkten nedan, om du angett en*, eller *Ingenting — låt insticksprogrammet AI On-Device sköta arbetet*. Sidan är grupperad på samma sätt: först chattens inställningar, under dem vad båda halvorna får göra.
- **Molnslutpunkt, modell och API-nyckel** — för att använda en OpenAI-kompatibel modell i stället för den lokala. Nyckeln ligger i macOS nyckelring, aldrig i dina konfigurationsfiler.
- **Assistentens självständighet** — skrivskyddad, bekräfta ändringar (standard) eller självständig.
- **Egen systemprompt** — valfria anvisningar som formar hur assistenten svarar.
- **MCP-server** — en valfri, enbart lokal server som låter en extern agent styra appen; avstängd som standard och möjlig att skydda med en token.

![AI-sidan i Inställningar med självständighet och MCP-serverns alternativ](screenshots/settings-ai.png)
*(Bild: alla assistentens alternativ finns på en enda AI-sida i Inställningar.)*

## Integritet

- Med Apple Intelligence körs assistenten **på din Mac**; ingenting lämnar enheten.
- En molnmodell används **bara om du ställer in en**, och dess API-nyckel stannar i nyckelringen.
- Åtgärder som ändrar filer bekräftas innan de körs, om du inte medvetet höjer självständighetsnivån.
