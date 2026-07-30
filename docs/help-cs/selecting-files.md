---
title: Výběr souborů
slug: selecting-files
section: Soubory a složky
order: 22
related: [copying-files, searching]
---

Než něco zkopírujete, přesunete, smažete nebo zabalíte, nejprve řeknete Peach Commanderu, na které položky má působit. Položka, na níž kurzor stojí, je vždy aktuální položkou, ale můžete také *označit* jeden nebo více souborů a složek, aby se příkaz provedl na všech najednou. Označené položky se v panelu odlišují výraznou barvou názvu.

## Označení souborů a složek

1. Klepnutím na řádek na něj přesunete kurzor. Jedno klepnutí vybere pouze tuto jednu položku.
2. Chcete-li označit několik položek najednou, podržte Cmd a klepněte na každou, nebo podržte Shift a klepnutím označte rozsah.
3. Chcete-li označit položku pod kurzorem a zároveň sestoupit dolů, stiskněte Insert. Opakovaným stiskem rychle označíte řadu po sobě jdoucích položek. Mezerník rovněž přepíná označení aktuální položky (a zobrazuje velikost složky).
4. Chcete-li označit vše v panelu, zvolte Výběr > Vybrat vše (Ctrl+Num+), nebo stiskněte Cmd+A. Zvolte Výběr > Zrušit výběr všeho (Ctrl+Num-) pro zrušení všech označení.

## Výběr nebo zrušení podle vzoru

1. Zvolte Výběr > Vybrat skupinu… (Num+) pro přidání položek, jejichž názvy odpovídají vzoru, nebo Výběr > Zrušit výběr skupiny… (Num-) pro odebrání odpovídajících položek z aktuálních označení.
2. Zadejte masku se zástupnými znaky. Použijte `*` pro libovolné znaky a `?` pro jeden znak. Více masek oddělte středníkem a výjimky uveďte za svislou čárou — například `*.jpg;*.png` označí všechny obrázky a `*.*|*.bak` označí vše kromě záložních souborů.

![Dialog Vybrat skupinu s maskou se zástupnými znaky zadanou v poli vzoru](screenshots/select-by-mask.png)
*(Obrázek: označování souborů maskou se zástupnými znaky.)*

## Invertovat, stejná přípona a obnovit

- **Invertovat výběr** (Num*, nabídka Výběr) obrátí každé označení: označené položky se stanou neoznačenými a naopak — praktické pro „vše kromě těchto“.
- **Vybrat vše se stejnou příponou** (Alt+Num+, nabídka Výběr) označí každý soubor, který sdílí příponu položky pod kurzorem, takže jeden stisk zachytí například všechny soubory `.pdf`.
- **Obnovit výběr** (Num/, nabídka Výběr) vrátí zpět vaši předchozí sadu označení — užitečné, pokud je příkaz zrušil nebo jste označili špatnou skupinu.

## Zkratky

| Akce | Klávesa |
|---|---|
| Přepnout označení, sestoupit dolů | Insert |
| Přepnout označení (aktuální položka) | Mezerník |
| Vybrat vše / Zrušit výběr všeho | Ctrl+Num+ / Ctrl+Num- |
| Vybrat vše (alternativa) | Cmd+A |
| Vybrat skupinu podle masky | Num+ |
| Zrušit výběr skupiny podle masky | Num- |
| Invertovat výběr | Num* |
| Vybrat vše se stejnou příponou | Alt+Num+ |
| Obnovit předchozí výběr | Num/ |

## Poznámky

- Označení a kurzor jsou nezávislé: pohyb kurzoru šipkami nemění, co je označeno.
- Položku nadřazené složky (`..`) nelze nikdy označit.
- Vybrat skupinu, Zrušit výběr skupiny a Invertovat výběr se shodují podle názvu souboru, takže můžete zahrnout nebo vynechat složky podle možností dialogu.
- Po dokončení kopírování, přesunu nebo mazání se úspěšně zpracované položky automaticky odznačí, zatímco ty, které selhaly, zůstanou označené, abyste je mohli zopakovat.
