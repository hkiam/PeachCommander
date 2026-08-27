---
title: Makrá
slug: macros
section: Pokročilé nástroje
order: 99
related: [automation, toolbar, start-menu, keyboard-shortcuts]
---

Makro je pomenovaná sekvencia akcií so súbormi — vytvoriť adresár, presunúť doň výber, označiť zvyšok — ktorú možno jediným kliknutím spustiť znova. Nie je to skriptovací jazyk: nie sú v ňom podmienky ani cykly, a to zámerne. Makro je zoznam, ktorý si môžete prečítať, a prečítať si ho musíte vedieť skôr, ako ho schválite.

Všetko, čo makro robí, prechádza tým istým strojom ako asistent. Makro teda nemôže urobiť nič, čo ste nepovolili, každý jeho krok sa objaví v protokole akcií a krok, ktorý sa dá vzať späť, sa dá vzať späť aj naďalej.

## Najrýchlejšia cesta: z toho, čo ste práve urobili

Makro nemusíte písať od začiatku.

1. Urobte to raz — cez asistenta alebo spustením existujúceho makra.
2. Zvoľte **Konfigurácia ▸ Makro z nedávnych akcií…**.
3. Zaškrtnite kroky, ktoré má makro opakovať, pomenujte ho a nechajte zapnuté **Pridať pre neho aj tlačidlo**.

**Uložiť makro** — a tlačidlo je v lište. To je celý postup.

> **Čo sa nezaznamenáva.** Zoznam sa skladá z akcií, ktoré prešli asistentom alebo iným makrom. Ručné kopírovanie, presúvanie a premenovanie v paneloch — F5, F6, F7 — sa nezaznamenáva, takže sa z nich touto cestou makro urobiť nedá. Na to použite editor nižšie.

## Ručné úpravy makier

**Konfigurácia ▸ Upraviť makrá…** otvorí `macros.json` vo vašom konfiguračnom adresári a prvýkrát doň vloží komentovaný príklad. Makro je zoznam krokov a každý krok uvádza nástroj a jeho argumenty:

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

Uloženie makrá okamžite znova načíta. Ktoré nástroje existujú a čo prijímajú, povie asistent cez `list_macros` — alebo príklad, s ktorým bol súbor vytvorený.

### Zástupné symboly

Samotné písmená sú tie isté, aké používa lišta tlačidiel a ponuka Štart: kto už jedno tlačidlo vytvoril, sa tu nemusí učiť nič nové.

| Symbol | Znamená |
| --- | --- |
| `%P` | Adresár aktívneho panela |
| `%T` | Adresár druhého panela |
| `%N` | Súbor pod kurzorom |
| `%S` | Vybrané súbory — **zoznam**, čo je presne to, čo prijímajú `copy`, `move` a `move_to_trash` |
| `%{date:yyyy-MM}` | Dátum spustenia makra v tomto formáte |
| `%{1}` | Výsledok kroku 1, ak tento krok vrátil cestu alebo zoznam ciest |

Zložené zátvorky sú pre doplnky, pretože písmená sú už obsadené: `%M` znamená vo zvyšku programu „meno pod kurzorom v druhom paneli“, mesiac sa teda takto zapísať nedal.

`%S` je jediné miesto, kde sa makro líši od tlačidla: na tlačidle sa výber stane zoznamom slov pre príkazový riadok, tu sa stane zoznamom plných ciest, ktoré prijímajú nástroje pre súbory.

Krok, ktorého `%S` alebo `%{1}` vyjde **prázdny, makro zastaví**, namiesto toho, aby bežal s ničím. `move` bez súborov nie je menší `move` — je to požiadavka, ktorá už nič nehovorí, a hlásiť pri nej úspech by bola lož.

## Spustenie makra

Každé makro sa stane príkazom s názvom `mc_<id>`, a preto sa samo objaví v:

- **Konfigurácia ▸ Prehliadač príkazov…**
- **Konfigurácia ▸ Upraviť skratky… — priraďte ho klávese**
- Výbere príkazov v editore lišty tlačidiel
- Vašom súbore ponuky `.mnu` a `usercmd.ini`, ak ich používate
- Asistentovi, ktorý ho môže spustiť podľa názvu

Než sa spustí makro, ktoré niečo mení, ukáže vám svoje kroky ako zoznam a počká. Krok, ktorý nechcete, môžete vyškrtnúť; čo zostane, sa vykoná. Makro, ktoré len číta, beží bez otázky.

Ak krok zlyhá, makro sa **na tom mieste zastaví**, namiesto toho, aby pokračovalo — krok dva zvyčajne predpokladá, že krok jeden prebehol, a presúvať súbory do nevytvoreného adresára nie je čiastočný úspech. Správa uvedie krok a povie, čo sa pokazilo; kroky, ktoré prebehli, sú v protokole akcií.

## Čo makro smie

Makro sa posudzuje podľa toho najnáročnejšieho, čo obsahuje. Makro, ktorého kroky len čítajú, sa považuje za čítanie; to, ktoré končí trvalým vymazaním, je chránené ako trvalé vymazanie — skôr než sa čokoľvek spustí, nie o štyri kroky neskôr.

Nepovoliť nič navyše je predvolený stav. Ak makro obsahuje krok, ktorý vaše oprávnenia nedovoľujú — príkaz shellu, skript —, celé makro je odmietnuté s uvedením dôvodu a nič sa nestane.

## Vzatie späť

Každý krok je zaznamenaný samostatne, takže **vzatie späť** po makre vráti jeho *posledný* krok, nie celé makro. Vzatie celého makra späť neexistuje, pretože niekoľko nástrojov nemá žiadnu inverziu a tlačidlo, ktoré by to ponúkalo, by o nich klamalo.

## Kde sa to ukladá

- Vaše makrá sú v `macros.json` v konfiguračnom adresári — obyčajný súbor, ktorý možno porovnávať a držať spolu s dotfiles.
- Tlačidlá pridané makrom sú bežné položky lišty tlačidiel v `default.bar`, takže odobrať jedno je to isté ako u ktoréhokoľvek iného tlačidla.

## Ďalšie kroky

- [Automatizácia (AppleScript a Skratky)](automation.md) — Riadenie Peach Commanderu zo skriptu a spúšťanie vlastných skriptov ako kroku makra.
- [Lišta tlačidiel](toolbar.md) — Kde skončí tlačidlo, ktoré makro pridalo.
- [Klávesnica a skratky](keyboard-shortcuts.md) — Priradenie makra klávese.
