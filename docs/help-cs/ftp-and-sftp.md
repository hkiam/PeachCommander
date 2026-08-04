---
title: Připojení k FTP a SFTP
slug: ftp-and-sftp
section: Síť a vzdálený přístup
order: 100
related: [downloading-from-url, network-shares]
---

Peach Commander umí procházet vzdálené servery, jako by to byly běžné složky. Po připojení jeden panel zobrazuje vzdálené soubory a vy je kopírujete, přesouváte, přejmenováváte a mažete stejnými klávesami jako místně. Mluví prostým FTP, zabezpečeným FTPS a SFTP/SCP přes SSH, takže dosáhnete na cokoli od klasického webhostingu po zpevněný SSH server. Uložená připojení žijí ve správci připojení a hesla jsou bezpečně uchována ve vaší klíčence macOS, nikoli v samotném připojení.

## Připojení k serveru

1. Otevřete nabídku **Síť** a zvolte **Připojení FTP…** (Ctrl+F) pro otevření správce připojení.
2. Vyberte uložené připojení ze seznamu a klepněte na **Připojit**, nebo klepněte na **Nové** pro vytvoření. Použijte složky v seznamu k seskupení připojení.
3. Pro rychlé jednorázové připojení zvolte **Síť > Nové připojení FTP…** (Ctrl+N) a zadejte adresu přímo.
4. Zadejte heslo, když budete vyzváni; zaškrtněte možnost jeho uložení a uloží se do vaší klíčenky na příště.
5. Až budete hotovi, zvolte **Síť > Odpojit FTP** (Ctrl+Shift+F).

![Správce připojení FTP zobrazující seznam uložených relací s tlačítky Nové, Upravit a Smazat](screenshots/ftp-connection-manager.png)
*(Obrázek: správce připojení uchovává vaše uložené servery; použijte Nové, Upravit a Smazat k jejich správě.)*

Při nastavování připojení můžete zvolit protokol (FTP, FTPS s explicitním AUTH TLS, implicitní FTPS na portu 990 nebo SFTP/SCP), pasivní nebo aktivní režim, vzdálenou a místní počáteční složku, kódování textu a volitelný interval keep-alive, který zabrání nečinným serverům, aby vás odpojily. U SFTP se můžete ověřit svým agentem SSH, heslem nebo souborem soukromého klíče a pro přenosy můžete zvolit SCP. Neznámé hostitelské klíče SSH jsou při prvním použití považovány za důvěryhodné; pokud se klíč známého serveru někdy změní, připojení je odmítnuto, aby vás ochránilo před manipulací.

## Konzole FTP

Chcete-li vidět přesně, co server říká, otevřete konzoli FTP z nabídky **Síť**. Zobrazuje živý protokol řídicího kanálu (vaše heslo je maskováno) a umožňuje zadávat serveru surové příkazy FTP.

![Konzole FTP zobrazující protokol řídicího kanálu a pole pro surové příkazy](screenshots/ftp-console.png)
*(Obrázek: konzole FTP zaznamenává každou výměnu a přijímá surové příkazy, což je praktické pro řešení potíží.)*

## Zkratky

| Akce | Zkratka |
| --- | --- |
| Otevřít správce připojení | Ctrl+F |
| Nové připojení | Ctrl+N |
| Odpojit | Ctrl+Shift+F |
| Změnit režim přenosu | Ctrl+Shift+M |

## Poznámky

- Přerušené stahování pokračuje tam, kde skončilo: je-li soubor částečně na místě a server restart přijme, přenese se jen chybějící zbytek. Server, který jej odmítne, prostě začne soubor znovu. Odesílání pokračuje stejným způsobem, je-li soubor na serveru kratší než odesílaný.
- U serverů FTPS s podepsaným vlastním certifikátem zapněte v nastavení daného připojení možnost přijmout nedůvěryhodný certifikát.
- Proxy SOCKS5 lze nastavit pro každé připojení u prostého FTP. Směrování šifrovaného připojení FTPS přes proxy není podporováno.
- Existující připojení FTP z Total Commanderu lze importovat.
- SCP se používá jen k přenosu souborů; výpis, přejmenování a mazání jdou vždy přes SFTP.
