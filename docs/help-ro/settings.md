---
title: Setări
slug: settings
section: Personalizare
order: 116
related: [appearance, keyboard-shortcuts]
---

Fereastra Setări este locul unde adaptați Peach Commander la modul în care lucrați: ce bare apar, cum sunt afișate fișierele, cum se comportă operațiunile de copiere și ștergere, formatul de arhivă folosit când împachetați, comportamentul filelor, valorile implicite FTP, limba de afișare și altele. Setările sunt grupate în pagini, astfel încât să găsiți rapid o opțiune, iar fiecare modificare este salvată automat în folderul dvs. personal de configurare.

## Deschiderea Setărilor

1. Alegeți **Peach Commander > Setări…**, sau apăsați Cmd+, (virgulă).
2. Puteți de asemenea deschide aceeași fereastră din **Configurare > Opțiuni…**.
3. Alegeți o pagină din lista din stânga; opțiunile acelei pagini apar în dreapta.
4. Ajustați controalele. Modificările intră în vigoare imediat, cu excepția cazului în care o notă de pe pagină spune altfel.
5. Pentru a ajunge direct la o opțiune, tastați în câmpul de căutare din partea de sus a ferestrei. Configurările potrivite din *toate* filele sunt listate împreună cu fila pe care se află, iar alegerea unei configurări deschide fila respectivă cu ea evidențiată. ↑/↓ parcurg rezultatele, Return deschide cea evidențiată, iar Esc părăsește căutarea și readuce fila de la care ați plecat.

![Fereastra Setări care arată pagina Aspect cu casete de bifare pentru barele interfeței](screenshots/settings-layout.png)
*(Figura: pagina Aspect controlează ce bare sunt afișate în jurul panourilor.)*

## Paginile

Fereastra are aceste pagini, în ordine:

- **Aspect** — afișează sau ascunde bara de unități, bara de file, bara de cale și bara de stare și alege ce pagini oferă panoul lateral.
- **Afișare** — cum sunt listate fișierele și folderele, inclusiv formatul datei.
- **Pictograme** — aspectul pictogramelor în listele de fișiere.
- **Operare** — comportament general, cum ar fi ce se întâmplă când tastați într-un panou (căutare rapidă vs. linia de comandă).
- **Culori** — culori personalizate ale panourilor, sau lăsați-le să urmeze tema curentă.
- **Confirmare** — ce acțiuni vă cer mai întâi să confirmați, precum ștergerea.
- **Editare/Vizualizare** — dacă salvarea în editor păstrează o copie de rezervă `.bak`, programele folosite pentru editarea și vizualizarea fișierelor asocierile pe tip și cât poate costa o previzualizare în locațiile de rețea și în arhive.
- **Copiere/Ștergere** — păstrează metadatele fișierelor, folosește clonarea rapidă, copiază doar fișierele mai noi, verifică după copiere, trimite ștergerile în Coș și setează o limită de viteză opțională.
- **Zip/Arhivator** — formatul de arhivă implicit și nivelul de compresie folosite când împachetați.
- **Pluginuri** — activează sau dezactivează pluginurile instalate.
- **File** — cum se deschid și se comportă filele de foldere.
- **FTP** — valori implicite de rețea precum intervalul keep-alive.
- **Tastatură** — examinează și schimbă comenzile rapide de tastatură.
- **Limbă** — alege Implicit sistem, English sau Deutsch.
- **IA** — configurează asistentul IA: model preferat, punct final și cheie cloud, autonomie și serverul MCP opțional (vedeți [Asistent IA](ai-assistant.md)).
- **Diverse** — deschide folderul de configurare în Finder.

Pluginurile activate pot adăuga propriile pagini după cele încorporate — de exemplu **Hartă disc** și **System Monitor** — astfel încât opțiunile lor trăiesc în aceeași fereastră (vedeți [Pluginuri](plugins.md)).

![Fereastra Setări care arată opțiunile paginii Afișare pentru listarea fișierelor](screenshots/settings-display.png)
*(Figura: pagina Afișare controlează cum sunt listate fișierele și folderele.)*

![Fereastra Setări care arată pagina Operare](screenshots/settings-operation.png)
*(Figura: pagina Operare guvernează căutarea rapidă și comportamentul mausului.)*

## Unde sunt stocate setările dvs.

Configurația dvs. este păstrată în fișiere text simplu în interiorul folderului dvs. personal Application Support, la `~/Library/Application Support/PeachCommander`. Pentru a-l deschide, mergeți la pagina **Diverse** și faceți clic pe **Deschide folderul de configurare**. Parolele FTP salvate nu sunt stocate în aceste fișiere; sunt păstrate în siguranță în inelul de chei macOS.

Setările sunt scrise pe măsură ce le modificați. Puteți de asemenea forța o salvare oricând cu **Configurare > Salvează setările** și stoca poziția curentă a ferestrei și aspectul panourilor cu **Configurare > Salvează poziția**.

## Aducerea setărilor din Total Commander

Dacă treceți de la Total Commander pe Windows, puteți importa site-urile FTP salvate. Alegeți **Configurare > Importă wincmd.ini…** și selectați fișierul de configurare FTP Total Commander. Conexiunile dvs. sunt adăugate în Peach Commander în aceeași ordine în care apăreau acolo.

## Comenzi rapide

| Acțiune | Comandă rapidă |
| --- | --- |
| Deschide Setările | Cmd+, |

## Note

- Pagina **Limbă** oferă Implicit sistem, English și Deutsch. Schimbarea limbii intră în vigoare doar după ce reporniți Peach Commander.
- Culorile setate pe pagina **Culori** suprascriu tema; folosiți **Resetează la valorile implicite** acolo pentru a reveni la culorile temei.
- Peach Commander își stochează setările doar în propriul folder de configurare, astfel încât modificările dvs. nu afectează niciodată alte aplicații și sunt ușor de salvat prin copierea acelui folder.
