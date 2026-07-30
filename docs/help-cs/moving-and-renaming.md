---
title: Přesun a přejmenování
slug: moving-and-renaming
section: Soubory a složky
order: 26
related: [copying-files, multi-rename]
---

Přesun přemísťuje soubory a složky místo jejich duplikování a přejmenování mění jejich názvy, aniž by se dotklo obsahu. Protože Peach Commander zobrazuje dva panely vedle sebe, přesun je jen otázkou výběru toho, co chcete, v jednom panelu a jeho odeslání do složky otevřené v druhém. Můžete také přejmenovat položku na místě, nebo dát přesouvaným položkám nové názvy za pochodu pomocí masky se zástupnými znaky.

## Přesun souborů do druhého panelu

1. Ve zdrojovém panelu otevřete složku obsahující položky, které chcete přesunout, a otevřete cílovou složku v druhém panelu.
2. Vyberte soubor nebo složku k přesunu. Chcete-li přesunout několik najednou, nejprve je všechny vyberte (viz *Výběr souborů*).
3. Stiskněte F6, nebo zvolte **Soubory > Přesunout**.
4. Zkontrolujte cílovou složku zobrazenou v dialogu a klepnutím na **OK** (nebo stiskem Enter) zahajte přesun.

![Dialog přesunu zobrazující pole cílové cesty, možnosti a zaškrtávací pole fronty](screenshots/copy-dialog.png)
*(Obrázek: dialog přesunu používá stejné cílové pole jako kopírování — zadejte cestu, nebo přidejte masku se zástupnými znaky k přejmenování při přesunu.)*

Přesuny na stejném disku probíhají téměř okamžitě. Když je cíl na jiném disku, Peach Commander položky zkopíruje a originály odstraní teprve poté, co každý soubor bezpečně dorazil.

## Přejmenování na místě

1. Vyberte jeden soubor nebo složku.
2. Stiskněte Shift+F6, nebo zvolte **Soubory > Přejmenovat**.
3. Upravte název přímo v panelu, poté stiskem Enter potvrďte nebo Esc zrušte.

## Přejmenování při přesunu

Cílové pole v dialogu přesunu přijímá masku se zástupnými znaky, takže můžete položky přejmenovat, jak se přesouvají:

1. Vyberte položky a stiskněte F6.
2. Do cílového pole přidejte za cílovou složku masku názvu, například `/Users/vy/Archive/*_backup.*`.
3. `*` zastupuje původní název a `.*` původní příponu. Potvrzením přesunete a přejmenujete v jednom kroku.

## Zkratky

| Akce | Zkratka |
| --- | --- |
| Přesunout do druhého panelu | F6 |
| Přejmenovat na místě | Shift+F6 |

## Tipy

- Dialog přesunu nabízí stejné tlačítko možností a zaškrtávací pole fronty na pozadí jako kopírování, takže můžete velké přesuny zařadit do fronty a nechat je běžet na pozadí.
- Přesun v rámci stejného disku je rychlá operace na místě, takže je bezpečný pro velmi velké složky. Přesun mezi disky trvá déle, protože data se nejprve zkopírují a poté se zdroj smaže.
- Chcete-li přejmenovat mnoho souborů najednou s číslováním, hledáním a nahrazováním nebo vzory, použijte místo toho nástroj hromadného přejmenování (viz *Hromadné přejmenování*).
