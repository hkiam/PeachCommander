---
title: Git
slug: git
section: Insticksprogram
order: 123
related: [plugins, view-modes-and-sorting]
---

Git-insticksprogrammet visar tillståndet i ett Git-arkiv direkt i filpanelen — ingen separat app, ingen
terminal. Det lägger till två kolumner, en undermeny **Git**, en dockad panel för att köa och checka in, och
fönster för historik, blame, grenar, konflikter och ombasering. Det använder den `git` som redan är
installerad på din Mac. Det är ett insticksprogram, så du kan stänga av det eller ta bort det under
**Konfiguration ▸ Hantera plugin-program…**.

## Vad det lägger till

- **Två kolumner i fillistan** — *Git-status* och *Gren*. Varje fil visar en ikon och ett kort statusord
  (Ändrad, Tillagd, Borttagen, Ospårad, Omdöpt, Kopierad, Konflikt, Ignorerad, Typ ändrad), med *(köad)* när
  ändringen redan ligger i indexet; kolumnen *Gren* visar den gren som filens arkiv står på. Slå på
  kolumnerna under **Konfiguration ▸ Kolumner…** (se
  [Visningslägen och sortering](view-modes-and-sorting.md)).
- **En Git-meny** — under **Kommandon ▸ Git**, och i en fils högerklicksmeny.

![Fönstret Git-status med aktuell gren och de ändrade filerna i arkivet](screenshots/git-status.png)
*(Figur: Git-status anger grenen och varje ändring i arbetsträdet.)*

## Panelen: köa, checka in, synkronisera

**Kommandon ▸ Git ▸ Panel** dockar en vy som grupperar arbetsträdet i *köad*, *ändrad* och *ospårad*. Välj
filer och använd **Köa**, **Avköa** eller **Kasta…**, skriv ett meddelande och tryck på **Checka in** — med
**Amend** viks ändringen i stället in i föregående incheckning. **Fetch**, **Pull** och **Push** ligger bredvid, där
incheckningen ändå sker; alla tre visar förlopp och kan avbrytas.

Det är *indexet* som checkas in, inte `git commit -a`: det du har köat är det som checkas in.

## Historik i panelen

Under knapparna visar panelen historiken för alla grenar, fjärrgrenar och taggar som en ritad graf, med arbetskopian som första rad. Området nedanför följer markeringen:

![Git-panelen med grengrafen, vald merge-commit och den ändrade filen med inbäddad diff](screenshots/git-panel.png)

- **Lokala ändringar** visar köade, ändrade och ospårade filer och commit-rutan som beskrivs ovan.
- En commit visar antingen **Commit** — författare, committer, datum, hash, föräldrar, refs, signatur och hela meddelandet — eller **Ändringar**.
- **Ändringar** visar berörda filer som ett träd och diffen för vald fil med radnummer; ett dubbelklick öppnar jämförelsefönstret.
- Snabbmenyn kopierar hash eller ämne, återställer, cherry-pickar, öppnar commiten på webben och begränsar listan till **Endast aktuell gren**.
- Från samma meny kan en commit checkas ut, få en ny gren eller tagg, slås samman in i aktuell gren, få aktuell gren rebasad på sig eller återställd till sig, eller starta en interaktiv rebase.
- Sökfältet ovanför listan söker i hela historiken — meddelande, författarens namn och e-post eller en hash och dess första tecken — och visar träffarna utan grafen.

## Mer i panelen och i Git-menyn

Arbetskopian, historiken och menyn **Kommandon ▸ Git** erbjuder mer än att checka in:

- En markerad köad eller ändrad fil visar sin diff under listan; markerade rader eller en hel hunk köas, avköas eller kastas från dess snabbmeny.
- Commitfältet tar flera rader — ett ämne, en tom rad, en brödtext —, gör commit med **Cmd+Retur** och räknar ämnets tecken; menyknappen bredvid håller dina senaste commitmeddelanden.
- **Visa i vänster panel** och **Visa i höger panel** för en filpanel till en fil från listan eller från en commits ändringar, medan Git-panelen förblir som den är; filer som Git LFS lagrar är märkta **LFS**.
- Stashar visas i historiken som små kvadrater ovanför den commit de gjordes på, med **Tillämpa stash**, **Tillämpa och ta bort stash** och **Ta bort stash…** i snabbmenyn.
- **Reflog…** listar varje förflyttning av HEAD; en commit som gick förlorad vid en återställning eller en borttagen gren kommer tillbaka med **Ny gren här…**.
- **Repository-inställningar…** lägger till, byter namn på, pekar om och tar bort fjärrar, lägger till, uppdaterar och tar bort undermoduler, hanterar worktrees och ger enbart detta repository ett namn och en e-postadress för commits.
- **Skapa repository här…** och **Klona repository…** arbetar i den aktiva panelens mapp, och klockan bredvid panelens titel går tillbaka till ett nyligen använt repository.

## När git stannar, och inställningarna

- **Push** anger uppströmsgrenen första gången en gren pushas. Har fjärren commits som den här grenen saknar, erbjuder den **Hämta, sedan pusha** eller **Tvinga push**, alltid med en lease som vägrar om någon har pushat sedan din senaste fetch; **Tvinga push (med lease)…** finns också i snabbmenyn för **Push**.
- Märker **Pull** att grenen och dess uppströmsgren har gått isär, frågar den om den ska slå ihop eller göra rebase i stället för att stanna vid gits meddelande.
- En sammanslagning, cherry-pick, revert, rebase eller patchserie som stannar i en konflikt visar en banderoll ovanför historiken med **Fortsätt** och **Avbryt…**; en sammanslagningscommit återställs eller cherry-pickas mot sin första förälder.
- Markera två commits för att jämföra dem, eller flera för att cherry-picka dem på en gång. **Jämför med arbetskopian** och **Spara som patch…** finns i historikens meny, **Tillämpa patchar…** i Git-menyn.
- Sökfältet tar också filter — `author:name`, `path:folder/`, `since:"2 weeks ago"`, `until:2026-10-01` — ensamma eller tillsammans med ord.
- **Bisect: markera som dålig** och **Bisect: markera som bra** i historikens meny startar en bisect; banderollen erbjuder sedan **Bra**, **Dålig**, **Hoppa över** och **Avsluta bisect** tills git nämner den första dåliga commiten.
- Att stasha valda filer eller alla ändringar frågar efter ett meddelande och om ospårade filer ska med eller indexet ska vara kvar. Filer i Git LFS kan låsas och låsas upp, och deras filtyp spåras.
- I grenlistan kan en gren byta namn (**Byt namn…**), få en uppströmsgren (**Ange uppströmsgren…**) eller tas bort på sin server (**Ta bort på fjärren…**).
- **Inställningar ▸ Git** bestämmer git-programmet, ditt globala namn och din e-post, hur **Pull** arbetar, fetch i bakgrunden, vad historiken visar och hur dess datum ser ut, signering, sign-off och hooks för commits samt blanksteg och kontextrader för diffar. Författare har färgade initialer i historiken.

## Filer, sammanfogning, Git flow och pull requests

- **Filer** bredvid Commit och Ändringar visar hela trädet vid vald commit; en fil öppnas med radnummer, och dess meny jämför den med arbetskopian, sparar den någon annanstans eller lägger tillbaka den i arbetskopian (**Återställ den här versionen…**).
- **Sammanfogningsredigerare…** — på en fil med konflikt i panelen, i banderollen, i **Lös konflikt…** och i Git-menyn — visar aktuell konflikt som vår, bas och deras sida vid sida och hela filen under, redigerbar. **Ta våra**, **Ta deras**, båda i valfri ordning eller **Ta basen** avgör en konflikt, och **Spara och köa** markerar filen som löst när inga markörer är kvar.
- Grensymbolen i panelens rubrik är menyn **Git flow**: **Starta funktion…**, **Starta release…** och **Starta snabbfix…** skapar grenen från develop eller main, och **Avsluta …** sammanfogar den tillbaka — en release eller snabbfix i main med en tagg, sedan i develop. Att avsluta igen efter en konflikt fortsätter där det stannade.
- **Pull requests…** i Git-menyn listar öppna pull requests (merge requests hos GitLab) och ärenden i projektet som fjärrarna pekar på, med kontrollerna för var och en; den checkar ut en pull request i en egen gren och öppnar en ny för aktuell gren.
- Det krävs en personlig åtkomsttoken, som anges i fönstret och förvaras i nyckelringen; token skickas bara till tjänstens API. Med en token visar en symbol bredvid grenen i panelens rubrik om CI gick igenom för aktuell commit.
- **Inställningar ▸ Git** namnger Git flow-grenar och -prefix och, under **Värdtjänst**, egna GitLab- eller GitHub Enterprise-servrar.

## Historik, blame och webben

- **Historik…** listar incheckningarna med en filgraf, referenserna som pekar på var och en (`● main`,
  `↗ origin/main`, `⚑ v1.0`), och filerna varje incheckning rört. Retur eller ett dubbelklick öppnar filens
  version mot sin föregångare i jämförelsefönstret. **Ångra incheckning** och **Cherry-pick** finns där, och
  båda vägrar i förväg om arbetsträdet inte är rent.
- **Filhistorik…** är samma fönster för en enda fil.
- **Blame (lista)…** visar varje rad med incheckning, författare och datum. **Blame i redigeraren** skriver
  samma information i redigerarens marginal, bredvid radnumren: peka på en rad för incheckningens meddelande,
  klicka för att öppna den mot sin föregångare.
- **Öppna på webben** öppnar filen, incheckningen eller grenen på GitHub, GitLab, Bitbucket eller Azure
  DevOps, byggd ur fjärrarkivets URL — inget konto, ingen token. För en värd vars länkform det inte känner
  till erbjuder det arkivsidan i stället för att gissa.

## Grenar, stashar och taggar

**Grenar, stashar och taggar…** listar alla tre. Byta, skapa, sammanfoga eller ta bort en gren; pusha, poppa
eller kasta en stash; skapa, ta bort eller pusha en tagg, eller byta till den — en tagg är ingen gren, så det
sägs i förväg att HEAD hamnar frikopplat. Fetch, Pull och Push finns i samma fönster och kan avbrytas medan de
körs.

Att pusha en tagg är avsiktligt en egen åtgärd: `git push` tar inte med taggar.

## Konflikter

**Lös konflikt…** listar de konfliktdrabbade områdena i filen under markören och fattar ett beslut för vart
och ett: *våra*, *deras*, *båda* — eller lämna öppet. Sedan **Skriv fil** eller **Skriv och köa**. Det vägrar
köa så länge ett område står öppet — Git checkar glatt in `<<<<<<<`-markörer — och det rör inte en fil vars
markörer det inte kan läsa i stället för att gissa sig till dem. För ett område där båda sidor måste vävas
samman för hand är **Öppna i redigeraren** en knapp bort.

## Ombasering

**Ombasera…** listar incheckningarna som ligger före uppströms — de som ingen annan har ännu — och låter dig
squasha, lägga till som fixup, kasta, ordna om eller formulera om dem innan grenen skrivs om. Stannar en
ombasering i en konflikt blir samma fönster **Fortsätt** / **Hoppa över incheckning** / **Avbryt ombasering**,
så att en halvfärdig ombasering inte måste avslutas i en terminal.

## Ändra commit-meddelanden i efterhand

- **Redigera meddelande…** i historikens meny öppnar en commits meddelande för redigering; med flera commits markerade heter det **Redigera meddelanden…**, och **Sök och ersätt i meddelanden…** — också **Redigera commit-meddelanden…** i Git-menyn — söker i meddelandena på den aktuella grenen, i de commits som inte pushats än eller på alla grenar och taggar.
- Listan visar de commits vars meddelande ändras. Den markerades meddelande visas som det är, med träffarna markerade, och som det kommer att bli, och där går det också att skriva; **Lämna som det är** tar ut en commit igen.
- **Sök hemligheter…** söker efter tokens, nycklar och lösenord i de listade meddelandena och fyller i sökningen efter dem; **Maskera** sätter in `***REDACTED***` som ersättning.
- **Verkställ…** frågar först: den listar varje ändring, hur många commits som får nya hashar och vilka grenar och taggar som flyttas, och varnar för commits som redan har pushats. Commits skrivs direkt, så inget checkas ut och inget kan hamna i konflikt; filer, författare och datum förblir som de var. En signatur tas bort, eller görs på nytt när **Signera commits** är på i **Inställningar ▸ Git**.
- De gamla commits behålls: **Ångra** sätter tillbaka grenarna så länge ingen av dem har flyttats sedan dess. En gren som redan har pushats ersätts på sitt fjärrarkiv med **Tvinga push…**, med en lease.
- För en hemlighet raderar **Ta bort gamla commits…** säkerhetskopian och de reflog-poster som inget når längre, rensar och säger sedan om någon gammal commit finns kvar. Commits som pushats kan fortfarande nås på servern och i andra kloner, så en hemlighet som pushats måste också återkallas.

## Att ignorera filer, och inloggningsuppgifter

- **Ignorera den här filen…**, **Ignorera den här filtypen…** och **Ignorera den här mappen…** skriver rätt
  mönster i `.gitignore` — förankrat där det hör hemma, så att *den här* `build`-mappen ignoreras och inte
  varje mapp som heter `build`.
- **Inloggningsuppgifter…** berättar hur det här arkivet autentiserar sig: SSH eller HTTPS, om en credential
  helper är uppsatt, om en SSH-agent kör och håller en nyckel. Där det hjälper erbjuder det exakt en åtgärd —
  låta Git förvara uppgifterna i macOS nyckelring. Insticksprogrammet frågar aldrig efter en lösenordsfras,
  visar den inte och sparar den inte.

## Anmärkningar

- Insticksprogrammet använder systemets Git i `/usr/bin/git` eller programmet som valts i **Inställningar ▸ Git**. Saknas Git meddelar kommandona att Git inte är tillgängligt. (Xcode Command Line Tools innehåller det.)
- Arkivets status läses en gång per mapp och cachas, så att bläddra i ett stort arkiv förblir snabbt; cachen
  förnyas efter varje kommando som ändrar trädet, och följer även en incheckning som gjorts utanför
  programmet.
- Länkade arbetsträd och undermoduler stöds: en fil i en undermodul visar *undermodulens* status och gren,
  inte det överordnade arkivets.
- Varje lista har en kontextmeny, **Retur** kör dess huvudåtgärd och **Cmd+R** laddar om fönstret.
- Git LFS, `gpg` för signerade commits och credential-hjälpare hittas i Homebrews och MacPorts mappar, även när appen öppnades från Finder.
