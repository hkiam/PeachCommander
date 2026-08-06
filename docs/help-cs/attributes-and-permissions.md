---
title: Atributy a oprávnění
slug: attributes-and-permissions
section: Pokročilé nástroje
order: 96
related: [file-utilities]
---

Peach Commander vám umožňuje prohlížet a měnit nízkoúrovňová metadata souborů a složek, která Finder z větší části skrývá: oprávnění POSIX pro čtení/zápis/spuštění, vlastníka a skupinu, data úpravy a vytvoření, příznaky macOS jako skrytý a uzamčený a rozšířené atributy. Můžete také upravit seznam řízení přístupu (ACL) souboru pro jemně odstupňovaná pravidla podle jednotlivých uživatelů nebo skupin, vytvářet odkazy a aliasy směřující na jiné položky a připojovat vlastní komentáře. Tyto nástroje jsou určeny pokročilým uživatelům, kteří potřebují přesnou kontrolu nad tím, jak se položky chovají a kdo se jich může dotknout.

## Změna atributů

1. V aktivním panelu vyberte jednu nebo více položek.
2. Zvolte **Soubor > Změnit atributy…**.
3. Nastavte, co potřebujete: přepněte políčka čtení/zápis/spuštění pro vlastníka, skupinu a všechny (nebo přímo zadejte osmičkovou hodnotu), změňte vlastníka nebo skupinu, přepněte příznaky skrytý nebo uzamčený a nastavte datum úpravy nebo vytvoření. Použijte **Použít aktuální** pro aktuální čas nebo zkopírujte datum z jiného souboru.
4. K použití stejné změny napříč obsahem složky zapněte rekurzivní možnost a zvolte, zda ovlivní soubory, složky nebo obojí.
5. Kliknutím na OK změnu spustíte. Rekurzivní změny běží jako úloha na pozadí s ukazatelem průběhu.

![Dialog Změnit atributy zobrazující mřížku oprávnění, příznaky a pole dat](screenshots/attributes-dialog.png)
*(Obrázek: Dialog Změnit atributy. Smíšené hodnoty napříč výběrem více souborů se zobrazují jako pomlčka, dokud je nenastavíte.)*

## Úprava ACL

Pro pravidla přesahující základní model vlastník/skupina/všichni upravte seznam řízení přístupu položky.

1. Otevřete **Soubor > Změnit atributy…** a odtud otevřete editor ACL.
2. Každý řádek je jedno pravidlo: uživatel nebo skupina, které se týká, zda povoluje nebo zakazuje, a jaká oprávnění (čtení, zápis, mazání a tak dále) uděluje.
3. Přidejte, odeberte nebo upravte řádky a poté uložením zapište seznam zpět k položce.

## Vytváření odkazů, aliasů a komentářů

- **Soubor > Vytvořit symbolický odkaz…** vytvoří symbolický odkaz (symlink), který ukazuje na položku pod kurzorem pomocí cesty.
- **Soubor > Vytvořit pevný odkaz…** vytvoří pevný odkaz na stejná data souboru. Pevné odkazy fungují pouze pro soubory na stejném svazku.
- **Soubor > Vytvořit alias…** vytvoří alias macOS, který dokáže sledovat i Finder.
- **Soubor > Upravit komentář…** (Ctrl+Z) otevře textový editor pro komentář k souboru. Komentáře lze zobrazit ve vlastním sloupci a ve stavových popiscích.

## Klávesové zkratky

| Akce | Zkratka |
| --- | --- |
| Upravit komentář | Ctrl+Z |

## Poznámky

- Změna vlastníka nebo skupiny obvykle vyžaduje oprávnění, která jako běžný uživatel nemáte; když k tomu dojde, změna se nahlásí jako neúspěšná namísto provedení a zbytek vašich změn stále projde.
- Komentáře se ukládají do souboru `descript.ion` vedle vašich položek a v závislosti na nastavení je lze uchovávat i jako komentáře Finderu. Při zobrazení komentáře se čtou oba. Formát je týž, jaký používá Total Commander a několik dalších správců souborů, takže komentář napsaný zde je tam čitelný.
- Komentáře s **zlomy řádků** a komentáře v **UTF-16** se čtou a zapisují tak, jak to dělá Total Commander: zlom řádku je uložen jako `\n` následované dvěma značkovacími bajty, které si TC pro tento účel nechal zaregistrovat, a soubor, který byl v UTF-16, v UTF-16 zůstane, když v něm změníte jeden komentář. Bez této značky jsou `\n` v cizím komentáři dva napsané znaky a zůstanou nedotčené.
- **Komentář jde s souborem.** Kopírování, přesun i přejmenování jej vezmou s sebou — při přesunu a kopírování do `descript.ion` cílové složky, při přejmenování na nový název, i když přejmenování vrátíte. Výjimkou je připojení souboru na konec jiného: soubor, který zůstává, si ponechá svůj vlastní komentář, protože je stále týmž souborem.
- Je-li zapnutý modul Poznámky, jeho postranní panel zobrazuje a upravuje týž komentář nad textem poznámky, aby nebyla dvě místa pro totéž.
- Symbolický odkaz i alias oba ukazují na cíl, ale symbolický odkaz ukládá prostou cestu, zatímco alias ukládá odkaz macOS, který funguje dál i po přesunu nebo přejmenování cíle. Pevný odkaz je druhý název pro stejná data souboru, nikoli ukazatel.
