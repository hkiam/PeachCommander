---
title: Súkromie a bezpečnosť
slug: privacy-and-security
section: macOS a súkromie
order: 132
related: [ftp-and-sftp, troubleshooting]
---

Peach Commander je postavený tak, aby vám neprekážal a udržal vaše údaje na vašom Macu. Heslá sa odovzdávajú zväzku kľúčov macOS, informácie o zlyhaniach nikdy neopustia váš počítač bez vášho súhlasu a aplikácia nezhromažďuje žiadnu analytiku používania. Táto téma vysvetľuje, kde žijú vaše citlivé informácie a ako udeliť jediné systémové povolenie, ktoré správca súborov potrebuje na svoju prácu.

## Kde sa ukladajú heslá

Akékoľvek heslo alebo prístupovú frázu kľúča, ktoré uložíte — pre pripojenie FTP alebo SFTP, alebo na otvorenie heslom chráneného archívu — sa zapíše do **zväzku kľúčov** macOS, toho istého bezpečného úložiska, ktoré systém používa na vaše prihlásenia do Wi-Fi a na webové stránky. Heslá sa nikdy nezapisujú do vlastných nastavení alebo súborov pripojení Peach Commanderu v otvorenom texte.

1. Keď uložíte heslo pripojenia alebo archívu, vyberte možnosť jeho zapamätania.
2. Heslo je uložené vo vašom prihlasovacom zväzku kľúčov, chránené vaším účtom.
3. Na neskoršie preskúmanie alebo odstránenie uloženého hesla otvorte aplikáciu **Prístup do zväzku kľúčov** (v Aplikácie ▸ Nástroje) a vyhľadajte názov pripojenia.

## Udelenie Úplného prístupu k disku

macOS udržiava niektoré umiestnenia súkromné — údaje Mail, Správy a iných aplikácií vnútri vášho priečinka Knižnica — kým výslovne nepovolíte prístup. Keďže správca súborov je určený na dosiahnutie každého súboru, Peach Commander žiada o **Úplný prístup k disku**. Aplikácia pracuje ďalej so zníženým prístupom, kým ho neudelíte; len neuvidíte tie chránené priečinky.

1. Vyberte **Príkazy ▸ Úplný prístup k disku…**, alebo kliknite na **Otvoriť Systémové nastavenia**, keď sa aplikácia ponúkne, že vás pri spustení prevedie.
2. V **Systémové nastavenia ▸ Súkromie a bezpečnosť ▸ Úplný prístup k disku** zapnite prepínač vedľa Peach Commanderu.
3. Reštartujte aplikáciu, ak budete vyzvaní.

## Správy o zlyhaní zostávajú lokálne

Ak sa aplikácia nečakane ukončí, macOS zapíše správu o zlyhaní do vášho vlastného priečinka diagnostiky. Pri ďalšom spustení si ju Peach Commander všimne a ponúkne, že vám pomôže podať správu o chybe — ale iba s vaším súhlasom.

- Môžete **Zobraziť vo Finderi** na zobrazenie správy, alebo **Skopírovať správu do schránky** na jej vlastné vloženie do správy o chybe.
- Nič sa nikdy neprenáša automaticky a nie je zapojená žiadna služba tretej strany na hlásenie zlyhaní.

## Poznámky

- **Žiadna telemetria.** Peach Commander nesleduje vašu aktivitu a neposiela analytiku používania nikam.
- **Znížený prístup je bezpečný.** Ak preskočíte Úplný prístup k disku, aplikácia stále prehliada a spravuje súbory, ktoré normálne vidíte; skryté sú len umiestnenia chránené systémom.
- **Vy ovládate uložené heslá.** Keďže poverenia žijú vo zväzku kľúčov, spravujete ich a odvolávate štandardnými nástrojmi macOS namiesto vnútri aplikácie.
