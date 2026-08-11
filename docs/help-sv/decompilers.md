---
title: Dekompilera Java och .NET
slug: decompilers
section: Plugins
order: 131
related: [plugins, viewing-files, searching]
---

Tryck **F3** på en kompilerad fil och se källkod i stället för byte. Två tillägg gör det — ett för Java (`.class`, `.jar`, `.apk`, `.dex`) och ett för .NET (`.dll`, `.exe`, `.winmd`, `.netmodule`) — och de beter sig likadant, så den här sidan täcker båda. Vart och ett kan stängas av eller tas bort för sig under **Konfiguration ▸ Tillägg…**.

Ett arkiv visas som ett träd av sina klasser; en ensam klass som en fil. **Dekompilera till källkod** i menyn Kommandon skriver ut resultatet och lägger det i en panel, så att du kan söka, jämföra och kopiera i det som i vilken annan källkodsmapp som helst.

## Motorn installerar du själv

Ingen dekompilator följer med och ingenting hämtas åt dig. Det är medvetet, av två skäl: JD-Core, den mest kända Java-dekompilatorn, är GPLv3 och kunde inte levereras inuti en Apache-2.0-app — och motorer blir bättre, så att byta en borde inte kräva en ny version av Peach Commander.

**Motormapp…** i visaren öppnar mappen de hör hemma i. README-filen där namnger varje motor och dess licens.

| | |
| --- | --- |
| Java | CFR, Vineflower, Procyon, jadx (för Androids `.dex` och `.apk`) och `javap` för ren bytekod |
| .NET | ILSpy, och `monodis` för IL |

**Kontrollera motorer** kör varje motors versionskommando och skiljer på tre saker: installerad och fungerande, inte installerad, och *installerad men oförmögen att köra* — ett Java-verktyg utan JDK finns där och startar ändå inte, och bara att verkligen köra det avslöjar detta.

En motor beskrivs av data och inte av kod, så du kan lägga till en själv:

```
[cfr]
kinds  = class, jar
tool   = java
args   = -jar {engine} {input}
engine = ~/Library/Application Support/PeachCommander/decompilers/cfr.jar
output = stdout
```

När fler än en motor klarar en fil används den första tillgängliga om du inte väljer en. Med två installerade visar **Jämför** båda resultaten sida vid sida — användbart när den ena motorn ger upp på en metod som den andra klarar.

## Söka i kompilerad kod

**Sök i alla klasser** går igenom den dekompilerade texten i stället för byten, så att du kan hitta en stränglitteral eller ett metodnamn i en JAR.

Att dekompilera under en *innehållssökning* över många filer är en egen inställning, av som förval: att producera texten kan innebära att motorn körs en gång per klass, vilket på en långsam maskin inte är något rimligt att lägga på en sökning. Huvudsökrutan frågar separat; här nekas det också.

## Cache och gränser

Resultat cachas, för att dekompilera samma klass två gånger är rent väntande. I inställningarna finns hur många dagar resultat behålls och en **storleksgräns** för cachen; **Töm cachen nu** tömmer den och rapporterar hur mycket som frigjordes.

Två tidsgränser skyddar mot en motor som inte blir klar: en för en enda klass eller typ, en för ett helt arkiv. Båda accepterar 0, vilket betyder ”använd motorns egen standard”.
