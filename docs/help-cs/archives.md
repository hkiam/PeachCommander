---
title: Práce s archivy
slug: archives
section: Archivy
order: 80
related: [copying-files]
---

Peach Commander zachází s archivy jako se složkami. Můžete vstoupit dovnitř ZIP, TAR nebo jiného podporovaného archivu, procházet jeho obsah a kopírovat soubory ven — to vše bez nutnosti nejprve rozbalit na disk. Když chcete vytvořit archiv, příkaz Zabalit sdruží váš výběr do formátu ZIP, 7z, TAR nebo jiného, s volitelným šifrováním a rozdělenými svazky. To se hodí ke sdružení souborů k odeslání, zmenšení složky pro uložení nebo k nahlédnutí do staženého souboru, než se rozhodnete jej rozbalit.

## Procházení archivu jako složky

1. V panelu přesuňte kurzor na soubor archivu (například `.zip` nebo `.tar.gz`).
2. Stiskem Enter nebo Ctrl+PageDown vstupte dovnitř, stejně jako byste otevřeli složku.
3. Obsah procházejte běžným způsobem. Stiskem Backspace nebo Ctrl+PageUp se vrátíte nahoru a archiv opustíte.
4. K vytažení souborů je vyberte a zkopírujte (F5) do druhého panelu.

![Procházení uvnitř archivu, jako by šlo o složku](screenshots/archive-browse.png)
*(Obrázek: Otevřený archiv zobrazený jako běžný výpis složky, s jeho soubory připravenými ke zkopírování ven.)*

ZIP, TAR a TAR komprimovaný pomocí gzip se čtou přímo. Další formáty, jako je CPIO, ISO, CAB, LZH, XAR a PAX, se čtou pomocí vestavěných systémových nástrojů. Šifrované archivy ZIP (klasické i AES) lze otevřít, když zadáte heslo.

## Zabalení souborů do nového archivu

1. V aktivním panelu vyberte soubory a složky, které chcete zahrnout.
2. Zvolte Soubor ▸ Zabalit… nebo stiskněte Alt+F5. (K zabalení a následnému smazání originálů použijte Alt+Shift+F5.)
3. V dialogu zvolte formát archivu (ZIP, 7z, TAR, tar.gz, bzip2, xz nebo RAR), úroveň komprese a místo uložení.
4. Volitelně zapněte šifrování AES-256 a nastavte heslo, nebo archiv rozdělte na svazky pevné velikosti.
5. Potvrzením archiv vytvořte.

![Dialog Zabalit s možnostmi formátu, komprese, šifrování a rozdělení](screenshots/pack-dialog.png)
*(Obrázek: Dialog Zabalit, kde vyberete formát a nastavíte možnosti šifrování a rozdělení na svazky.)*

## Rozbalení nebo test archivu

1. Umístěte archiv, který chcete rozbalit, do aktivního panelu a cílovou složku do druhého panelu.
2. Zvolte Soubor ▸ Rozbalit… nebo stiskněte Alt+F9, poté potvrďte cíl.
3. Ke kontrole archivu na poškození bez rozbalení zvolte Soubor ▸ Otestovat archiv.

## Úprava ZIP na místě

Soubory uvnitř existujícího ZIP můžete přidávat nebo odebírat bez rozbalení. Otevřete ZIP jako složku a poté běžným způsobem zkopírujte soubory dovnitř nebo je smažte — změna se zapíše přímo zpět do archivu.

## Klávesové zkratky

| Akce | Zkratka |
| --- | --- |
| Vstoupit do archivu pod kurzorem | Enter nebo Ctrl+PageDown |
| Opustit archiv (jít nahoru) | Backspace nebo Ctrl+PageUp |
| Zabalit | Alt+F5 |
| Zabalit a smazat originály | Alt+Shift+F5 |
| Rozbalit | Alt+F9 |

## Poznámky

- Balení do 7z, xz, bzip2 a RAR se spoléhá na externí nástroje. RAR zejména vyžaduje nainstalovaný proprietární program RAR; bez něj je tento formát nedostupný.
- Úprava ZIP na místě přepisuje celý archiv, takže časové značky úpravy souborů uvnitř nejsou zachovány.
- Velmi velcí jednotliví členové jsou při rozbalování omezeni na 512 MiB. Rozbalování lze během běhu zrušit.
- Mimořádně velké archivy (ZIP64) nejsou podporovány.
