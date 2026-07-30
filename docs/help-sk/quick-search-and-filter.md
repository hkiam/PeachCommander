---
title: Rýchle hľadanie a filter
slug: quick-search-and-filter
section: Usporiadanie zobrazenia
order: 44
related: [searching, view-modes-and-sorting]
---

Keď priečinok obsahuje stovky položiek, málokedy potrebujete posúvať. Peach Commander vám umožňuje skočiť rovno na súbor napísaním jeho názvu (rýchle hľadanie), zúžiť zoznam len na položky, ktoré vás zaujímajú (rýchly filter), a zobraziť alebo skryť bodkové súbory, ktoré macOS zvyčajne drží mimo dohľadu. Všetky tri fungujú vnútri aktívneho panela bez otvárania dialógu.

## Skok na súbor písaním (rýchle hľadanie)

1. Kliknite na panel súborov, aby bol aktívny.
2. Začnite písať začiatok názvu. Kurzor skočí na prvú zhodnú položku.
3. Pokračujte v písaní na spresnenie zhody, alebo stlačte to isté písmeno znova na prechádzanie položkami, ktoré začínajú tým písmenom.
4. Napísaný text sa po krátkej pauze vymaže, takže nové hľadanie môžete začať kedykoľvek.

Predvolene obyčajné písmená idú do príkazového riadka a rýchle hľadanie sa spúšťa pomocou Ctrl+Option+písmeno (klasické správanie). Rýchle hľadanie môžete prepnúť tak, aby reagovalo na obyčajné písanie, alebo ho vypnúť, v nastaveniach konfigurácie.

## Filtrovanie zoznamu (rýchly filter)

1. V aktívnom paneli stlačte Ctrl+S na zapnutie rýchleho filtra.
2. Zadajte masku filtra. Panel sa počas písania naživo zúži na zhodné položky.
3. Stlačte Esc na vymazanie filtra a opätovné zobrazenie všetkého.

Filter prijíma niekoľko druhov masiek:

- **Obyčajný text** sa zhoduje s ktorýmkoľvek názvom, ktorý obsahuje to, čo ste napísali (napríklad `správa` zobrazí každú položku so slovom „správa" kdekoľvek v názve).
- **Zástupné znaky** používajú `*` (ľubovoľné znaky) a `?` (jeden znak). Oddeľte viac masiek bodkočiarkou a pridajte výnimky za zvislú čiaru, napríklad `*.jpg;*.png|*thumb*` na zobrazenie obrázkov, ale skrytie miniatúr.
- **Štítky Finder** filtrujú podľa farby štítka: napíšte `tag:red` (alebo `#red`) na zobrazenie len položiek s červeným štítkom, alebo holé `tag:` na zobrazenie všetkého, čo nesie akýkoľvek štítok.

## Zobrazenie skrytých súborov

Stlačte Ctrl+H, alebo vyberte príkaz z ponuky Zobraziť, na prepnutie skrytých položiek (názvy začínajúce bodkou a systémovo skryté súbory). Nastavenie platí pre aktívny panel a pamätá sa medzi reláciami.

## Skratky

| Akcia | Skratka |
| --- | --- |
| Rýchle hľadanie (klasický režim) | Ctrl+Option+písmeno |
| Rýchly filter zap./vyp. | Ctrl+S |
| Vymazať filter / zrušiť | Esc |
| Zobraziť/skryť skryté súbory | Ctrl+H |

## Poznámky

- Rýchle hľadanie iba posúva kurzor; rýchly filter skutočne mení, ktoré položky sú uvedené. Filter použite, keď chcete pracovať na podmnožine (napríklad vybrať alebo skopírovať len zhody).
- Nastavenia filtra a skrytých súborov platia pre každý panel, takže obe strany môžu zobrazovať rôzne veci naraz.
- Rýchle hľadanie zhoduje názvy od začiatku; režim obyčajného textu rýchleho filtra zhoduje kdekoľvek v názve. Použite zástupný znak ako `*text*`, ak chcete, aby sa filter správal rovnako.
