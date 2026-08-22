---
title: Odpravljanje težav
slug: troubleshooting
section: Pomoč in odpravljanje težav
order: 140
related: [privacy-and-security, known-limitations]
---

Ta tema pokriva težave, na katere ljudje najpogosteje naletijo: macOS blokira dostop do določenih map, mapa, ki se zdi obtičala pri stari vsebini, varni strežnik FTP, ki zavrača povezavo, in pakiranje v RAR. Vsak razdelek vam pove, kaj se dogaja in kako to popraviti.

## macOS prosi za dovoljenje, ali mape izgledajo prazne

Nekatere lokacije — kot so vaša mapa `~/Library`, mape drugih uporabnikov in sistemska območja — so zaščitene z macOS in ostanejo skrite, dokler ne podelite dostopa. Peach Commander zazna, kdaj se to zgodi, in ponudi, da vas usmeri k pravi nastavitvi.

Takšna mapa ni prikazana kot prazna, temveč je zavrnjena, in podokno to pove: *macOS ohranja <mapo> zasebno — glejte Ukazi ▸ Polni dostop do diska…*. To je vredno poimenovati, saj nič pri tem ni videti kot težava z dovoljenji: mapa je vidna, vaša je in njena dovoljenja pravijo, da jo lahko berete. Na poti je le macOS sam, in skrbniške pravice tega ne spremenijo. Podokno ostane v mapi, ki jo je že prikazovalo.

1. Ko ste pozvani, izberite odpiranje Sistemskih nastavitev, ali jih odprite sami.
2. Pojdite v Zasebnost in varnost, nato Popolni dostop do diska.
3. Vklopite stikalo ob Peach Commander. Če ni na seznamu, uporabite gumb Dodaj, da ga dodate.
4. Zaprite in znova odprite Peach Commander, da novo dovoljenje začne veljati.

Peach Commander ne teče znotraj omejenega peskovnika, tako da lahko po podelitvi Popolnega dostopa do diska brska in upravlja datoteke natanko kot Finder.

## Mapa ne prikazuje nedavnih sprememb

Podokna se običajno sama posodobijo, ko se datoteke spremenijo na disku. Če je mapo spremenil drug program, je na omrežnem nosilcu, ali preprosto izgleda zastarela, jo osvežite ročno.

1. Kliknite podokno, ki ga želite posodobiti.
2. Pritisnite F2 (ali Ctrl+R), da znova preberete to mapo.

Omrežni in priklopljeni nosilci ne poročajo vedno o spremembah macOS, tako da je ročna osvežitev tam zanesljiva rešitev.

## Strežnik FTPS se ne poveže

Če varna povezava FTP spodleti, preverite te nastavitve v podrobnostih povezave:

- Uskladite varnostni način strežnika: izrecni FTPS (AUTH TLS) proti implicitnemu FTPS (vrata 990) nista zamenljiva.
- Če se povezava po prijavi zatakne, preklopite med pasivnim in aktivnim načinom prenosa — večina strežnikov za požarnim zidom potrebuje pasivnega.
- Če strežnik uporablja samopodpisano potrdilo, ga morate izrecno dovoliti; sicer je povezava zavrnjena.
- Potrdite gostitelja, vrata, uporabniško ime in geslo, in ali je v vašem omrežju potreben posrednik SOCKS5.

## Pakiranje v RAR ne naredi ničesar

Peach Commander lahko sam ustvari arhive ZIP, 7z, TAR, TAR.GZ, BZ2 in XZ. RAR je drugačen: ker je RAR lastniška oblika, ustvarjanje arhivov RAR zahteva ločeno orodje ukazne vrstice RAR, nameščeno na vašem Macu. Brez njega RAR ni na voljo, ko pakirate datoteke (Option+F5). Za branje obstoječih arhivov RAR jih lahko še vedno odprete kot mapo. Če ne potrebujete prav RAR, izberite namesto tega ZIP ali 7z — oba podpirata močno šifriranje AES-256 in razdeljene nosilce.

## Bližnjice

| Dejanje | Bližnjica |
| --- | --- |
| Osveži dejavno mapo | F2 ali Ctrl+R |
| Poveži se s strežnikom FTP/FTPS | Ctrl+F |
| Priklopi omrežno mapo | Cmd+K |
| Zapakiraj izbrane datoteke | Option+F5 |

## Opombe

- Gesla in druge poverilnice so shranjene le v ključavnici macOS, nikoli v konfiguracijskih datotekah v navadnem besedilu.
- Priklop omrežne mape (Cmd+K, ali meni Omrežje ▸ Priklopi omrežno mapo…) uporablja isto povezavo, ki jo uporablja macOS sam, tako da se pojavi tudi v Finderju.
- Če težava vztraja po osvežitvi in ponovnem zagonu, gre morda za znano omejitev in ne za napako — glejte Znane omejitve.
