---
title: Amazon S3 in shrambe, združljive s S3
slug: amazon-s3
section: Vtičniki
order: 135
related: [plugins, webdav, ftp-and-sftp, copying-files]
---

Vedro S3 lahko v podoknu brskate kot vsako mapo. Izberite **Poveži z Amazon S3…** v meniju Omrežje, vnesite končno točko in ključe, in shramba se pojavi v aktivnem podoknu — s **seznamom veder kot najvišjo ravnjo** in vsakim vedrom kot običajnim imenikom pod njo.

Deluje z Amazon S3 in z vsem, kar govori isti protokol: MinIO, Ceph/RADOS Gateway, Cloudflare R2, Wasabi, Backblaze B2 in DigitalOcean Spaces so dosegljivi.

Je vtičnik, zato ga lahko izklopite ali odstranite v **Konfiguracija ▸ Vtičniki…**.

## Povezovanje

Meni **Storitev** izpolni dve nastavitvi, ki jih ni mogoče uganiti — ali uporabiti HTTPS in ali končna točka potrebuje naslavljanje po poti — končno točko samo pa pusti vam, saj je običajno odvisna od vašega računa. Obe nastavitvi odpovesta tako, da je videti kot nekaj drugega: naslavljanje po imenu gostitelja proti golemu naslovu IP je napaka razreševanja imen, naslavljanje po poti proti Amazonu pa je »ni takega vedra«, kar se bere kot manjkajoče vedro.

**Skrivni ključ za dostop** gre prek gostiteljskega programa v **Zbirko ključev**, nikoli v nastavitveno datoteko. Pustite polje pri naslednji povezavi prazno in uporabljen bo shranjeni.

**Zapomni si to povezavo** ohrani končno točko, regijo, ID ključa in način naslavljanja — nikoli skrivnosti — v `~/Library/Application Support/PeachCommander/s3/profiles.json`. Zapomnjena povezava postane tudi gumb v vrstici pogonov, klik nanj pa jo poveže neposredno, namesto da bi znova odprl to pogovorno okno.

### Profili, ki jih že imate

Če uporabljate ukazno vrstico AWS, so njeni profili ponujeni v meniju **Ime** z oznako *(AWS CLI)* in prebrani iz `~/.aws/credentials` in `~/.aws/config` — skupaj z regijo, žetonom seje in `s3.addressing_style`. Tja se nič ne zapisuje nazaj, in tak profil se **ne** zapomni samodejno: hraniti drugo kopijo skrivnosti je nekaj, kar se zahteva, ne nekaj, kar se zgodi, ker ste izbrali ime iz menija.

### Javna vedra

**Poveži anonimno** ne pošlje nobenega podpisa, kar javno berljivo vedro tudi želi. Če vedro ni javno, vam bo povedano prav to — in ne, da je bil vaš ključ zavrnjen. Ključa ni bilo.

## Kaj je mogoče

Izpis, branje, pisanje, ustvarjanje map in veder, brisanje, preimenovanje in premikanje delujejo. Kopiranje in premikanje se zgodita **na strežniku**: bajti ne gredo prek vašega Maca.

Mapa v S3 ni nič resničnega — je bodisi skupna predpona ključev pod njo bodisi predmet nič bajtov, čigar ime se konča z `/`. Oboje je prikazano kot mapa. Ustvarjanje zapiše to oznako; brisanje izbriše vsak predmet pod njo, ker drugega za brisanje ni.

Na najvišji ravni **Nova mapa ustvari vedro** — ta raven *je* seznam veder, drugega tam ne bi moglo pomeniti.

**Razred shrambe** in **ETag** sta na voljo kot stolpca podokna (desni klik na glavo stolpca). Oba prihajata iz izpisa, ki se je že zgodil, zato nič ne stanejo.

## Kaj pričakovati

**Vedra ni mogoče preimenovati.** S3 te operacije nima, alternativa — kopirati vsak predmet v novo vedro in staro izbrisati — pa ni to, kar je zahtevalo pogovorno okno za preimenovanje. To je zavrnjeno, ne pa hlinjeno.

**Prenosi zajemajo cele datoteke.** Datoteka se pridobi ali pošlje v enem kosu; prekinjen prenos se začne znova, namesto da bi se nadaljeval. Veliki prenosi navzgor se samodejno razdelijo na dele; če del odpove, se deli počistijo in ne ostanejo, da bi bili zaračunani.

**Preimenovanje mape ni atomarno.** Kopira in briše predmet za predmetom in se ustavi pri prvi napaki, namesto da bi nadaljevalo v napol premaknjeno stanje.

**Arhiviranih predmetov ni mogoče brati neposredno.** Predmet v Glacier ali Deep Archive je treba najprej obnoviti, v konzoli AWS ali z CLI. Podokno to pove, namesto da bi odpovedalo, kot bi bil predmet poškodovan.

**Izpis zelo velike mape traja toliko, kolikor traja strežniku.** Predmeti prihajajo po tisoč, podokno pa se napolni, ko prispe zadnja stran.

**Vsaka zahteva pri plačljivi storitvi stane denar.** Vtičnik je napisan tako, da vpraša čim manj — stolpci prihajajo iz izpisa, ki se je že zgodil, regija vedra se izve enkrat in se zapomni — a brskanje po vedru ni brezplačno tako kot brskanje po disku.
