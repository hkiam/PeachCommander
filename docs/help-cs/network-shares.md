---
title: Síťová sdílení
slug: network-shares
section: Síť a vzdálený přístup
order: 104
related: [ftp-and-sftp]
---

Peach Commander se umí připojit k souborovým serverům ve vaší místní nebo firemní síti — sdílením SMB (Windows/Samba) a AFP — a zobrazit jejich obsah v panelu přesně jako složku na vašem Macu. Po připojení sdílení v něm můžete procházet, kopírovat, přesouvat, přejmenovávat a otevírat soubory přesně jako místně, včetně kopírování mezi sdílením a vaším druhým panelem.

## Připojení k serveru

1. Klepněte na panel, ke kterému se chcete připojit (připojené sdílení se otevře v aktivním panelu).
2. Stiskněte Cmd+K, nebo zvolte **Síť > Okolní počítače > Připojit síťové sdílení…**.
3. V dialogu **Připojit k serveru** zadejte adresu serveru. Můžete uvést:
   - adresu SMB, například `smb://fileserver/projects`
   - adresu AFP, například `afp://fileserver/projects`
   - cestu ve stylu Windows, například `\\fileserver\projects`
   - jednoduchý název `server/sdílení`
4. Klepněte na Připojit (nebo stiskněte Enter). Pokud server vyžaduje jméno a heslo, macOS zobrazí své obvyklé přihlašovací okno — zadejte tam své údaje.
5. Až je sdílení připravené, aktivní panel jej automaticky otevře. Procházejte a pracujte s ním jako s jakoukoli jinou složkou.

## Odpojení

Připojené sdílení se objeví jako připojený svazek na vašem Macu. Chcete-li jej odpojit, vysuňte jej obvyklým způsobem macOS — například z postranního panelu Finderu nebo ze seznamu zařízení v Peach Commanderu.

## Zkratky

| Akce | Zkratka |
| --- | --- |
| Připojit síťové sdílení… | Cmd+K |

## Poznámky

- Ověření (uživatelské jméno, heslo a případná volba „zapamatovat v mé klíčence“) obstarává obvyklé přihlašovací okno macOS, takže uložená hesla serverů fungují jako ve Finderu.
- Pokud zadáte adresu, kterou nelze rozebrat, Peach Commander požádá o adresu SMB/AFP, cestu ve stylu Windows nebo název `server/sdílení`, a nic se nepřipojí.
- Po potvrzení může připojení chvíli trvat, než macOS sdílení připojí; panel na něj přepne, jakmile bude dostupné.
- Toto se připojuje ke sdíleným zařízením v síti. Chcete-li místo toho dosáhnout serveru FTP, FTPS nebo SFTP, viz související téma níže.
