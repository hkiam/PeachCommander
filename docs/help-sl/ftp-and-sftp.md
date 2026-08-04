---
title: Povezovanje s FTP in SFTP
slug: ftp-and-sftp
section: Omrežje in oddaljeni dostop
order: 100
related: [downloading-from-url, network-shares]
---

Peach Commander lahko brska po oddaljenih strežnikih, kot da bi bili običajne mape. Ko ste povezani, eno podokno prikazuje oddaljene datoteke, vi pa jih kopirate, premikate, preimenujete in brišete z istimi tipkami kot lokalno. Govori navadni FTP, varni FTPS in SFTP/SCP prek SSH, tako da lahko dosežete karkoli, od klasičnega spletnega gostovanja do utrjenega strežnika SSH. Shranjene povezave živijo v upravitelju povezav, gesla pa so varno shranjena v vaši ključavnici macOS, ne v sami povezavi.

## Povezovanje s strežnikom

1. Odprite meni **Omrežje** in izberite **Povezava FTP…** (Ctrl+F), da odprete upravitelja povezav.
2. Izberite shranjeno povezavo s seznama in kliknite **Poveži**, ali kliknite **Nova**, da jo ustvarite. Uporabite mape na seznamu za združevanje povezav.
3. Za hitro enkratno povezavo izberite **Omrežje > Nova povezava FTP…** (Ctrl+N) in vnesite naslov neposredno.
4. Vnesite geslo, ko ste pozvani; obkljukajte možnost, da ga shranite, in gre v vašo ključavnico za naslednjič.
5. Ko končate, izberite **Omrežje > Prekini FTP** (Ctrl+Shift+F).

![Upravitelj povezav FTP, ki prikazuje seznam shranjenih sej z gumbi Nova, Uredi in Izbriši](screenshots/ftp-connection-manager.png)
*(Slika: upravitelj povezav hrani vaše shranjene strežnike; uporabite Nova, Uredi in Izbriši za njihovo upravljanje.)*

Pri nastavljanju povezave lahko izberete protokol (FTP, FTPS z izrecnim AUTH TLS, implicitni FTPS na vratih 990 ali SFTP/SCP), pasivni ali aktivni način, oddaljeno in lokalno začetno mapo, kodiranje besedila in izbirni interval keep-alive, da preprečite nedejavnim strežnikom, da vas prekinejo. Za SFTP se lahko overite s svojim agentom SSH, geslom ali datoteko zasebnega ključa, za prenose pa lahko izberete SCP. Neznani ključi gostiteljev SSH se ob prvi uporabi štejejo za zaupanja vredne; če se ključ znanega strežnika kdaj spremeni, je povezava zavrnjena, da vas zaščiti pred posegi.

## Konzola FTP

Za ogled, kaj natanko pravi strežnik, odprite konzolo FTP iz menija **Omrežje**. Prikazuje dnevnik nadzornega kanala v živo (vaše geslo je zakrito) in vam omogoča vnašanje surovih ukazov FTP strežniku.

![Konzola FTP, ki prikazuje dnevnik nadzornega kanala in polje za surove ukaze](screenshots/ftp-console.png)
*(Slika: konzola FTP beleži vsako izmenjavo in sprejema surove ukaze, kar je priročno za odpravljanje težav.)*

## Bližnjice

| Dejanje | Bližnjica |
| --- | --- |
| Odpri upravitelja povezav | Ctrl+F |
| Nova povezava | Ctrl+N |
| Prekini | Ctrl+Shift+F |
| Spremeni način prenosa | Ctrl+Shift+M |

## Opombe

- Prekinjen prenos se nadaljuje tam, kjer se je ustavil: če je datoteka že deloma tam in strežnik sprejme vnovični zagon, potuje le manjkajoči rep. Strežnik, ki to zavrne, datoteko preprosto začne znova. Nalaganja se še ne nadaljujejo.
- Za strežnike FTPS s samopodpisanim potrdilom vklopite možnost sprejmi nezaupljivo potrdilo v nastavitvah te povezave.
- Posrednik SOCKS5 je mogoče nastaviti za vsako povezavo za navadni FTP. Usmerjanje šifrirane povezave FTPS skozi posrednika ni podprto.
- Obstoječe povezave FTP iz Total Commander je mogoče uvoziti.
- SCP se uporablja le za prenos datotek; naštevanje, preimenovanje in brisanje vedno potekajo prek SFTP.
