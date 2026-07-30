---
title: Uninstaller
slug: uninstaller
section: Zásuvné moduly
order: 126
related: [plugins, deleting-files]
---

Presunutie aplikácie do Koša za sebou nechá jej podporné súbory, vyrovnávacie pamäte, predvoľby a kontajnery roztrúsené po vašich priečinkoch Library. Zásuvný modul Uninstaller odstráni aplikáciu **aj** tieto zvyšky: nájde všetko, čo aplikácia zanechala, zobrazí vám zoznam s veľkosťou každej položky a po vašom potvrdení presunie všetko do Koša. Keďže ide o zásuvný modul, môžete ho vypnúť alebo odstrániť v **Konfigurácia ▸ Zásuvné moduly…**.

## Odinštalovanie aplikácie pod kurzorom

1. Umiestnite kurzor na aplikáciu (`.app`) v paneli.
2. Vyberte **Súbor ▸ Odinštalovať aplikáciu…**, alebo pravý klik ▸ **Odinštalovať aplikáciu…**, alebo stlačte **Cmd+Shift+U**.
3. Otvorí sa okno kontroly, uvádzajúce aplikáciu plus každý súvisiaci súbor, ktorý našlo, každý označený svojou kategóriou, cestou a veľkosťou.
4. Odškrtnite čokoľvek, čo si chcete ponechať, potom kliknite na **Presunúť do Koša** (alebo **Odstrániť natrvalo**).

![Okno kontroly odinštalovania uvádzajúce zvyškové súbory aplikácie so zaškrtávacími poľami a veľkosťami](screenshots/uninstaller.png)
*(Obrázok: pred odstránením čohokoľvek skontrolujte presne to, čo sa odstráni.)*

## Prehliadanie všetkých nainštalovaných aplikácií

Vyberte **Príkazy ▸ Odinštalovať aplikáciu…** na otvorenie prehľadávateľného zoznamu aplikácií nainštalovaných na vašom Macu, s názvom, veľkosťou a dátumom inštalácie každej aplikácie. Vyberte jednu (alebo viacero), kliknite na **Odinštalovať…** a ocitnete sa v tom istom okne kontroly. Zoznam môžete filtrovať písaním do poľa hľadania.

## Nájdenie zvyškových súborov

Vyberte **Príkazy ▸ Nájsť zvyškové súbory…** na vyhľadanie podporných súborov, vyrovnávacích pamätí a predvolieb, ktoré patria aplikáciám, ktoré ste **už** odstránili. Skontrolujte ich rovnakým spôsobom a odstráňte ich. Ak sa nič nenájde, zásuvný modul vám to oznámi.

## Ako dôkladne skenovať

Okno kontroly má ovládací prvok spoľahlivosti:

- **Presné** — súbory ukotvené na identifikátor balíka aplikácie. Vysoká spoľahlivosť; vopred vybrané.
- **Rozšírené** — pridáva súbory zhodné podľa názvu; ponechané neoznačené, aby ste sa mohli rozhodnúť.
- **Hĺbkové** — Rozšírené plus prehľadanie cez Spotlight na čokoľvek ďalšie, čo spomína aplikáciu; tiež ponechané neoznačené.

## Poznámky

- Zásuvný modul nič neodstraňuje priamo — položky prechádzajú cez Kôš aplikácie alebo trvalé odstránenie, presne ako každá iná operácia so súbormi. Odstránenie súborov v `/Library` alebo `/var` môže vyžadovať heslo správcu.
- Pred odstránením zásuvný modul ukončí bežiacu aplikáciu a odbremení jej položky na pozadí (launchd), potom ponúkne upratanie akýchkoľvek teraz prázdnych priečinkov dodávateľa.
- Ak bola aplikácia nainštalovaná pomocou **Homebrew**, zásuvný modul vás upozorní a navrhne `brew uninstall --cask`, aby Homebrew zostal synchronizovaný. Aplikácie z App Store sú tiež zaznamenané.
- Zhody Rozšírené a Hĺbkové sú zámerne menej spoľahlivé a začínajú neoznačené — pred odstránením ich skontrolujte. Niektoré položky na pozadí nainštalované cez moderné API položiek prihlásenia tu nemožno odstrániť.
