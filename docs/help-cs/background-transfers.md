---
title: Přenosy na pozadí
slug: background-transfers
section: Soubory a složky
order: 32
related: [copying-files, downloading-from-url]
---

Rozsáhlé kopírování, přesouvání, mazání a stahování nemusí zdržovat vaši práci. Peach Commander je dokáže spouštět na pozadí a shromáždit vše na jednom místě: ve Správci přenosů na pozadí. Odtud sledujete průběh a přenosovou rychlost každé úlohy, pozastavíte ji nebo obnovíte, zrušíte ji nebo úlohy seřadíte, aby se spustily později. Protože úloha na pozadí běží samostatně, nikdy vám nebrání v procházení, otevírání souborů nebo zahájení dalšího přenosu.

## Postup

1. Zahajte kopírování, přesun, mazání nebo stahování a zvolte spuštění na pozadí. Úloha se objeví ve Správci přenosů na pozadí.
2. Správce kdykoli otevřete z nabídky **Příkazy ▸ Správce přenosů na pozadí…** (nebo stiskem Cmd+Shift+B).
3. Každá úloha zobrazuje název, ukazatel průběhu a živý řádek s dokončenými soubory, přenesenými bajty a aktuální rychlostí.
4. Pomocí tlačítek u jednotlivých úloh můžete během běhu úlohu **Pozastavit**, **Obnovit** nebo **Zrušit**.
5. Běžící úloha má také nabídku rychlosti. Zvolte limit — 1, 5 nebo 20 MB/s, nebo plnou rychlost —, abyste jednu přenášenou úlohu uhnuli z cesty jiné, aniž byste zpomalili ostatní. Platí okamžitě; **Výchozí** vrátí úlohu k limitu nastavenému v Konfiguraci.
6. U úloh, které jste přidali, ale dosud nespustili (podržené úlohy), klikněte na **Spustit**, nebo na **Spustit vše** pro celý seznam. Tlačítky **▲** a **▼** posunete čekající úlohu ve frontě dopředu nebo dozadu; objeví se jen tam, kde je posun možný, takže čekající úloha nikdy nepředběhne již běžící přenos.
7. Až vše, na čem vám záleží, skončí, kliknutím na **Vymazat dokončené** uklidíte seznam.

![Správce přenosů na pozadí vypisující aktivní a čekající úlohy s ukazateli průběhu a tlačítky Pozastavit, Obnovit a Zrušit.](screenshots/transfer-manager.png)

*Každý přenos je řádek, který můžete nezávisle pozastavit, obnovit nebo zrušit.*

## Klávesové zkratky

| Akce | Zkratka |
| --- | --- |
| Otevřít Správce přenosů na pozadí | Cmd+Shift+B |

## Tipy

- **Omezte rychlost.** Aby velký přenos nezahltil vaše připojení nebo disk, nastavte před spuštěním úlohy omezení rychlosti v dialogu kopírování. Správce pak živě zobrazuje omezenou rychlost.
- **Zařaďte do fronty na později.** Pozdržené úlohy zůstávají v seznamu bez běhu, dokud nestisknete Spustit (nebo Spustit vše), takže můžete připravit několik přenosů a spustit je společně.
- **Spusťte několik naráz.** Úlohy běží nezávisle, takže můžete jednu pozastavit, zatímco jiná pokračuje.

## Poznámky

Protože úloha na pozadí běží bez vašeho dohledu, nemůže se zastavit a klást otázky. Pokud v cíli soubor již existuje, úloha na pozadí jej přepíše; pokud jednotlivou položku nelze přenést, tato položka se přeskočí a úloha pokračuje. Po dokončení úlohy se všechny přeskočené položky shromáždí do protokolu chyb, abyste si mohli přesně prohlédnout, co se pokazilo.
