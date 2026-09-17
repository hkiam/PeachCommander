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
3. Pokračujte v písaní na spresnenie zhody, alebo prechádzajte medzi zhodami klávesmi ↑ a ↓, kým je hľadanie zobrazené. Opätovné stlačenie toho istého písmena tiež prechádza položky, ktoré ním začínajú.
4. Napísaný text sa po krátkej pauze vymaže, takže nové hľadanie môžete začať kedykoľvek.

Predvolene obyčajné písmená idú do príkazového riadka a rýchle hľadanie sa spúšťa pomocou Ctrl+Option+písmeno (klasické správanie). Rýchle hľadanie môžete prepnúť tak, aby reagovalo na obyčajné písanie, alebo ho vypnúť, v nastaveniach konfigurácie.

## Filtrovanie zoznamu (rýchly filter)

1. V aktívnom paneli stlačte Ctrl+S na zapnutie rýchleho filtra.
2. Napíšte filtrovaciu masku. Panel sa počas písania živo zužuje na zodpovedajúce položky a kurzor zostáva na položke, ktorú ste sledovali, kým ju užšia maska ponecháva.
3. Výsledkom sa pohybujte klávesmi ↑ a ↓. Vo filtrovanom zozname sa šípky otáčajú, takže posledná položka vedie späť na začiatok a krátky výsledok možno obchádzať dokola bez narážania na konce.
4. Stlačte Esc na vymazanie filtra a opätovné zobrazenie všetkého. Kurzor zostáva na nájdenej položke, teraz zobrazenej medzi susedmi.

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
| Predchádzajúca / ďalšia zhoda (počas rýchleho hľadania) | ↑ / ↓ |
| Rýchly filter zap./vyp. | Ctrl+S |
| Vymazať filter / zrušiť | Esc |
| Zobraziť/skryť skryté súbory | Ctrl+H |

## Poznámky

- Rýchle hľadanie iba posúva kurzor; rýchly filter skutočne mení, ktoré položky sú uvedené. Filter použite, keď chcete pracovať na podmnožine (napríklad vybrať alebo skopírovať len zhody).
- Nastavenia filtra a skrytých súborov platia pre každý panel, takže obe strany môžu zobrazovať rôzne veci naraz.
- Rýchle hľadanie zhoduje názvy od začiatku; režim obyčajného textu rýchleho filtra zhoduje kdekoľvek v názve. Použite zástupný znak ako `*text*`, ak chcete, aby sa filter správal rovnako.
