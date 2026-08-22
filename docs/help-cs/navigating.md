---
title: Pohyb v aplikaci
slug: navigating
section: Začínáme
order: 14
related: [interface-overview, favorites]
---

Peach Commander zobrazuje dvě složky vedle sebe, takže většinu času trávíte přesouváním jednoho panelu ze složky do složky. Můžete otevírat složky, vracet se v hierarchii výš, sledovat, kde jste byli, přímo zadat cestu a přeskakovat rovnou na běžná místa jako Domů, Plocha a Stažené. Každá akce působí na *aktivní* panel — ten se zvýrazněnou lištou cesty.

## Otevírání složek a návrat výš

1. Šipkami posouvejte výběrovou lištu, dokud není zvýrazněna složka.
2. Stiskem **Enter** (nebo dvojklikem) ji otevřete. Tím také vstoupíte do archivů a otevřete soubory ve výchozí aplikaci.
3. O úroveň výš do nadřazené složky přejdete stiskem **Ctrl+PageUp** (nebo **Backspace**).
4. Na začátek aktuálního disku přeskočíte volbou **Přejít ▸ Kořen**.

## Zpět a vpřed

Peach Commander si pamatuje složky, které jste v každém panelu navštívili, stejně jako webový prohlížeč.

- Stiskem **Alt+Vlevo** se vrátíte do předchozí složky a **Alt+Vpravo** přejdete zase vpřed.
- Stiskem **Alt+Dolů** otevřete rozbalovací seznam nedávných složek a přeskočíte na kteroukoli z nich.

## Zadání cesty nebo použití lišty cesty

Lišta cesty v horní části každého panelu ukazuje, kde jste, a slouží také jako způsob, jak se někam rychle dostat.

![Upravitelná lišta cesty zobrazující aktuální složku jako klikatelné segmenty](screenshots/path-bar-crop.png)
*(Obrázek: lišta cesty. Klepnutím na segment přeskočíte do té složky, nebo klepnutím vpravo od cesty zadáte celou cestu.)*

- Klepnutím na kterýkoli segment cesty (například na název nadřazené složky) přeskočíte přímo na něj.
- Klepnutím kamkoli do prázdného místa vpravo od cesty — včetně tužky — ji změníte na textové pole, poté napište nebo vložte cestu a stiskněte Enter. Nemusíte trefit samotnou tužku.
- Klepnutí na lištu cesty zároveň učiní daný panel aktivním.
- Nebo zvolte **Soubor ▸ Přejít do složky…** (**Cmd+Shift+G**), abyste zadali cestu odkudkoli.

## Přeskok na běžná místa

Nabídka **Přejít** přenese aktivní panel do složek, které používáte nejčastěji:

- **Domů**, **Plocha**, **Stažené**, **Koš** a **iCloud Drive**.
- **iCloud Drive** se objeví, když je na vašem Macu nastaven.

## Přepínání panelů a disků

- Stiskem **Tab** přesunete zaměření mezi levým a pravým panelem.
- Lišta disků nad každým panelem uvádí připojené svazky s volným místem; klepnutím na svazek na něj panel přepnete.
- Stiskem **Ctrl+U** prohodíte oba panely (jejich složky si vymění strany); **Ctrl+Shift+U** je prohodí i s jejich kartami.
- Stiskem **Ctrl+=** namíříte druhý panel na stejnou složku jako aktivní (*cíl = zdroj*) — praktické těsně před kopírováním nebo přesunem.
- **Přejít ▸ Levý = pravý** a **Přejít ▸ Pravý = levý** dělají totéž, ale stranu pojmenují výslovně: první zobrazí složku pravého panelu vlevo, druhý složku levého panelu vpravo. Na rozdíl od *cíl = zdroj* nezávisí na tom, který panel je aktivní, takže jejich dvě tlačítka na liště tlačítek znamenají vždy totéž.

## Zkratky

| Akce | Zkratka |
| --- | --- |
| Otevřít složku / soubor pod kurzorem | Enter |
| Přejít do nadřazené složky | Ctrl+PageUp (nebo Backspace) |
| Zpět / Vpřed v historii | Alt+Vlevo / Alt+Vpravo |
| Rozbalovací seznam historie | Alt+Dolů |
| Přejít do složky… (zadat cestu) | Cmd+Shift+G |
| Domů | Cmd+Shift+H |
| Plocha | Cmd+Shift+D |
| Stažené | Option+Cmd+L |
| Přepnout aktivní panel | Tab |
| Globální historie (kterýkoli panel) | Ctrl+Cmd+H |

## Tipy

- Panel se udržuje aktuální sám: soubor, který jiný program v zobrazené složce vytvoří, změní nebo smaže, se objeví sám a kurzor i vaše označení zůstanou tam, kde byly. V **Konfigurace ▸ Možnosti ▸ Zobrazení** to vypněte, pokud se složka, do níž se neustále zapisuje, obnovuje bez přestání.
- Každý panel si drží vlastní historii, takže Zpět a Vpřed ovlivňují jen aktivní stranu.
- Pokud zadaná cesta není platná složka, lišta cesty tiše zachová vaše poslední umístění místo přechodu.
- Koš a iCloud Drive v nabídce Přejít nemají výchozí zkratku, ale můžete ji přiřadit v **Konfigurace ▸ Možnosti ▸ Klávesnice**.
