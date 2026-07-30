---
title: Stahování z URL
slug: downloading-from-url
section: Síť a vzdálený přístup
order: 102
related: [ftp-and-sftp]
---

Peach Commander umí stáhnout soubor přímo z webové adresy HTTP nebo HTTPS do aktivního panelu, aniž byste otevírali prohlížeč. Vložte odkaz, potvrďte název, pod kterým bude uložen, a stahování běží samo — s obnovením při výpadku spojení, dávkovým stahováním mnoha odkazů naráz a volitelným ověřením kontrolního součtu, abyste věděli, že soubor dorazil neporušený.

## Stažení souboru

1. Otevřete složku panelu, kam chcete soubor umístit.
2. Zvolte **Síť > Stáhnout z URL** nebo stiskněte Cmd+Shift+D.
3. Vložte webovou adresu do pole **URL**. Pokud jste odkaz předtím zkopírovali, vyplní se za vás.
4. Zkontrolujte název **Uložit jako** — je navržen z odkazu a můžete jej volně upravit.
5. Klikněte na **Stáhnout**.

![Dialog Stáhnout z URL s odkazem, upravitelným názvem souboru a možnostmi](screenshots/download-url.png)
*(Obrázek: Dialog stahování — vložte odkaz, upravte název a nastavte volitelné ověření, přihlašovací údaje, hlavičky nebo proxy.)*

Ve výchozím nastavení běží stahování **na pozadí**, takže můžete během přenosu dále pracovat v panelech. Vypnutím **Stahovat na pozadí** na něj počkáte, nebo zapnutím **Zařadit na později** jej nastavíte, aniž byste jej zatím spustili.

## Stažení několika souborů naráz

Vložte do pole **URL** jednu webovou adresu na řádek. Když je přítomno více odkazů, název každého souboru se odvodí automaticky z jeho odkazu a pole **Uložit jako** a **Ověřit** pro jednotlivé soubory se vypnou.

## Obnovení přerušeného stahování

Pokud je přenos přerušen, Peach Commander ponechá to, co již přijal, v dočasném souboru `.part`. Opětovné spuštění téhož stahování naváže tam, kde přestalo, kdykoli to server podporuje, místo aby začínalo znovu. Soubor `.part` se přejmenuje na konečný název až po úspěšném dokončení stahování.

## Klávesové zkratky

| Akce | Zkratka |
| --- | --- |
| Stáhnout z URL | Cmd+Shift+D |

## Tipy

- **Ověřte soubor.** U jednotlivého stahování vložte do pole **Ověřit** očekávaný kontrolní součet **SHA-256**. Po přenosu se kontrolní součet souboru porovná s ním, takže můžete věřit, že soubor odpovídá tomu, co vydavatel uvedl.
- **Vyžadováno přihlášení?** Zadejte uživatelské jméno a heslo do polí **Ověření** u webů, které používají základní autentizaci. Pro přístup založený na tokenu přidejte do pole **Hlavičky** řádek `Authorization: Bearer …`.
- **Vlastní hlavičky.** Přidejte jednu hlavičku na řádek do pole **Hlavičky**, například `Referer: …` nebo `Cookie: …`, pro odkazy, které fungují jen s konkrétními hlavičkami požadavku.
- **Proxy.** Nasměrujte stahování přes proxy HTTP nebo SOCKS5 vyplněním hostitele, portu a typu **Proxy**.
- **Nedůvěryhodné certifikáty.** Volbu **Povolit nedůvěryhodný certifikát** zapněte pouze pro web, kterému důvěřujete a který používá vlastnoručně podepsaný certifikát; u daného stahování vypne běžnou bezpečnostní kontrolu HTTPS.
- **Poznámka:** Cmd+Shift+D se používá i jinde pro přechod do složky Plocha; pokud zkratka tento dialog neotevře, použijte místo toho z nabídky **Síť > Stáhnout z URL**.
