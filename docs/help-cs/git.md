---
title: Git
slug: git
section: Zásuvné moduly
order: 123
related: [plugins, view-modes-and-sorting]
---

Zásuvný modul Git ukazuje stav repozitáře Git přímo v panelu souborů — bez samostatné aplikace a bez
terminálu. Přidává dva sloupce, podnabídku **Git**, ukotvený panel pro přípravu a zápis změn a okna pro
historii, blame, větve, konflikty a přeskládání. Používá `git`, který je na vašem Macu už nainstalovaný. Je to
zásuvný modul, takže jej můžete vypnout nebo odebrat v **Konfigurace ▸ Spravovat zásuvné moduly…**.

## Co přidává

- **Dva sloupce seznamu souborů** — *Stav Gitu* a *Větev*. Každý soubor ukazuje ikonu a krátké slovo stavu
  (Změněno, Přidáno, Smazáno, Nesledováno, Přejmenováno, Zkopírováno, Konflikt, Ignorováno, Změněn typ), s
  *(připraveno)*, když je změna už v indexu; sloupec *Větev* ukazuje větev, na které stojí repozitář daného
  souboru. Sloupce zapnete v **Konfigurace ▸ Sloupce…** (viz
  [Režimy zobrazení a řazení](view-modes-and-sorting.md)).
- **Nabídka Git** — v **Příkazy ▸ Git** a v místní nabídce souboru.

![Okno Stav Gitu s aktuální větví a změněnými soubory v repozitáři](screenshots/git-status.png)
*(Obrázek: Stav Gitu uvádí větev a každou změnu v pracovním stromu.)*

## Panel: připravit, zapsat, synchronizovat

**Příkazy ▸ Git ▸ Panel** ukotví pohled, který dělí pracovní strom na *připravené*, *změněné* a *nesledované*.
Vyberte soubory a použijte **Připravit**, **Zrušit přípravu** nebo **Zahodit…**, napište zprávu a stiskněte
**Zapsat** — s **Opravit** se změna vloží do předchozího zápisu. **Fetch**, **Stáhnout** a **Odeslat** leží vedle, tam,
kde se stejně zapisuje; všechny tři ukazují postup a lze je přerušit.

Zapisuje se *index*, nikoli `git commit -a`: zapíše se to, co jste připravili.

## Historie v panelu

Pod tlačítky panel ukazuje historii všech větví, vzdálených větví a tagů jako kreslený graf, s pracovní kopií v prvním řádku. Oblast pod ním sleduje výběr:

![Panel Git s grafem větví, vybraným merge commitem a jeho změněným souborem s vloženým diffem](screenshots/git-panel.png)

- **Místní změny** ukazuje připravené, změněné a nesledované soubory a pole pro commit popsané výše.
- Commit ukazuje buď **Commit** — autora, committera, datum, hash, rodiče, refy, podpis a celou zprávu — nebo **Změny**.
- **Změny** vypíše dotčené soubory jako strom a diff vybraného souboru s čísly řádků; dvojklik otevře okno porovnání.
- Kontextová nabídka kopíruje hash nebo předmět, vrací, dělá cherry-pick, otevírá commit na webu a omezuje seznam na **Jen aktuální větev**.
- Ze stejné nabídky lze commit přepnout, dát mu novou větev nebo tag, sloučit ho do aktuální větve, přenést na něj aktuální větev nebo ji na něj resetovat, nebo od něj spustit interaktivní rebase.
- Vyhledávací pole nad seznamem prohledá celou historii — zprávu, jméno a e-mail autora nebo hash a jeho první znaky — a vypíše výsledky bez grafu.

## Více v panelu a v nabídce Git

Pracovní kopie, historie a nabídka **Příkazy ▸ Git** nabízejí víc než zápis:

- Vybraný připravený nebo změněný soubor ukáže pod seznamem svůj diff; vybrané řádky nebo celý blok lze z jeho kontextové nabídky připravit, vrátit z přípravy nebo zahodit.
- Pole commitu přijímá více řádků — předmět, prázdný řádek, text —, commituje přes **Cmd+Return** a počítá znaky předmětu; tlačítko nabídky vedle drží tvé poslední zprávy commitů.
- **Zobrazit v levém panelu** a **Zobrazit v pravém panelu** přenesou souborový panel na soubor ze seznamu nebo ze změn commitu, zatímco panel Git zůstane, jak je; soubory uložené Git LFS jsou označeny **LFS**.
- Stashe se v historii zobrazují jako malé čtverce nad commitem, na kterém vznikly, s **Použít stash**, **Použít a odebrat stash** a **Smazat stash…** v kontextové nabídce.
- **Reflog…** vypíše každý posun HEAD; commit ztracený resetem nebo smazanou větví se vrátí přes **Nová větev zde…**.
- **Nastavení repozitáře…** přidává, přejmenovává, přesměrovává a odebírá vzdálené repozitáře, přidává, aktualizuje a odebírá submoduly, spravuje worktree a dává jen tomuto repozitáři jméno a e-mail pro commity.
- **Vytvořit repozitář zde…** a **Klonovat repozitář…** pracují ve složce aktivního panelu a hodiny vedle názvu panelu vedou zpět k nedávnému repozitáři.

## Když se git zastaví, a nastavení

- **Push** při prvním odeslání větve nastaví upstream. Má-li vzdálený repozitář commity, které této větvi chybí, nabídne **Stáhnout, pak odeslat** nebo **Vynutit odeslání** — vždy s lease, který odmítne, pokud někdo od tvého posledního fetch odeslal; **Vynutit odeslání (s lease)…** je i v kontextové nabídce tlačítka **Push**.
- Zjistí-li **Pull**, že se větev a její upstream rozešly, zeptá se, zda sloučit, nebo rebasovat, místo aby skončil u zprávy gitu.
- Sloučení, cherry-pick, revert, rebase nebo série patchů, které se zastaví v konfliktu, ukážou nad historií pruh s **Pokračovat** a **Přerušit…**; slučovací commit se vrací nebo cherry-pickuje vůči svému prvnímu rodiči.
- Vyber dva commity a porovnej je, nebo několik a cherry-pickni je najednou. **Porovnat s pracovní kopií** a **Uložit jako patch…** jsou v nabídce historie, **Použít patche…** v nabídce Git.
- Pole hledání přijímá i filtry — `author:name`, `path:folder/`, `since:"2 weeks ago"`, `until:2026-10-01` — samotné nebo spolu se slovy.
- **Bisect: označit jako špatný** a **Bisect: označit jako dobrý** v nabídce historie spustí bisect; pruh pak nabízí **Dobrý**, **Špatný**, **Přeskočit** a **Ukončit bisect**, dokud git nenajde první špatný commit.
- Odložení vybraných souborů nebo všech změn do stashe se zeptá na zprávu a na to, zda zahrnout nesledované soubory nebo ponechat index. Soubory v Git LFS lze zamknout a odemknout a jejich typ souboru sledovat.
- V seznamu větví lze větev přejmenovat (**Přejmenovat…**), dát jí upstream (**Nastavit upstream…**) nebo ji smazat na jejím serveru (**Smazat na vzdáleném repozitáři…**).
- **Nastavení ▸ Git** určuje program git, tvé globální jméno a e-mail, jak pracuje **Pull**, fetch na pozadí, co ukazuje historie a jak vypadají její data, podepisování, sign-off a hooky commitů a mezery a řádky kontextu v diffech. Autoři mají v historii barevné iniciály.

## Soubory, slučování, Git flow a pull requesty

- **Soubory** vedle Commit a Změny ukazují celý strom ve vybraném commitu; soubor se otevře s čísly řádků a jeho nabídka ho porovná s pracovní kopií, uloží jinam nebo vrátí do pracovní kopie (**Obnovit tuto verzi…**).
- **Editor sloučení…** — u souboru s konfliktem v panelu, v pruhu, ve **Vyřešit konflikt…** a v nabídce Git — ukazuje aktuální konflikt jako naše, základ a jejich vedle sebe a pod nimi celý soubor k úpravám. **Vzít naše**, **Vzít jejich**, obojí v libovolném pořadí nebo **Vzít základ** rozhodne konflikt a **Uložit a přidat** označí soubor jako vyřešený, jakmile nezbývají žádné značky.
- Symbol větve v záhlaví panelu je nabídka **Git flow**: **Začít funkci…**, **Začít vydání…** a **Začít hotfix…** vytvoří větev z develop nebo main a **Dokončit …** ji sloučí zpět — vydání nebo hotfix do main s tagem, pak do develop. Opětovné dokončení po konfliktu pokračuje tam, kde se zastavilo.
- **Pull requesty…** v nabídce Git vypíší otevřené pull requesty (merge requesty u GitLabu) a issues projektu, na který ukazují vzdálené repozitáře, s kontrolami každého; přepnou pull request do vlastní větve a otevřou nový pro aktuální větev.
- Potřebují osobní přístupový token, zadaný v tom okně a uložený v klíčence; token se posílá jen do API služby. S tokenem ukazuje symbol vedle větve v záhlaví panelu, zda CI pro aktuální commit prošlo.
- **Nastavení ▸ Git** pojmenuje větve a předpony Git flow a v části **Hosting** vlastní servery GitLab nebo GitHub Enterprise.

## Historie, blame a web

- **Historie…** vypisuje zápisy s pruhovým grafem, odkazy, které na ně míří (`● main`, `↗ origin/main`,
  `⚑ v1.0`), a soubory, kterých se každý zápis dotkl. Return nebo dvojklik otevře verzi toho souboru proti
  jeho předchůdci v okně porovnání. **Vrátit zápis** a **Cherry-pick** jsou tam také a oba předem odmítnou,
  pokud pracovní strom není čistý.
- **Historie souboru…** je totéž okno pro jeden soubor.
- **Blame (seznam)…** ukazuje každý řádek s jeho zápisem, autorem a datem. **Blame v editoru** píše tutéž
  informaci na okraj editoru, vedle čísel řádků: ukázání na řádek zobrazí zprávu zápisu, klepnutí jej otevře
  proti jeho předchůdci.
- **Otevřít na webu** otevře soubor, zápis nebo větev na GitHubu, GitLabu, Bitbucketu či Azure DevOps,
  sestaveno z URL vzdáleného repozitáře — bez účtu, bez tokenu. U serveru, jehož podobu odkazů nezná, nabídne
  stránku repozitáře, místo aby hádal.

## Větve, odložené změny a značky

**Větve, odložené změny a značky…** vypisuje všechny tři. Přepnout, založit, sloučit nebo smazat větev;
odeslat, vyzvednout nebo zahodit odložené změny; založit, smazat či odeslat značku nebo na ni přepnout —
značka není větev, a tak se předem řekne, že HEAD skončí odpojený. Načtení, Stáhnout a Odeslat jsou ve stejném
okně a lze je přerušit za běhu.

Odeslat značku je záměrně samostatná akce: `git push` značky s sebou nebere.

## Konflikty

**Vyřešit konflikt…** vypisuje konfliktní oblasti souboru pod kurzorem a pro každou přijme rozhodnutí: *naše*,
*jejich*, *obojí* — nebo ji nechat otevřenou. Pak **Zapsat soubor** nebo **Zapsat a připravit**. Odmítá
připravit, dokud je některá oblast otevřená — Git značky `<<<<<<<` zapíše bez mrknutí oka — a raději se
nedotkne souboru, jehož značky neumí přečíst, než aby je hádal. Pro oblast, kterou je třeba proplést ručně z
obou stran, je **Otevřít v editoru** jedno tlačítko daleko.

## Přeskládání

**Přeskládat…** vypisuje zápisy před proti proudu — ty, které ještě nikdo jiný nemá — a nechá vás je sloučit,
připojit jako opravu, zahodit, přeskládat nebo přepsat jejich zprávu, než se větev přepíše. Zastaví-li se
přeskládání na konfliktu, stane se z téhož okna **Pokračovat** / **Přeskočit zápis** / **Přerušit
přeskládání**, aby se rozdělané přeskládání nemuselo dokončovat v terminálu.

## Dodatečná změna zpráv commitů

- **Upravit zprávu…** v nabídce historie otevře zprávu jednoho commitu k úpravě; při více vybraných commitech je to **Upravit zprávy…** a **Najít a nahradit ve zprávách…** — také **Upravit zprávy commitů…** v nabídce Git — prohledá zprávy aktuální větve, dosud neodeslaných commitů nebo všech větví a tagů.
- Seznam ukazuje commity, jejichž zpráva se změní. Zpráva vybraného je zobrazena tak, jak je, s vyznačenými shodami, a tak, jak bude, a do té lze psát; **Nechat, jak je** commit zase vyřadí.
- **Najít tajemství…** hledá tokeny, klíče a hesla ve zprávách v seznamu a vyplní je do hledání; **Začernit** vloží `***REDACTED***` jako náhradu.
- **Použít…** se nejprve zeptá: vypíše každou změnu, kolik commitů dostane nové hashe a které větve a tagy se posunou, a varuje před commity, které už byly odeslány. Commity se zapisují přímo, takže se nic nepřepíná a nic nemůže být v konfliktu; soubory, autoři a data zůstanou, jak byly. Podpis zmizí, nebo se vytvoří znovu, když je v **Nastavení ▸ Git** zapnuto **Podepisovat commity**.
- Staré commity se uchovají: **Zpět** vrátí větve, dokud se od té doby žádná z nich neposunula. Větev, která už byla odeslána, se na svém remote nahradí pomocí **Vynutit odeslání…**, s lease.
- U tajemství **Odstranit staré commity…** smaže zálohu a záznamy reflogu, na které už nic nedosáhne, provede prune a pak řekne, zda tu ještě nějaký starý commit je. Odeslané commity mohou být stále dosažitelné na serveru a v jiných klonech, takže odeslané tajemství je navíc třeba zneplatnit.

## Ignorování souborů a přihlašovací údaje

- **Ignorovat tento soubor…**, **Ignorovat tento typ souboru…** a **Ignorovat tuto složku…** zapíší správný
  vzor do `.gitignore` — ukotvený tam, kam patří, aby ignorování *této* složky `build` neignorovalo každou
  složku jménem `build`.
- **Přihlašovací údaje…** hlásí, jak se tento repozitář ověřuje: SSH, nebo HTTPS, zda je nastaven pomocník pro
  přihlašovací údaje, zda běží agent SSH a drží klíč. Kde to pomůže, nabídne přesně jednu akci — nechat Git
  uchovávat údaje v klíčence macOS. Zásuvný modul se nikdy neptá na heslo klíče, nezobrazuje je ani neukládá.

## Poznámky

- Zásuvný modul používá systémový Git v `/usr/bin/git` nebo program zvolený v **Nastavení ▸ Git**. Pokud Git chybí, příkazy oznámí, že Git není k dispozici. (Dodávají ho Xcode Command Line Tools.)
- Stav repozitáře se čte jednou na složku a ukládá do mezipaměti, aby procházení velkého repozitáře zůstalo
  rychlé; mezipaměť se obnoví po každém příkazu, který změní strom, a sleduje i zápis provedený mimo
  aplikaci.
- Připojené pracovní stromy a podmoduly jsou podporovány: soubor uvnitř podmodulu ukazuje stav a větev
  *podmodulu*, ne nadřazeného repozitáře.
- Každý seznam má místní nabídku, **Return** spustí jeho hlavní akci a **Cmd+R** okno znovu načte.
- Git LFS, `gpg` pro podepsané commity a pomocníci pro přihlašovací údaje se najdou ve složkách Homebrew a MacPorts, i když byla aplikace otevřena z Finderu.
