---
title: Presúvanie a premenovávanie
slug: moving-and-renaming
section: Súbory a priečinky
order: 26
related: [copying-files, multi-rename]
---

Presun premiestni súbory a priečinky namiesto ich duplikovania a premenovanie zmení ich názvy bez zásahu do obsahu. Keďže Peach Commander zobrazuje dva panely vedľa seba, presun je len otázkou výberu toho, čo chcete, v jednom paneli a jeho odoslania do priečinka otvoreného v druhom. Položku môžete tiež premenovať na mieste alebo dať presunutým položkám nové názvy za behu pomocou masky so zástupnými znakmi.

## Presun súborov do druhého panela

1. V zdrojovom paneli otvorte priečinok, ktorý obsahuje položky na presun, a v druhom paneli otvorte cieľový priečinok.
2. Vyberte súbor alebo priečinok na presun. Ak chcete presunúť viacero naraz, najprv ich všetky vyberte (pozri *Výber súborov*).
3. Stlačte F6 alebo zvoľte **Súbor ▸ Presunúť**.
4. Skontrolujte cieľový priečinok zobrazený v dialógu a kliknite na **OK** (alebo stlačte Return), čím presun spustíte.

![Dialóg presunu s poľom cieľovej cesty, možnosťami a začiarkavacím políčkom frontu](screenshots/copy-dialog.png)
*(Obrázok: Dialóg presunu používa rovnaké cieľové pole ako kopírovanie — napíšte cestu alebo pridajte masku so zástupnými znakmi na premenovanie počas presunu.)*

Presuny na tej istej jednotke prebehnú takmer okamžite. Keď je cieľ na inej jednotke, Peach Commander položky skopíruje a originály odstráni až po tom, čo každý súbor bezpečne dorazí.

## Premenovanie na mieste

1. Vyberte jeden súbor alebo priečinok.
2. Stlačte Shift+F6 alebo zvoľte **Súbor ▸ Premenovať**.
3. Upravte názov priamo v paneli a potom potvrďte stlačením klávesu Return alebo zrušte stlačením Esc.

## Premenovanie počas presunu

Cieľové pole v dialógu presunu prijíma masku so zástupnými znakmi, takže položky môžete premenovať počas ich presúvania:

1. Vyberte položky a stlačte F6.
2. Do cieľového poľa pridajte za cieľový priečinok masku názvu, napríklad `/Users/you/Archive/*_backup.*`.
3. `*` zastupuje pôvodný názov a `.*` pôvodnú príponu. Potvrdením presuniete a premenujete v jednom kroku.

## Klávesové skratky

| Akcia | Skratka |
| --- | --- |
| Presunúť do druhého panela | F6 |
| Premenovať na mieste | Shift+F6 |

## Tipy

- Dialóg presunu ponúka rovnaké tlačidlo možností a začiarkavacie políčko frontu na pozadí ako kopírovanie, takže veľké presuny môžete zaradiť do frontu a nechať bežať na pozadí.
- Presun v rámci tej istej jednotky je rýchla operácia na mieste, takže je bezpečný aj pre veľmi veľké priečinky. Presun medzi jednotkami trvá dlhšie, pretože sa dáta najprv skopírujú a potom sa zdroj odstráni.
- Ak chcete premenovať mnoho súborov naraz s číslovaním, hľadaním a nahrádzaním alebo vzormi, použite radšej nástroj na hromadné premenovanie (pozri *Premenovanie mnohých súborov*).
