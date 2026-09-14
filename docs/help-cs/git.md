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
zásuvný modul, takže jej můžete vypnout nebo odebrat v **Konfigurace ▸ Zásuvné moduly…**.

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
**Zapsat** — s **Opravit** se změna vloží do předchozího zápisu. **Stáhnout** a **Odeslat** leží vedle, tam,
kde se stejně zapisuje; obojí ukazuje postup a lze je přerušit.

Zapisuje se *index*, nikoli `git commit -a`: zapíše se to, co jste připravili.

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

## Ignorování souborů a přihlašovací údaje

- **Ignorovat tento soubor…**, **Ignorovat tento typ souboru…** a **Ignorovat tuto složku…** zapíší správný
  vzor do `.gitignore` — ukotvený tam, kam patří, aby ignorování *této* složky `build` neignorovalo každou
  složku jménem `build`.
- **Přihlašovací údaje…** hlásí, jak se tento repozitář ověřuje: SSH, nebo HTTPS, zda je nastaven pomocník pro
  přihlašovací údaje, zda běží agent SSH a drží klíč. Kde to pomůže, nabídne přesně jednu akci — nechat Git
  uchovávat údaje v klíčence macOS. Zásuvný modul se nikdy neptá na heslo klíče, nezobrazuje je ani neukládá.

## Poznámky

- Zásuvný modul používá systémový Git v `/usr/bin/git`. Pokud Git chybí, příkazy oznámí, že Git není k
  dispozici. (Přinášejí jej Xcode Command Line Tools.)
- Stav repozitáře se čte jednou na složku a ukládá do mezipaměti, aby procházení velkého repozitáře zůstalo
  rychlé; mezipaměť se obnoví po každém příkazu, který změní strom, a sleduje i zápis provedený mimo
  aplikaci.
- Připojené pracovní stromy a podmoduly jsou podporovány: soubor uvnitř podmodulu ukazuje stav a větev
  *podmodulu*, ne nadřazeného repozitáře.
- Každý seznam má místní nabídku, **Return** spustí jeho hlavní akci a **Cmd+R** okno znovu načte.
