---
title: Loggvisaren
slug: log-viewer
section: Insticksprogram
order: 128
related: [plugins, viewing-files, searching]
---

Sätt markören på en loggfil och välj **Visa som logg…** för att öppna den i ett fönster byggt för loggar i stället för för text: en rad per rad, nivån på varje rad igenkänd och färgad, ett filter, och en följning som håller jämna steg medan filen fortfarande skrivs.

Det är ett tillägg: du kan stänga av det eller ta bort det under **Konfiguration ▸ Tillägg…**. Utan det visar F3 en logg som vilken annan textfil som helst.

## Varför den öppnas direkt

Filen mappas i minnet och bara ett index över var varje rad börjar byggs, i bakgrunden. Ingenting läses in som text innan det står på skärmen, och bara de rader som faktiskt syns avkodas. En logg på flera gigabyte öppnas lika snabbt som en liten, och att gå till slutet läser inte mitten.

## Nivåer och färg

Varje rad klassificeras — **Fel**, **Varning**, **Info**, **Felsökning**, **Spårning**, eller **Okänd** när formatet inte avslöjar något — och färgas därefter. Standardfärgerna följer det ljusa eller mörka utseendet; ange egna i tilläggets inställningar så används dina.

Kolumnen **Nivå** visar med en blick var felen sitter, och filterfältet smalnar av listan till det du söker. Slå på **Regex** för att filtrera med ett reguljärt uttryck i stället för ren text.

## Följa en fil som fortfarande växer

Slå på **Direkt (rulla automatiskt)** så följer fönstret filens slut medan nya rader kommer: indexet utökas över de tillagda byten i stället för att byggas om, så det förblir billigt hur lång filen än blir. Rulla upp så läser du historik; följningen fortsätter under.

## Hitta rätt

| | |
| --- | --- |
| **Sök…** | Söker i meddelandena; **Sök (markera och hoppa)…** markerar varje träff så att du kan stega mellan dem |
| **Gå till rad…** | Hoppar till ett fysiskt radnummer |
| **Gå till datum/tid…** | Hoppar till första raden från och med en tidsstämpel, t.ex. `2024-01-15 10:23:45` |

Kopieringen vet vad en loggrad är: **Kopiera rad** tar raden under markören, **Kopiera post (alla rader)** tar hela posten när en post sträcker sig över flera rader — en stackspårning till exempel — och **Kopiera markerade rader** tar exakt det du markerat.

## Format

**log4j**, **log4net** och **CSV** är inbyggda, och formatet känns igen automatiskt; fönstret visar vilket det stannade för. Är dina loggar inget av dem lägger du till ett eget under **Loggformat** i inställningarna: ett reguljärt uttryck med namngivna grupper för de delar som betyder något.

```
(?<time>…)   (?<level>…)   (?<msg>…)
```

En rad som uttrycket inte matchar visas ändå — den klassificeras helt enkelt som Okänd i stället för att kastas, för en logg man inte kan läsa är värre än en logg utan färger.

## Visning

**Visa radnummer** och **Radbryt långa rader** finns i inställningarna. Detaljytan under listan visar alltid hela texten för den markerade posten, radbruten, vad listan än gör.
