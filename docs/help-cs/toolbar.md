---
title: Lišta tlačítek
slug: toolbar
section: Přizpůsobení
order: 110
related: [keyboard-shortcuts, settings, macros]
---

Lišta tlačítek je pruh ikonových tlačítek podél horní části okna. Každé tlačítko je zkratka na jedno klepnutí, kterou si sami definujete: spustit vestavěný příkaz, spustit externí program nebo aplikaci, přeskočit do složky, nebo otevřít celou podlištu dalších tlačítek. Je to nejrychlejší způsob, jak mít akce, které používáte nejvíce, na dosah, a můžete ji přizpůsobit přesně způsobu, jakým pracujete.

## Přizpůsobení lišty tlačítek

1. Zvolte **Konfigurace > Přizpůsobit lištu nástrojů…**, nebo klepněte na lištu pravým tlačítkem a zvolte **Upravit lištu tlačítek…**.
2. Seznam vlevo zobrazuje aktuální tlačítka. Použijte **+** pro přidání tlačítka, **—** pro přidání oddělovače, **−** pro odebrání vybraného tlačítka a **↑ / ↓** pro změnu pořadí.
3. Vyberte tlačítko a vyplňte formulář vpravo:
   - **Příkaz** — zadejte vestavěný příkaz, nebo klepněte na **Vybrat…** pro výběr ze seznamu. Můžete také zadat cestu programu nebo aplikace, složku k otevření, nebo jinou lištu tlačítek k použití jako podlišta.
   - **Popisek** — štítek a nápověda zobrazené pro tlačítko.
   - **Parametry** a **Počáteční cesta** — předané externím programům. Zástupné symboly jako `%P` (zdrojová složka), `%N` (aktuální soubor) a `%S` (vybrané soubory) se vyplní při spuštění tlačítka.
   - **Ikona** — zvolte SF Symbol nebo použijte vlastní ikonu souboru či aplikace; zapněte **jen ikona** pro skrytí popisku.
4. Klepněte na **Uložit**. Pruh se ihned znovu načte.

![Lišta tlačítek podél horní části okna s ikonovými tlačítky](screenshots/button-bar-crop.png)
*(Obrázek: lišta tlačítek se nachází nad panely souborů; každé tlačítko spouští příkaz, program, složku nebo podlištu.)*

## Podlišty a přetečení

Tlačítko může otevřít *podlištu* — druhou sadu tlačítek přeloženou přes první. Klepnutím na ni sestoupíte; tlačítko **◀** vlevo vás vrátí na předchozí lištu. Když je tlačítek více, než se vejde do šířky okna, ta navíc se sbalí za šipku **»** na pravém konci; klepnutím na ni se k nim dostanete.

## Přidání programu přetažením na lištu

Abyste dali nástroj na lištu, nemusíte otevírat editor. Přetáhněte program, aplikaci nebo skript z panelu — nebo z Finderu — na **volné místo** lišty. Čárka ukáže, kam přistane; po puštění tam vznikne tlačítko.

- **Programy, aplikace a skripty** se stanou tlačítkem, které je spustí nad vaším aktuálním výběrem: parametry nového tlačítka jsou `%S`, tedy názvy vybraných souborů. Pokud nástroj nemá dostávat argumenty, vyprázdněte toto pole v editoru.
- **Složky** se stanou tlačítkem, které do nich přejde — a které do nich kopíruje soubory, když je na ně později pustíte.
- Co nelze spustit, je odmítnuto: běžný dokument nemá právo ke spuštění a tlačítko pro něj by při kliknutí jen selhalo.

Puštění na **existující** tlačítko si zachovává svůj význam: tlačítko se spustí s puštěnými soubory. Nové vznikne jen na volném místě.

## Přetažení souborů na tlačítko

Soubory nebo složky můžete přetáhnout přímo na tlačítko:

- **Tlačítko složky** — přetažené položky se zkopírují do té složky na pozadí.
- **Tlačítko programu** — program se spustí s přetaženými položkami jako svým výběrem.
- **Tlačítko příkazu** — příkaz se spustí jako obvykle.

## Skrytí lišty tlačítek

Zvolte **Zobrazení > Lišta tlačítek**, chcete-li lištu skrýt, a znovu, chcete-li ji vrátit. Stejný přepínač je na stránce **Rozvržení** v nastavení a volba se pamatuje.

## Svislá lišta tlačítek

Chcete-li přesunout pruh z horní části okna do sloupce podél levé strany, zvolte **Zobrazení > Svislá lišta tlačítek**. Zvolte ji znovu pro návrat k vodorovnému pruhu.

## Poznámky

- Lišta je uložena ve standardním souboru lišty tlačítek kompatibilním s Total Commanderem, takže lišty, které už máte, lze znovu použít.
- Těmto akcím není ve výchozím nastavení přiřazena žádná klávesová zkratka, ale můžete přidat vlastní — viz [Klávesové zkratky](keyboard-shortcuts).
- Tlačítko bez ikony a bez příkazu se zobrazí jako prostý oddělovač, praktický pro seskupení souvisejících tlačítek.
