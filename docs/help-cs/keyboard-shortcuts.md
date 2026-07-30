---
title: Klávesnice a zkratky
slug: keyboard-shortcuts
section: Přizpůsobení
order: 112
related: [keyboard-shortcuts-reference, settings]
---

Peach Commander je vytvořen tak, aby se ovládal z klávesnice. Dodává se se dvěma hotovými schématy zkratek a umožňuje znovu přiřadit jakýkoli příkaz klávesám, které preferujete. Pokud přicházíte z klasického dvoupanelového správce souborů, můžete si ponechat klávesy, které už znáte; pokud raději používáte známé kombinace Mac, přepněte na schéma macOS jedním klepnutím. Prohledávatelný prohlížeč příkazů umožňuje objevit vše, co aplikace umí, a spustit jakýkoli příkaz podle názvu.

## Přepnutí schématu klávesnice

1. Otevřete nabídku **Konfigurace**.
2. Zvolte **Schéma klávesnice**, poté vyberte jedno:
   - **TC Classic** (výchozí) zachovává tradiční klávesy, s kombinacemi založenými na Ctrl jako Ctrl+R pro obnovení panelu.
   - **macOS Native** mapuje stejné akce na známé klávesy Mac tam, kde to dává smysl, například Cmd+C pro kopírování souborů a Cmd+F pro hledání.
3. Zaškrtnutí ukazuje aktivní schéma. Změna se projeví ihned v nabídkách i liště zkratek.

## Přizpůsobení zkratek

1. Zvolte **Konfigurace > Klávesové zkratky…**.
2. Najděte příkaz pomocí vyhledávacího pole, poté vyberte jeho řádek.
3. Klepněte na **Zaznamenat…** a stiskněte požadovanou kombinaci kláves. Přiřadí se ihned.
4. Pokud tuto kombinaci již používal jiný příkaz, upozornění vám sdělí, kterému příkazu byla odebrána.
5. Použijte **Vymazat** k odstranění zkratky příkazu, nebo **Obnovit výchozí** k zahození všech vašich změn a návratu k původním klávesám schématu.

![Editor klávesových zkratek uvádějící příkazy s jejich přiřazenými klávesami](screenshots/keys-editor.png)
*(Obrázek: najděte příkaz, poté použijte Zaznamenat, Vymazat nebo Obnovit výchozí ke změně jeho zkratky.)*

## Procházení všech příkazů

1. Zvolte **Konfigurace > Prohlížeč příkazů…**.
2. Pište do vyhledávacího pole pro filtrování podle názvu, kategorie nebo popisu.
3. Poklepejte na příkaz, nebo jej vyberte a klepněte na **Spustit**, abyste jej provedli na aktivním panelu.

![Prohlížeč příkazů zobrazující prohledávatelný seznam příkazů](screenshots/command-browser.png)
*(Obrázek: každý příkaz v jediném prohledávatelném seznamu, s krátkým popisem každého.)*

## Zkratky

| Akce | Cesta v nabídce |
|---|---|
| Zvolit klasické schéma | Konfigurace > Schéma klávesnice > TC Classic |
| Zvolit schéma Mac | Konfigurace > Schéma klávesnice > macOS Native |
| Upravit zkratky | Konfigurace > Klávesové zkratky… |
| Procházet všechny příkazy | Konfigurace > Prohlížeč příkazů… |
| Obnovit aktivní panel | F2 (také Ctrl+R) |

## Poznámky

- Vaše vlastní zkratky se ukládají automaticky a nasazují se nad aktivní schéma. Přepnutí schémat zachová vaše osobní přepisy.
- Příkazy nedostupné v aktuálním kontextu se objeví ztlumené jak v editoru zkratek, tak v prohlížeči příkazů.
- Chcete-li používat funkční klávesy (F1–F12) přímo, zapněte **Používat klávesy F1, F2 atd. jako standardní funkční klávesy** v Nastavení systému > Klávesnice. Jinak podržte klávesu **Fn** spolu s funkční klávesou.
