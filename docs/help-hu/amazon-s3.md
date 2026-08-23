---
title: Amazon S3 és S3-kompatibilis tárolók
slug: amazon-s3
section: Bővítmények
order: 135
related: [plugins, webdav, ftp-and-sftp, copying-files]
---

Egy S3-bucket a panelen ugyanúgy böngészhető, mint bármelyik mappa. Válassza a **Kapcsolódás az Amazon S3-hoz…** parancsot a Hálózat menüből, adja meg a végpontot és a kulcsokat, és a tároló megjelenik az aktív panelen — a **bucketek listájával a legfelső szinten**, alatta pedig minden bucket egy közönséges könyvtárként.

Működik az Amazon S3-mal és mindennel, ami ugyanezt a protokollt beszéli: a MinIO, a Ceph/RADOS Gateway, a Cloudflare R2, a Wasabi, a Backblaze B2 és a DigitalOcean Spaces mind elérhető.

Bővítmény, tehát a **Konfiguráció ▸ Bővítmények…** alatt kikapcsolható vagy eltávolítható.

## Kapcsolódás

A **Szolgáltatás** menü kitölti azt a két beállítást, amit nem lehet kitalálni — hogy HTTPS-t kell-e használni, és hogy a végpont igényel-e útvonal alapú címzést —, a végpontot magát viszont önre hagyja, mert az általában a fiókjától függ. Mindkét beállítás úgy hibázik, hogy másnak látszik: a virtuális gazdanév alapú címzés egy puszta IP-cím ellen névfeloldási hiba, az útvonal alapú címzés az Amazon ellen pedig „nincs ilyen bucket”, ami hiányzó bucketnek olvasható.

A **titkos hozzáférési kulcs** a gazdaalkalmazáson keresztül a **Kulcskarikára** kerül, soha nem konfigurációs fájlba. Hagyja a mezőt egy későbbi kapcsolódásnál üresen, és a mentett kulcsot használja.

A **Kapcsolat megjegyzése** megőrzi a végpontot, a régiót, a kulcsazonosítót és a címzés módját — a titkot soha — a `~/Library/Application Support/PeachCommander/s3/profiles.json` fájlban. A megjegyzett kapcsolat ezenkívül gomb lesz a meghajtósávon, és arra kattintva közvetlenül kapcsolódik, nem nyílik meg újra ez a párbeszédpanel.

### Profilok, amelyek már megvannak

Ha használja az AWS parancssorát, annak profiljai a **Név** menüben *(AWS CLI)* jelöléssel jelennek meg, a `~/.aws/credentials` és a `~/.aws/config` fájlból olvasva — a régióval, a munkamenet-tokennel és az `s3.addressing_style` beállítással együtt. Oda semmi nem íródik vissza, és az ilyen profilt **nem** jegyzi meg magától: egy titok második példányát tartani olyan dolog, amit kérni kell, nem olyan, ami azért történik, mert egy menüből nevet választott.

### Nyilvános bucketek

A **Kapcsolódás anonim módon** egyáltalán nem küld aláírást, és ezt akarja egy nyilvánosan olvasható bucket. Ha a bucket nem nyilvános, pontosan ezt közli — nem azt, hogy a kulcsát elutasították. Nem volt kulcs.

## Mit lehet vele tenni

A listázás, olvasás, írás, mappa- és bucketlétrehozás, törlés, átnevezés és mozgatás mind működik. A másolás és a mozgatás **a kiszolgálón** történik: a bájtok nem mennek át a Macjén.

Egy mappa az S3-ban nem valódi dolog — vagy az alatta lévő kulcsok közös előtagja, vagy egy nulla bájtos objektum, amelynek a neve `/` jelre végződik. Mindkettő mappaként látszik. Létrehozni azt jelenti, hogy ezt a jelölőt írjuk; törölni azt, hogy minden alatta lévő objektumot törlünk, mert más nincs, amit törölni lehetne.

A legfelső szinten az **Új mappa bucketet hoz létre** — az a szint *maga* a bucketlista, ott semmi mást nem jelenthetne.

A **Tárolási osztály** és az **ETag** panel-oszlopként elérhető (jobb kattintás az oszlopfejlécen). Mindkettő a már megtörtént listázásból származik, tehát semmibe nem kerül.

## Mire számíthat

**Egy bucketet nem lehet átnevezni.** Az S3-ban nincs ilyen művelet, és az alternatíva — minden objektum átmásolása egy új bucketbe, majd a régi törlése — nem az, amit egy átnevezési párbeszédpanel kért. Ezt elutasítja, nem pedig megjátssza.

**Az átvitel teljes fájlokra vonatkozik.** Egy fájl egy darabban jön vagy megy; a megszakadt átvitel újrakezdődik, nem folytatódik. A nagy feltöltések automatikusan részekre bomlanak; ha egy rész elbukik, a részeket eltakarítja, nem hagyja ott, hogy kiszámlázzák.

**Egy mappa átnevezése nem atomi.** Objektumonként másol és töröl, és az első hibánál megáll, nem megy tovább egy félig áthelyezett állapotba.

**Az archivált objektumok közvetlenül nem olvashatók.** A Glacierben vagy Deep Archive-ban lévő objektumot először vissza kell állítani, az AWS konzolján vagy a CLI-vel. A panel ezt mondja, nem pedig úgy hibázik, mintha az objektum sérült volna.

**Egy nagyon nagy mappa listázása annyi ideig tart, amennyi a kiszolgálónak kell.** Az objektumok ezres tételekben érkeznek, és a panel akkor telik meg, amikor az utolsó oldal beérkezett.

**Fizetős szolgáltatásnál minden kérés pénzbe kerül.** A bővítmény úgy készült, hogy a lehető legkevesebbet kérdezze — az oszlopok a már megtörtént listázásból jönnek, egy bucket régióját egyszer megtudja és megjegyzi —, de egy bucket böngészése nem olyan ingyenes, mint egy lemez böngészése.
