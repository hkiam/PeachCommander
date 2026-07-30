---
title: Pripojenie k FTP a SFTP
slug: ftp-and-sftp
section: Sieť a vzdialený prístup
order: 100
related: [downloading-from-url, network-shares]
---

Peach Commander dokáže prehliadať vzdialené servery, akoby to boli bežné priečinky. Po pripojení jeden panel zobrazuje vzdialené súbory a vy ich kopírujete, presúvate, premenúvate a mažete tými istými klávesmi, aké používate lokálne. Hovorí obyčajným FTP, zabezpečeným FTPS a SFTP/SCP cez SSH, takže dosiahnete na čokoľvek od klasického webhostingu po spevnený server SSH. Uložené pripojenia žijú v správcovi pripojení a heslá sú bezpečne uchované vo vašom zväzku kľúčov macOS, nie v samotnom pripojení.

## Pripojenie k serveru

1. Otvorte ponuku **Sieť** a vyberte **Pripojenie FTP…** (Ctrl+F) na otvorenie správcu pripojení.
2. Vyberte uložené pripojenie zo zoznamu a kliknite na **Pripojiť**, alebo kliknite na **Nové** na jeho vytvorenie. Použite priečinky v zozname na zoskupenie pripojení.
3. Pre rýchle jednorazové pripojenie vyberte **Sieť > Nové pripojenie FTP…** (Ctrl+N) a zadajte adresu priamo.
4. Zadajte heslo, keď budete vyzvaní; zaškrtnite možnosť jeho uloženia a uloží sa do vášho zväzku kľúčov na nabudúce.
5. Keď skončíte, vyberte **Sieť > Odpojiť FTP** (Ctrl+Shift+F).

![Správca pripojení FTP zobrazujúci zoznam uložených relácií s tlačidlami Nové, Upraviť a Odstrániť](screenshots/ftp-connection-manager.png)
*(Obrázok: správca pripojení uchováva vaše uložené servery; použite Nové, Upraviť a Odstrániť na ich spravovanie.)*

Pri nastavovaní pripojenia môžete vybrať protokol (FTP, FTPS s explicitným AUTH TLS, implicitný FTPS na porte 990, alebo SFTP/SCP), pasívny alebo aktívny režim, vzdialený a lokálny počiatočný priečinok, kódovanie textu a voliteľný interval keep-alive, ktorý zabráni nečinným serverom, aby vás odpojili. Pri SFTP sa môžete overiť svojím agentom SSH, heslom alebo súborom súkromného kľúča a na prenosy môžete vybrať SCP. Neznáme hostiteľské kľúče SSH sú pri prvom použití považované za dôveryhodné; ak sa kľúč známeho servera niekedy zmení, pripojenie sa odmietne, aby vás ochránilo pred manipuláciou.

## Konzola FTP

Na zobrazenie, čo presne server hovorí, otvorte konzolu FTP z ponuky **Sieť**. Zobrazuje živý protokol riadiaceho kanála (vaše heslo je maskované) a umožňuje zadávať serveru surové príkazy FTP.

![Konzola FTP zobrazujúca protokol riadiaceho kanála a pole na surové príkazy](screenshots/ftp-console.png)
*(Obrázok: konzola FTP zaznamenáva každú výmenu a prijíma surové príkazy, čo je praktické na riešenie problémov.)*

## Skratky

| Akcia | Skratka |
| --- | --- |
| Otvoriť správcu pripojení | Ctrl+F |
| Nové pripojenie | Ctrl+N |
| Odpojiť | Ctrl+Shift+F |
| Zmeniť režim prenosu | Ctrl+Shift+M |

## Poznámky

- Prerušené sťahovania a nahrávania môžu pokračovať tam, kde skončili, namiesto začatia odznova.
- Pri serveroch FTPS so samopodpísaným certifikátom zapnite v nastaveniach daného pripojenia možnosť prijať nedôveryhodný certifikát.
- Proxy SOCKS5 možno nastaviť pre každé pripojenie pri obyčajnom FTP. Smerovanie šifrovaného pripojenia FTPS cez proxy nie je podporované.
- Existujúce pripojenia FTP z Total Commanderu možno importovať.
- SCP sa používa iba na prenos súborov; výpis, premenovanie a mazanie idú vždy cez SFTP.
