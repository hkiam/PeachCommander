---
title: Avtomatizacija (AppleScript in Bližnjice)
slug: automation
section: Napredna orodja
order: 98
related: [start-menu, settings, macros]
---

Avtomatizacija tu deluje v obe smeri.

**Navzven:** Peach Commander je skriptljiv, zato ga lahko vodite iz AppleScripta in iz aplikacije Bližnjice. Nekaj osnovnih glagolov omogoča skriptu, da se giblje po pultih, izbira datoteke po maski, kopira ali premika trenutni izbor in zaganja katerikoli ukaz Peach Commanderja po njegovem id-ju — z natanko istimi dejanji, kot jih uporabljajo meniji, tako da se skriptni korak obnaša kot ročni. O tem govori preostanek te strani.

**Navznoter:** Peach Commander lahko tudi *zažene* vaš skript — AppleScript ali JavaScript — in ga postavi v meni, na gumb ali na tipko. Za to je potreben vstavek **Scripting**, ki je dobavljen izklopljen; glejte [Zaganjanje lastnih skriptov](#zaganjanje-lastnih-skriptov) spodaj.

Za ponavljanje *zaporedja* dejanj z datotekami namesto enega glejte [Makri](macros.md).

## Ogled slovarja

1. Odprite **Urejevalnik skriptov** (v `/Applications/Utilities` — »Pripomočki« v Finderju).
2. Izberite **Okno ▸ Knjižnica**, nato dvakrat kliknite **Peach Commander** (dodajte ga z **+**, če ni na seznamu).
3. Slovar se odpre in našteje ukaze in lastnosti spodaj.

Ko skript prvič upravlja Peach Commander, macOS zaprosi za dovoljenje (**Sistemske nastavitve ▸ Zasebnost in varnost ▸ Avtomatizacija**). Odobrite ga enkrat in kasnejši skripti se izvajajo brez vprašanja.

## Kaj lahko preberete

| Lastnost | Pomen |
| --- | --- |
| `active folder` | Pot POSIX mape dejavnega podokna. |
| `inactive folder` | Pot POSIX mape drugega podokna. |
| `selection paths` | Izbrani elementi v dejavnem podoknu (ali element pod kazalko). |

## Glagoli

| Ukaz | Kaj naredi |
| --- | --- |
| `go to "<pot>" [in left\|right]` | Odpri mapo v podoknu (privzeto: dejavno podokno). |
| `select "<maska>"` | Izberi elemente v dejavnem podoknu po maski z nadomestnimi znaki, npr. `*.pdf`. |
| `copy items to "<mapa>"` | Kopiraj izbor dejavnega podokna v mapo. |
| `move items to "<mapa>"` | Premakni izbor dejavnega podokna v mapo. |
| `run command "<id>"` | Zaženi kateri koli ukaz po njegovem identifikatorju, npr. `cm_PackFiles`. |

Kopiranje in premikanje uporabljata isto vrsto prenosa v ozadju kot F5/F6, tako da se napredek in morebitni pozivi za prepis prikažejo natanko tako kot pri ročnem opravilu.

## Primer

```applescript
tell application "Peach Commander"
    go to "~/Downloads" in left
    select "*.pdf"
    copy items to "~/Documents/PDFs"
    return selection paths
end tell
```

## Uporaba iz Bližnjic

V aplikaciji **Bližnjice** dodajte dejanje **Zaženi AppleScript** in prilepite skript, kot je zgornji. To vam omogoča vključitev koraka Peach Commander v večjo Bližnjico — na primer sproženo s spremembo mape ali tipko za bližnjico.

## Zaganjanje lastnih skriptov

Druga smer: vaš skript, ki ga zaganja Peach Commander.

To je vstavek in je dobavljen **izklopljen**, ker zagon programa po vaši izbiri zmore vse, kar zmore preostanek aplikacije, in več stvari, ki jih nič od tega ne pokriva. Dva stikala, obe izklopljeni, dokler jih ne nastavite:

1. **Nastavitve ▸ Vstavki…** — vklopite **Scripting**.
2. **Možnosti ▸ UI** — vklopite **Dovoli izvajanje skriptov**. Na tej strani je zato, ker gre za enako vrsto dovoljenja kot pri lupini pomočnika, in oboje sodi skupaj.

Nato postavite skript v `scripts/` znotraj svoje nastavitvene mape — **Ukazi ▸ Odpri mapo skriptov** vas pripelje tja in prvič tam pusti primer. Datoteka `.applescript`, `.scpt` ali `.jxa` v tej mapi *je* skript; ni ničesar za prijaviti.

### Kaj skript dobi

Stanje pultov pride v okolju, tako da običajni primer ne potrebuje dogodkov Apple in nobenega vprašanja o dovoljenju:

| Spremenljivka | Pomeni |
| --- | --- |
| `PC_ACTIVE_DIR` | Mapa aktivnega pulta |
| `PC_TARGET_DIR` | Mapa drugega pulta |
| `PC_CURSOR_NAME` | Datoteka pod kazalcem |
| `PC_SELECTION_COUNT` | Koliko elementov je izbranih |
| `PC_SELECTION_FILE` | Besedilna datoteka z eno izbrano potjo na vrstico (manjka, ko ni izbrano nič) |

```applescript
set here to system attribute "PC_ACTIVE_DIR"
return "The active panel is showing " & here
```

Vse čez to gre skozi aplikacijo samo, z glagoli zgoraj — polovici se torej dopolnjujeta.

### Postavitev skripta na gumb ali tipko

Vsak skript postane ukaz z imenom `plugin.script.run.<ime>`, kjer je `<ime>` ime datoteke brez končnice (presledki in pike se spremenijo v vezaje). Ta id deluje vsepovsod, kjer deluje id `cm_*`: v vrstici z gumbi, v `usercmd.ini`, v datoteki `.mnu` in v **Nastavitve ▸ Uredi bližnjice…**.

### Kako se skript zaganja in časovna omejitev

Privzeto se skript zaganja kot ločen proces, kar pomeni, da mu je mogoče dati časovno omejitev in ga ustaviti, če jo preseže — trideset sekund, če ne rečete drugače. Skript se lahko odloči, da teče *znotraj* aplikacije, kar mu omogoči vrnitev strukturirane vrednosti in ga med zagoni ohrani prevedenega, a takrat ni časovne omejitve: skript, ki se zacikla, zadrži aplikacijo. Izbiro navedite v `scripts.json` ob svojih skriptih:

```json
[
  { "id": "Tidy", "fileName": "Tidy.applescript", "title": "Tidy Downloads",
    "language": "AppleScript", "mode": "subprocess", "timeoutSeconds": 60 }
]
```

Vnos potrebuje le tisto, kar se razlikuje od privzetih vrednosti; datoteka brez vnosa dobi svoje ime kot naslov, teče kot ločen proces in se po tridesetih sekundah ustavi.

### Za pomočnika

Z vklopljenim vstavkom in omogočeno nastavitvijo pomočnik dobi `run_applescript`, `run_jxa` in `check_script`. Vsak vam pokaže natančen skript in počaka na vašo odobritev, preden se kar koli zažene, in nobeden ni nikoli na voljo zunanjemu agentu prek MCP.

## Opombe

- Identifikator ukaza, ki ga posredujete v `run command`, je isti identifikator `cm_*`, prikazan v brskalniku ukazov (glejte [Meni Start in poljubni ukazi](start-menu.md)).
- Skriptiranje vedno deluje na **dejavnem** podoknu; najprej uporabite `go to … in left` / `in right`, če potrebujete določeno stran.
- Peach Commander je aplikacija z enim oknom, tako da skripti ciljajo na obe podokni tega okna.
