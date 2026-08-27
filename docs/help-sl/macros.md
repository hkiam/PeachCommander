---
title: Makri
slug: macros
section: Zmogljiva orodja
order: 99
related: [automation, toolbar, start-menu, keyboard-shortcuts]
---

Makro je poimenovano zaporedje dejanj z datotekami — ustvari mapo, vanjo premakni izbor, kar ostane pa označi — ki ga lahko z enim klikom znova zaženete. Ni skriptni jezik: ni pogojev in ni zank, in to je namerno. Makro je seznam, ki ga lahko preberete, in prebrati ga morate znati, preden ga odobrite.

Vse, kar makro počne, gre skozi isto napravo kot pomočnik. Makro torej ne more storiti ničesar, česar niste dovolili, vsak njegov korak se pojavi v dnevniku dejanj, korak, ki ga je mogoče razveljaviti, pa to ostane.

## Najhitrejša pot: iz tega, kar ste pravkar naredili

Makra ni treba napisati iz nič.

1. Naredite stvar enkrat — prek pomočnika ali z zagonom obstoječega makra.
2. Izberite **Nastavitve ▸ Makro iz nedavnih dejanj…**.
3. Označite korake, ki naj jih makro ponovi, poimenujte ga in pustite vklopljeno **Zanj dodaj tudi gumb**.

**Shrani makro** — in gumb je v vrstici. To je ves postopek.

> **Kaj se ne zapisuje.** Seznam se sestavi iz dejanj, ki so šla skozi pomočnika ali drug makro. Ročno kopiranje, premikanje in preimenovanje v pultih — F5, F6, F7 — se ne zapisuje, zato po tej poti iz njih ni mogoče narediti makra. Za to uporabite urejevalnik spodaj.

## Ročno urejanje makrov

**Nastavitve ▸ Uredi makre…** odpre `macros.json` v vaši nastavitveni mapi in prvič vanjo vstavi komentiran primer. Makro je seznam korakov, vsak korak pa navaja orodje in njegove argumente:

```json
[
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
]
```

Shranjevanje makre takoj znova naloži. Katera orodja obstajajo in kaj sprejmejo, vam pove pomočnik prek `list_macros` — ali primer, s katerim je bila datoteka ustvarjena.

### Nadomestni znaki

Posamezne črke so iste, kot jih uporabljata vrstica z gumbi in meni Start: kdor je že naredil gumb, se tu ne rabi učiti nič novega.

| Nadomestek | Pomeni |
| --- | --- |
| `%P` | Mapa aktivnega pulta |
| `%T` | Mapa drugega pulta |
| `%N` | Datoteka pod kazalcem |
| `%S` | Izbrane datoteke — **seznam**, kar je natanko to, kar sprejmejo `copy`, `move` in `move_to_trash` |
| `%{date:yyyy-MM}` | Datum zagona makra v tej obliki |
| `%{1}` | Rezultat koraka 1, če je ta korak vrnil pot ali seznam poti |

Zaviti oklepaji so za dodatke, ker so črke že zasedene: `%M` v vsem preostalem programu pomeni »ime pod kazalcem v drugem pultu«, zato meseca ni bilo mogoče zapisati tako.

`%S` je edino mesto, kjer se makro razlikuje od gumba: na gumbu izbor postane seznam besed za ukazno vrstico, tu pa seznam polnih poti, ki jih sprejmejo datotečna orodja.

Korak, katerega `%S` ali `%{1}` pride **prazen, ustavi makro**, namesto da bi tekel brez česa. `move` brez datotek ni manjši `move` — je zahteva, ki ne pove več nič, in poročati o uspehu bi bila laž.

## Zagon makra

Vsak makro postane ukaz z imenom `mc_<id>` in se zato sam pojavi v:

- **Nastavitve ▸ Brskalnik ukazov…**
- **Nastavitve ▸ Uredi bližnjice… — dodelite ga tipki**
- Izbirniku ukazov v urejevalniku vrstice z gumbi
- Vaši datoteki menija `.mnu` in `usercmd.ini`, če ju uporabljate
- Pomočniku, ki ga lahko zažene po imenu

Preden se zažene makro, ki kaj spremeni, vam pokaže svoje korake kot seznam in počaka. Korak, ki ga ne želite, lahko prečrtate; kar ostane, se izvede. Makro, ki samo bere, teče brez vprašanja.

Če korak spodleti, se makro **tam ustavi** namesto da bi nadaljeval — drugi korak običajno predpostavlja, da se je prvi zgodil, in premikanje datotek v mapo, ki ni bila ustvarjena, ni delni uspeh. Poročilo navede korak in pove, kaj je šlo narobe; koraki, ki so se izvedli, so v dnevniku dejanj.

## Kaj makro sme

Makro se presoja po najzahtevnejšem, kar je v njem. Makro, katerega koraki samo berejo, velja za branje; tisti, ki se konča s trajnim brisanjem, je varovan kot trajno brisanje — preden se karkoli zažene, ne štiri korake pozneje.

Ne dodeliti nič dodatnega je privzeto. Če makro vsebuje korak, ki ga vaša dovoljenja ne dopuščajo — ukaz lupine, skript — je celoten makro zavrnjen z navedbo razloga in nič se ne zgodi.

## Razveljavitev

Vsak korak se zapiše zase, zato **razveljavi** po makru vzame nazaj njegov *zadnji* korak, ne celega makra. Razveljavitve celega makra ni, ker več orodij nima nobenega obratnega dejanja in gumb, ki bi jo ponujal, bi o njih lagal.

## Kje se vse shrani

- Vaši makri so v `macros.json` v nastavitveni mapi — navadna datoteka, ki jo lahko primerjate in hranite skupaj z dotfiles.
- Gumbi, ki jih je dodal makro, so navadni vnosi vrstice z gumbi v `default.bar`, zato je odstraniti enega enako kot pri katerem koli drugem gumbu.

## Naslednji koraki

- [Avtomatizacija (AppleScript in Bližnjice)](automation.md) — Vodenje Peach Commanderja iz skripta in zaganjanje lastnih skriptov kot koraka makra.
- [Vrstica z gumbi](toolbar.md) — Kje pristane gumb, ki ga je dodal makro.
- [Tipkovnica in bližnjice](keyboard-shortcuts.md) — Dodelitev makra tipki.
