---
title: Globální historie
slug: history
section: Uspořádání zobrazení
order: 47
related: [favorites, navigating]
---

Globální historie je jedno okno, které si pamatuje vaši vlastní práci: navštívené složky, otevřené soubory, provedené operace a spuštěné příkazy. Odkudkoli stiskněte Ctrl+Cmd+H, začněte psát a za sekundu jste zpět ve včerejší složce — bez myši.

## Otevření historie

1. Stiskněte Ctrl+Cmd+H nebo zvolte **Přejít > Historie…**. Nezáleží na tom, který panel je aktivní.
2. Napište několik znaků. Shoda nemusí být přesná ani souvislá: `proj rep` najde `~/Projects/annual-report.txt`.
3. Mezi výsledky se pohybujte klávesami Nahoru a Dolů, zatímco dál píšete.
4. Enter provede označenou položku, Esc okno zavře.

Položky jsou seřazené podle toho, jak nedávno *a* jak často jste je použili, takže místa, kde pracujete nejvíc, jsou už nahoře. Připnuté položky vedou vždy.

## Filtrování podle druhu

Tlačítka pod vyhledávacím polem omezí seznam na všechny položky, složky, soubory, operace nebo oblíbené. Option+1 až Option+5 mezi nimi přepínají z klávesnice.

## Práce s položkou

| Akce | Zkratka |
| --- | --- |
| Otevřít označenou položku | Return |
| Zobrazit v panelu, s kurzorem na ní | Option+Return |
| Otevřít jednu z devíti nejrelevantnějších položek | Cmd+1 … Cmd+9 |
| Přepnout panel, ve kterém se otevírá | Tab |
| Připnout nebo odepnout položku | Cmd+P |
| Odebrat položku z historie | Cmd+Delete |
| Kopírovat cestu položky | Option+Cmd+C |
| Zobrazit položku ve Finderu | Cmd+Shift+R |
| Zavřít historii | Esc |

Enter udělá to, co položce odpovídá: složka se otevře v cílovém panelu, soubor se otevře stejně jako z panelu a příkazová řádka se vloží do příkazového řádku, abyste si ji mohli prohlédnout a spustit. Cílový panel je uveden dole v okně a Tab jej přepíná.

## Zopakování operace

Kopírování nebo přesun se objeví pod **Operace** a Enter je spustí znovu — tytéž položky do téže složky, běžnou přenosovou frontou i s jejími dotazy na přepsání. Položky, které už neexistují, se přeskočí, a nezůstane-li žádná, dozvíte se to.

Mazání a přejmenování jsou v seznamu, ale nikdy se neopakují: Enter místo toho ukáže, kde se staly. Zopakovat mazání nemá být na jedno stisknutí v seznamu, který jen prohlížíte.

## Udržení pod kontrolou

Nastavení ▸ Ostatní rozhoduje, zda se historie vede, kolik položek si drží a po kolika dnech je zapomene. Připnuté položky jsou z obojího vyňaté a 0 dní znamená uchovat vše; seznam leží v `history.ini` ve vaší konfigurační složce a přežije restart.

## Poznámky

- Otevřít něco z historie se počítá jako použití — proto to, k čemu se vracíte, stále stoupá.
- Pamatují se i složky na serverech a v discích zásuvných modulů; ta, která už není dosažitelná, to při pokusu řekne.
- Není to vlastní historie složek panelu na Alt+Dolů, která vypisuje jen to, kde byl ten jeden panel, v pořadí.
