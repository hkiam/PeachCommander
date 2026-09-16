---
title: Arbetsytor
slug: workspaces
section: Anpassning
order: 118
related: [settings, panels-and-tabs]
---

En arbetsyta är ett namngivet sammanhang du arbetar i: ”Rensa säkerhetskopior”, ”Sortera ansökningshandlingar”. Var och en minns båda panelerna, alla öppna flikar, vilken flik som är aktiv på varje sida, visningsläget, mappträdet, fram/tillbaka-historiken och vilka filer du hade markerat, snabbfiltret och fönstrets uppställning — sidopanelen, dockan, raderna och var avdelaren sitter. Ett byte kostar ett klick, och på vägen går aldrig något förlorat — en arbetsyta sparas aldrig, eftersom den aldrig tar slut.

Tills du skapar en andra finns det inget att se. Ingen rad, ingen meny, inga kortkommandon.

## Så gör du

1. Ställ in båda panelerna för uppgiften: öppna mapparna, lägg till flikarna, välj den vy du vill ha.
2. Öppna menyn **Gå** och välj **Arbetsytor…**, sedan **Ny arbetsyta…**. Ge den ett namn.
3. Överst i fönstret dyker en rad färgade brickor upp, och i menyraden dyker menyn **Arbetsyta** upp. Den nya arbetsytan börjar som en kopia av den uppställning du befann dig i.
4. Ställ in den nya arbetsytan för sin egen uppgift. Den du kom från behåller det den hade.
5. Klicka på en bricka för att byta, eller tryck **Ctrl+1** till **Ctrl+9**. Allt byter med.

## Tillbaka till ett utgångsläge

Varje arbetsyta minns också den uppställning den sattes upp som. **Arbetsyta ▸ Spara nuvarande läge i arbetsytan** (Cmd+Ctrl+S) gör den nuvarande uppställningen till detta utgångsläge, och **Återställ till sparat läge** för dig dit igen efter en eftermiddag på villovägar.

Detta är skilt från det löpande minnet: du behöver aldrig spara för att inte tappa din plats.

## Samlingen

Varje arbetsyta har en samling — för det som faktiskt händer under en uppstädning: tre mappar ner i
säkerhetskopiorna hittar du något som hör till ett helt annat jobb. **Dra filer till en annan arbetsytas
bricka**, så hamnar de i *dess* samling — du byter inte, och inget kopieras eller flyttas; räknaren på
brickan stiger och du fortsätter. Håll **⌥** när du släpper för att i stället kopiera till den
arbetsytans mapp, eller **⌘** för att flytta. **Ctrl+Cmd+A** lägger markeringen i den nuvarande
arbetsytans samling, sidan **Samlingen** i sidopanelen visar innehållet, och **Arbetsyta ▸ Kopiera
samlingen till den andra panelen** tar hela samlingen i en enda operation.

Filer som raderats sedan dess, eller som ligger på en volym som inte är monterad, visas som saknade i
stället för att tas bort, och en massoperation erbjuder att hoppa över dem eller ta ut dem först. En
flytt tömmer samlingen på det som flyttades; en kopia lämnar den som den var.

| Åtgärd | Kortkommando |
| --- | --- |
| Byt till arbetsyta 1 till 9 | Ctrl+1 … Ctrl+9 |
| Gör nuvarande uppställning till utgångsläget | Cmd+Ctrl+S |

## Tips

- Högerklicka på en bricka för att byta namn på den, ge den en färg eller radera den — eller klicka på **✕** i dess högra kant, som raderar arbetsytan efter en fråga. Färgen är det du skiljer arbetsytorna åt med i ett ögonkast när fönstret är smalt och namnen inte längre får plats.
- Nio är gränsen, så att varje bricka förblir igenkännlig.
- **Visa ▸ Visa arbetsytefältet** döljer raden utan att stänga av funktionen — för den som byter mellan arbetsytor med tangentbordet.
- Arbetsytor kan stängas av helt under **Inställningar ▸ Flikar**. Dina arbetsytor behålls och kommer tillbaka oförändrade när du slår på funktionen igen.

## Att begränsa en arbetsyta till en mapp

En arbetsyta kan få veta vad den handlar om, och kontrollerar sedan innan en åtgärd sträcker sig
utanför. Högerklicka på dess bricka, **Begränsa till mapp ▸ Sätt till den aktiva mappen**, och välj om
åtgärder utanför ska tillåtas, frågas om eller avvisas.

Det kontrolleras innan en radering tar filer utifrån, innan en kopiering eller flytt hamnar utanför, och
innan ett namnbyte eller en ny mapp skriver utanför. **Navigering begränsas aldrig** — en filhanterare
som vägrar visa en mapp är trasig, och värdet ligger helt i ögonblicket före F8. Sparningar i
redigeraren omfattas inte heller; de sker i sitt eget fönster.

## Journalen

Varje arbetsyta för bok över vad som gjorts i den — besökta mappar, utförda åtgärder, skrivna
skalrader, och allt som en mappbegränsning har avvisat. **Arbetsyta ▸ Journal…** visar den, senaste
dagen först, med ett filter **Problem** för allt som misslyckades eller stoppades.

Retur upprepar den valda raden enligt samma regel som historiken: bara en kopiering eller flytt kan
upprepas med ett tangenttryck, och en skalrad fylls in i kommandoraden i stället för att köras.
Journalen är medvetet skild från den globala historiken — den svarar på "var brukar jag vara" och
rangordnar efter frekvens; denna svarar på "vad hände här" och behåller ordningen. Den raderas
tillsammans med sin arbetsyta, bevaras annars utan tidsgräns, och kan stängas av under **Inställningar ▸
Flikar**.

## Att skicka en arbetsyta vidare

**Arbetsyta ▸ Exportera arbetsyta…** skriver den aktuella arbetsytan till en `.pcworkspace`-fil som du
kan skicka till någon eller spara i en projektmapp. **Importera arbetsyta…** läser tillbaka den, och
det gör även ett dubbelklick i Finder.

Det som följer med är arbetsytans **sparade utgångspunkt** — tryck ⌘⌃S först om du vill ha den
uppställning du har framför dig — tillsammans med namn, färg, mappgräns och samling. Mappar inuti din
hemmapp skrivs förkortade, så att filen öppnas i den *andres* hemmapp och inte i en mapp uppkallad
efter dig.

Det som medvetet inte följer med:

- **Allt som skulle kunna vara en inloggningsuppgift.** Flikar som pekar på en anslutning eller en monterad insticksenhet tas bort vid exporten, och rapporten säger hur många. Det finns inget att förlora, eftersom ingenting om en anslutning skrivs ner.
- **Journalen.** Den antecknar vad *du* har gjort och nämner mappar på din dator. Den stannar här.
- Markörpositioner, ångra-historiken, fönsterstorleken samt öppna visnings-, redigerings-, sök- eller synkroniseringsfönster.
- Terminalflikar och samtal med assistenten. De hör till den här Macen; en arbetsytefil bär *var* det arbetas, inte vad som är igång.

En import **lägger** alltid till en arbetsyta; den ersätter aldrig den du står i och växlar aldrig av
sig själv — en fil som någon skickat ska inte flytta ditt fönster. Mappar som inte finns på den här
Macen öppnas på den närmaste som finns, poster i samlingen behåller sina sökvägar och visas
nedtonade, och en mappgräns vars mapp saknas behålls men frågar i stället för att vägra. En rapport
räknar upp allt detta.

## Anmärkningar

- Ett byte frågar aldrig om något ska sparas och stänger aldrig något. Pågående filoperationer fortsätter, och likaså allt i en terminal: flikarna i arbetsytan du lämnar läggs undan med levande skal, inte stängs. Assistentens samtal följer också arbetsytan.
- Ångra följer en arbetsyta bara så länge appen körs: ett ångra-steg bär den åtgärd som vänder det, och den kan inte skrivas till disk.
- En arbetsyta minns mappplatser, inte filerna i dem. Har en sparad mapp flyttats eller raderats öppnas den fliken i den närmaste mapp som fortfarande finns.
- Vid uppgradering från en tidigare version: arbetsytor du sparat tidigare blir brickor, och sessionen du var i blir den första. Inget går förlorat, och den gamla `workspaces.ini` behålls som `workspaces.ini.migrated`.
