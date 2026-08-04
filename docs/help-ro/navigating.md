---
title: Deplasarea prin foldere
slug: navigating
section: Primii pași
order: 14
related: [interface-overview, favorites]
---

Peach Commander afișează două foldere alăturate, așa că cea mai mare parte a timpului este petrecută mutând un panou de la un folder la altul. Puteți deschide foldere, urca înapoi în ierarhie, reface traseul parcurs, tasta o cale direct și sări imediat la locurile de zi cu zi precum Acasă, Birou și Descărcări. Fiecare acțiune funcționează asupra panoului *activ* — cel cu bara de cale evidențiată.

## Deschiderea folderelor și urcarea înapoi

1. Deplasați bara de selecție cu tastele săgeți până când un folder este evidențiat.
2. Apăsați **Enter** (sau faceți dublu clic) pentru a-l deschide. Aceasta intră și în arhive și deschide fișierele cu aplicația lor implicită.
3. Pentru a urca un nivel la folderul părinte, apăsați **Ctrl+PageUp** (sau **Backspace**).
4. Pentru a sări la rădăcina discului curent, alegeți **Salt ▸ Rădăcină**.

## Înapoi și înainte

Peach Commander reține folderele pe care le-ați vizitat în fiecare panou, exact ca un navigator web.

- Apăsați **Alt+Left** pentru a reveni la folderul anterior și **Alt+Right** pentru a merge din nou înainte.
- Apăsați **Alt+Down** pentru a deschide o listă derulantă cu folderele recente și a sări la oricare dintre ele.

## Tastarea unei căi sau folosirea barei de cale

Bara de cale din partea de sus a fiecărui panou arată unde vă aflați și servește în același timp ca modalitate de a ajunge rapid undeva.

![Bara de cale editabilă care afișează folderul curent sub formă de segmente pe care se poate face clic](screenshots/path-bar-crop.png)
*(Figura: Bara de cale. Faceți clic pe orice segment pentru a sări la acel folder sau pe creion pentru a tasta o cale completă.)*

- Faceți clic pe orice segment al căii (de exemplu numele unui folder părinte) pentru a sări direct la el.
- Faceți clic pe creionul din dreapta barei de cale pentru a o transforma într-un câmp de text, apoi tastați sau lipiți orice cale și apăsați Enter.
- Sau alegeți **Fișier ▸ Salt la folder…** (**Cmd+Shift+G**) pentru a tasta o cale de oriunde.

## Salt la locurile obișnuite

Meniul **Salt** duce panoul activ la folderele pe care le folosiți cel mai des:

- **Acasă**, **Birou**, **Descărcări**, **Coșul de gunoi** și **iCloud Drive**.
- **iCloud Drive** apare atunci când este configurat pe Mac-ul dumneavoastră.

## Comutarea panourilor și a discurilor

- Apăsați **Tab** pentru a muta focalizarea între panoul stâng și cel drept.
- Bara de discuri de deasupra fiecărui panou listează volumele montate cu spațiul liber; faceți clic pe un volum pentru a comuta acel panou la el.
- Apăsați **Ctrl+U** pentru a interschimba cele două panouri (folderele lor schimbă locurile); **Ctrl+Shift+U** le interschimbă împreună cu filele lor.
- Apăsați **Ctrl+=** pentru a îndrepta celălalt panou spre același folder ca cel activ (*țintă = sursă*) — util chiar înainte de o copiere sau mutare.

## Scurtături

| Acțiune | Scurtătură |
| --- | --- |
| Deschideți folderul / fișierul de sub cursor | Enter |
| Salt la folderul părinte | Ctrl+PageUp (sau Backspace) |
| Înapoi / Înainte în istoric | Alt+Left / Alt+Right |
| Lista derulantă cu istoricul | Alt+Down |
| Salt la folder… (tastați o cale) | Cmd+Shift+G |
| Acasă | Cmd+Shift+H |
| Birou | Cmd+Shift+D |
| Descărcări | Option+Cmd+L |
| Comutați panoul activ | Tab |

## Sfaturi

- Un panou se ține la zi singur: un fișier pe care alt program îl creează, modifică sau șterge în dosarul afișat apare de la sine, iar cursorul și selecțiile rămân unde erau. Dezactivați-l din **Configurare ▸ Opțiuni ▸ Afișare** dacă un dosar în care se scrie continuu se reîmprospătează fără oprire.
- Fiecare panou își păstrează propriul istoric, așa că Înapoi și Înainte afectează doar partea activă.
- Dacă o cale tastată nu este un folder valid, bara de cale păstrează în tăcere ultima locație în loc să navigheze.
- Coșul de gunoi și iCloud Drive din meniul Salt nu au o scurtătură implicită, dar puteți atribui una în **Configurare ▸ Opțiuni ▸ Tastatură**.
