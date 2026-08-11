---
title: Servery WebDAV
slug: webdav
section: Plugins
order: 130
related: [plugins, ftp-and-sftp, network-shares]
---

Server WebDAV — Nextcloud, ownCloud, Synology, univerzitní úložiště — lze procházet v panelu jako každou složku. Zvolte **Připojit WebDAV…** v nabídce Síť, zadejte URL a server se objeví v aktivním panelu.

Je to plugin: můžete jej vypnout nebo odstranit v **Konfigurace ▸ Pluginy…**.

## Připojení

URL je kolekce, ve které chcete přistát, s vaším uživatelským jménem před hostitelem:

```
https://anna@files.example.com/remote.php/dav/files/anna/
```

Na heslo se ptá zvlášť a putuje přes aplikaci do **klíčenky**, nikdy do konfiguračního souboru. Nechte je při dalším připojení prázdné a použije se uložené.

Každá URL, ke které se připojíte, se zapamatuje — posledních třicet, nejnovější první — a příště se nabídne v rozbalovací nabídce. Tento seznam leží v `~/Library/Application Support/PeachCommander/webdav/sites.json` a obsahuje **pouze URL**; heslo se tam nikdy nezapisuje.

## Používejte https

Ověřování probíhá přes HTTP Basic, což znamená, že vaše uživatelské jméno a heslo cestují zakódované v base64 — zakódované, ne zašifrované. Přes `https://` je spojení chrání. Přes `http://` jsou prakticky nechráněné a vše mezi vámi a serverem si je může přečíst. Prosté `http://` se přijímá, protože server na vlastním počítači nebo v uzavřené laboratorní síti je legitimní případ — dobré výchozí nastavení to ale není.

## Co můžete dělat

Výpis, čtení, zápis, vytváření složek, mazání, přejmenování i přesun fungují — mapují se na WebDAV slovesa `PROPFIND`, `GET`, `PUT`, `MKCOL`, `DELETE` a `MOVE`. Panel na serveru WebDAV se tedy při běžné práci chová jako panel na disku.

## S čím počítat

**Přenosy probíhají po celých souborech.** Soubor se stáhne nebo odešle v jednom kuse; přenos po rozsazích neexistuje, takže přerušený přenos velkého souboru začne znovu, místo aby navázal.

**Kopírování uvnitř serveru jde přes váš Mac.** Plugin nepoužívá sloveso `COPY`, takže duplikace souboru na serveru jej stáhne a znovu nahraje. Na pomalé lince je přesun — který server zvládne sám — mnohem rychlejší než kopírování.

**Nic se nezamyká.** WebDAV `LOCK` se nepoužívá, takže píší-li dva lidé stejný soubor současně, rozhodne ten, kdo uloží poslední — přesně jako na síťovém sdílení bez zamykání.

**Pouze ověřování Basic.** Servery vyžadující Digest, bearer token nebo jednotné přihlášení spojení odmítnou. Mnohé z nich místo toho nabízejí heslo pro konkrétní aplikaci, a to zde funguje.
