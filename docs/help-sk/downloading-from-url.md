---
title: Sťahovanie z URL
slug: downloading-from-url
section: Sieť a vzdialený prístup
order: 102
related: [ftp-and-sftp]
---

Peach Commander dokáže stiahnuť súbor priamo z webovej adresy HTTP alebo HTTPS do aktívneho panela, bez otvárania prehliadača. Vložte odkaz, potvrďte názov, pod ktorým sa uloží, a sťahovanie beží samo — s obnovením, ak spojenie spadne, dávkovým sťahovaním viacerých odkazov naraz a voliteľným overením kontrolného súčtu, takže viete, že súbor dorazil neporušený.

## Stiahnite súbor

1. Otvorte priečinok panela, kam chcete, aby súbor pristál.
2. Vyberte **Sieť > Stiahnuť z URL** alebo stlačte Cmd+Shift+D.
3. Vložte webovú adresu do poľa **URL adresy**. Ak ste najprv skopírovali odkaz, vyplní sa za vás.
4. Skontrolujte názov **Uložiť ako** — je navrhnutý z odkazu a môžete ho voľne upraviť.
5. Kliknite na **Stiahnuť**.

![Dialóg Stiahnuť z URL s odkazom, upraviteľným názvom súboru a možnosťami](screenshots/download-url.png)
*(Obrázok: dialóg sťahovania — vložte odkaz, upravte názov a nastavte voliteľné overenie, poverenia, hlavičky alebo proxy.)*

Predvolene sťahovanie beží **na pozadí**, takže môžete počas prenosu pokračovať v práci v paneloch. Vypnite **Stiahnuť na pozadí** na čakanie naň, alebo zapnite **Do fronty na neskôr** na jeho nastavenie bez toho, aby ste ho ešte začali.

## Stiahnite viac súborov naraz

Vložte jednu webovú adresu na riadok do poľa **URL adresy**. Keď je prítomných viac ako jeden odkaz, názov každého súboru sa automaticky odvodí z jeho odkazu a polia **Uložiť ako** a **Overiť** pre jednotlivé súbory sú vypnuté.

## Obnovenie prerušeného sťahovania

Ak sa prenos preruší, Peach Commander uchová to, čo už prijal, v dočasnom súbore `.part`. Opätovné spustenie toho istého sťahovania pokračuje od miesta, kde sa zastavilo, kedykoľvek to server podporuje, namiesto začatia odznova. Súbor `.part` sa premenuje na konečný názov až po úspešnom dokončení sťahovania.

## Skratky

| Akcia | Skratka |
| --- | --- |
| Stiahnuť z URL | Cmd+Shift+D |

## Tipy

- **Overte súbor.** Pri jednom sťahovaní vložte očakávaný kontrolný súčet **SHA-256** do poľa **Overiť**. Po prenose sa kontrolný súčet súboru s ním porovná, takže môžete dôverovať, že súbor zodpovedá tomu, čo vydavateľ uviedol.
- **Vyžaduje sa prihlásenie?** Zadajte používateľské meno a heslo do polí **Overenie** pre stránky, ktoré používajú základné overenie. Pre prístup založený na tokene pridajte riadok `Authorization: Bearer …` do poľa **Hlavičky**.
- **Vlastné hlavičky.** Pridajte jednu hlavičku na riadok do poľa **Hlavičky**, napríklad `Referer: …` alebo `Cookie: …`, pre odkazy, ktoré fungujú iba s konkrétnymi hlavičkami požiadavky.
- **Proxy.** Nasmerujte sťahovanie cez proxy HTTP alebo SOCKS5 vyplnením hostiteľa, portu a typu **Proxy**.
- **Nedôveryhodné certifikáty.** Zapnite **Povoliť nedôveryhodný certifikát** iba pre dôveryhodnú stránku, ktorá používa samopodpísaný certifikát; vypne to normálnu bezpečnostnú kontrolu HTTPS pre dané sťahovanie.
- **Poznámka:** Cmd+Shift+D sa používa aj inde na prechod do priečinka Plocha; ak skratka neotvorí tento dialóg, použite namiesto toho **Sieť > Stiahnuť z URL** z ponuky.
