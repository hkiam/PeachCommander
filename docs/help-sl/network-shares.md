---
title: Omrežne mape
slug: network-shares
section: Omrežje in oddaljeni dostop
order: 104
related: [ftp-and-sftp]
---

Peach Commander se lahko poveže z datotečnimi strežniki v vašem lokalnem ali podjetniškem omrežju — mapami SMB (Windows/Samba) in AFP — ter prikaže njihovo vsebino v podoknu natanko kot mapo na vašem Macu. Ko je mapa povezana, lahko v njej brskate, kopirate, premikate, preimenujete in odpirate datoteke natanko kot lokalno, vključno s kopiranjem med mapo in vašim drugim podoknom.

## Povezovanje s strežnikom

1. Kliknite podokno, s katerim se želite povezati (povezana mapa se odpre v dejavnem podoknu).
2. Pritisnite Cmd+K, ali izberite **Omrežje > Omrežna soseščina > Poveži omrežno mapo…**.
3. V pogovornem oknu **Poveži s strežnikom** vnesite naslov strežnika. Navedete lahko:
   - naslov SMB, na primer `smb://fileserver/projects`
   - naslov AFP, na primer `afp://fileserver/projects`
   - pot v slogu Windows, na primer `\\fileserver\projects`
   - preprosto ime `strežnik/mapa`
4. Kliknite Poveži (ali pritisnite Enter). Če strežnik potrebuje ime in geslo, macOS prikaže svoje običajno okno za prijavo — tam vnesite svoje podatke.
5. Ko je mapa pripravljena, jo dejavno podokno samodejno odpre. Brskajte in delajte z njo kot s katero koli drugo mapo.

## Prekinitev povezave

Povezana mapa se pojavi kot priklopljen nosilec na vašem Macu. Za prekinitev povezave jo izvrzite na običajen način macOS — na primer iz stranske vrstice Finder ali s seznama naprav v Peach Commander.

## Bližnjice

| Dejanje | Bližnjica |
| --- | --- |
| Poveži omrežno mapo… | Cmd+K |

## Opombe

- Preverjanje pristnosti (uporabniško ime, geslo in morebitna možnost »zapomni si v moji ključavnici«) obravnava običajno okno za prijavo macOS, tako da shranjena gesla strežnikov delujejo kot v Finderju.
- Če navedete naslov, ki ga ni mogoče razčleniti, Peach Commander prosi za naslov SMB/AFP, pot v slogu Windows ali ime `strežnik/mapa`, in nič ni priklopljeno.
- Po potrditvi lahko povezava traja trenutek, medtem ko macOS priklaplja mapo; podokno preklopi nanjo, takoj ko postane na voljo.
- To se poveže s skupnimi napravami v omrežju. Za dosego strežnika FTP, FTPS ali SFTP glejte sorodno temo spodaj.
