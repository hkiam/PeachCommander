---
title: Súbory CSV ako tabuľka
slug: csv-lister
section: Plugins
order: 129
related: [plugins, viewing-files, log-viewer]
---

Stlačte **F3** na súbore `.csv` alebo `.tsv` a otvorí sa ako skutočná tabuľka — stĺpce, záhlavie, zoraďovanie a filter — namiesto ako textové riadky s čiarkami.

Je to plugin: môžete ho vypnúť alebo odstrániť v **Konfigurácia ▸ Pluginy…**. Bez neho zobrazí F3 súbor ako obyčajný text, čo je pri malom súbore stále dobre čitateľné.

## Oddeľovač sa zistí, nepredpokladá sa

Čiarka, bodkočiarka, tabulátor, zvislá čiara a dvojbodka prichádzajú do úvahy všetky. Plugin každý z nich spočíta cez prvých dvadsať riadkov a vezme ten, ktorý sa na najviac riadkoch vyskytuje rovnako často — súbor, kde má každý riadok štyri bodkočiarky, je súborom s bodkočiarkami, nech prípona hovorí čokoľvek. V praxi na tom záleží: `.csv` vyexportované tabuľkovým procesorom na slovenskom systéme býva oddelené bodkočiarkami a `.tsv` nie je vždy oddelené tabulátormi.

Prvý riadok sa považuje za záhlavie a stanú sa z neho názvy stĺpcov.

## Zoraďovanie a filtrovanie

Kliknutím na záhlavie stĺpca sa podľa neho zoradí, ďalším kliknutím sa poradie obráti. Zoraďuje sa **číselne, keď sú obe hodnoty čísla**, inak abecedne, takže stĺpec s veľkosťami zoradí 9 pred 10, a nie za.

Vyhľadávacie pole filtruje počas písania, bez ohľadu na veľkosť písmen. V predvolenom stave hľadá vo všetkých stĺpcoch; výberom stĺpca v ponuke vedľa hľadá len v ňom.

## Čo nedokáže

Parser je zámerne malý a jedno obmedzenie je dobré poznať skôr, než vás prekvapí: **oddeľovač vnútri poľa v úvodzovkách sa stále považuje za oddeľovač.** Riadok ako

```
"Smith, John",42
```

sa stane tromi bunkami namiesto dvoch. Obklopujúce úvodzovky sa odstránia, ak obopínajú celé pole, ďalej sa však úvodzovky nevyhodnocujú. Pri súbore, kde na tom záleží, je lepším nástrojom vstavaný prehliadač alebo tabuľkový procesor.

Prázdne riadky sa preskakujú a pole presahujúce niekoľko riadkov podporované nie je.
