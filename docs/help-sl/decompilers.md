---
title: Povratno prevajanje Jave in .NET
slug: decompilers
section: Vtičniki
order: 131
related: [plugins, viewing-files, searching]
---

Pritisnite **F3** na prevedeni datoteki in videli boste izvorno kodo namesto bajtov. To počneta dva vtičnika — eden za Javo (`.class`, `.jar`, `.apk`, `.dex`) in eden za .NET (`.dll`, `.exe`, `.winmd`, `.netmodule`) — in vedeta se enako, zato ta stran pokriva oba. Vsakega je mogoče posebej izklopiti ali odstraniti v **Konfiguracija ▸ Vtičniki…**.

Arhiv se pokaže kot drevo svojih razredov, posamezen razred kot ena datoteka. **Prevedi nazaj v izvorno kodo** v meniju Ukazi izpiše rezultat in ga postavi v ploščo, tako da lahko po njem iščete, primerjate in kopirate kot v vsaki drugi mapi z izvorno kodo.

## Pogon namestite sami

Noben povratni prevajalnik ni priložen in nič se ne prenese namesto vas. To je namerno iz dveh razlogov: JD-Core, najbolj znan povratni prevajalnik za Javo, je pod GPLv3 in ga ne bi bilo mogoče dostaviti znotraj aplikacije pod Apache-2.0 — pogoni pa se izboljšujejo, zato njihova zamenjava ne bi smela zahtevati nove različice Peach Commanderja.

**Mapa pogonov…** v pregledovalniku odpre mapo, kamor sodijo. Tamkajšnji README poimenuje vsak pogon in njegovo licenco.

| | |
| --- | --- |
| Java | CFR, Vineflower, Procyon, jadx (za androidne `.dex` in `.apk`) in `javap` za goli bajtni zapis |
| .NET | ILSpy in `monodis` za IL |

**Preveri pogone** zažene ukaz za različico vsakega pogona in loči tri stvari: nameščen in deluje, ni nameščen, ter *nameščen, a se ne more zagnati* — orodje Java brez JDK je prisotno in se vseeno ne zažene, kar razkrije šele resničen zagon.

Pogon opisujejo podatki in ne koda, zato lahko sami dodate svojega:

```
[cfr]
kinds  = class, jar
tool   = java
args   = -jar {engine} {input}
engine = ~/Library/Application Support/PeachCommander/decompilers/cfr.jar
output = stdout
```

Kadar datoteko zmore več pogonov, se uporabi prvi razpoložljivi, razen če enega izberete. Z dvema nameščenima **Primerjaj** pokaže oba izida drug ob drugem — koristno, kadar en pogon obupa pri metodi, ki jo drugi zmore.

## Iskanje po prevedeni kodi

**Preišči vse razrede** gre skozi nazaj preveden zapis namesto skozi bajte, tako da v datoteki JAR najdete besedilni niz ali ime metode.

Povratno prevajanje med *iskanjem po vsebini* prek mnogih datotek je ločeno stikalo, privzeto izklopljeno: izdelava zapisa lahko pomeni, da se pogon zažene enkrat na razred, kar na počasnem računalniku ni razumna poraba za iskanje. Glavno okno iskanja vpraša posebej; tudi tu je to zavrnjeno.

## Predpomnilnik in omejitve

Izidi se predpomnijo, kajti dvakrat prevesti isti razred je zgolj čakanje. V nastavitvah je, koliko dni se izidi hranijo, in **omejitev velikosti** predpomnilnika; **Izprazni predpomnilnik zdaj** ga izprazni in sporoči, koliko se je sprostilo.

Dve časovni omejitvi varujeta pred pogonom, ki ne konča: ena za posamezen razred ali vrsto, ena za cel arhiv. Obe sprejmeta 0, kar pomeni »uporabi privzeto vrednost pogona«.
