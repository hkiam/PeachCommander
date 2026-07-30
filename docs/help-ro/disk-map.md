---
title: Hartă disc
slug: disk-map
section: Pluginuri
order: 121
related: [plugins, deleting-files, settings]
---

Hartă disc este un plugin încorporat care arată, dintr-o privire, ce folosește spațiu într-un folder sau pe un întreg volum. Scanează folderul pe care îl alegeți și desenează fiecare element dimensionat proporțional cu spațiul pe care îl ocupă efectiv pe disc, astfel încât cei mai mari devoratori de spațiu ies imediat în evidență. Puteți intra în adâncimea folderelor, vedea cum se reconciliază scanarea dvs. cu spațiul liber, purjabil și ascuns al volumului și face curățenie direct de pe hartă.

## Începeți o scanare

1. În panoul activ, mergeți la folderul (sau volumul) pe care doriți să-l măsurați.
2. Alegeți **Comenzi ▸ Hartă disc: Analizează folderul curent**.
3. Vizualizarea Hartă disc se deschide în dreapta și scanează în fundal, arătând o numărătoare curentă de elemente și octeți. Folderele mari se termină în câteva secunde — scanarea citește metadatele directorului în masă și lucrează pe mai multe nuclee de procesor.

![Hartă disc care arată o hartă arborescentă a unui folder, o bară de volum, o listă a celor mai mari fișiere și o legendă de categorii](screenshots/disk-map.png)
*(Figura: vizualizarea hărții arborescente, colorată după categoria fișierului, cu bara de volum deasupra și lista celor mai mari fișiere în dreapta.)*

## Citirea hărții

- Fiecare bloc (hartă arborescentă) sau segment de inel (explozie solară) este dimensionat după **dimensiunea reală pe disc** a elementului, astfel încât imaginea se potrivește cu ceea ce raportează Finder și sistemul.
- Blocurile sunt **colorate după tipul fișierului** — video, imagini, audio, documente, cod, arhive, aplicații, imagini de disc — cu o legendă în partea de jos. În setări puteți comuta la o **hartă termică** după dimensiune.
- **Faceți clic pe un folder** pentru a intra în el; firimiturile din partea de sus arată unde vă aflați, iar butonul **◂** urcă un nivel.
- Treceți cu cursorul peste orice bloc pentru a-i vedea calea completă, dimensiunea și numărul de elemente.

## Două vizualizări: hartă arborescentă și explozie solară

Hartă disc oferă două vizualizări, între care puteți comuta cu butonul **◎ / ▦** din antet sau de pe pagina de setări:

- **Hartă arborescentă** — dreptunghiuri imbricate, cea mai densă pentru depistarea celui mai mare fișier individual.
- **Explozie solară** — inele concentrice (unul per adâncime de folder) în jurul folderului curent, cea mai bună pentru a vedea cum este distribuit spațiul într-un arbore adânc.

![Vizualizarea explozie solară a Hărții disc care arată inele concentrice pentru adâncimea folderelor](screenshots/disk-map-sunburst.png)
*(Figura: vizualizarea explozie solară — discul interior este folderul curent, iar fiecare inel este un nivel mai adânc.)*

## Bara de volum

Bara din partea de sus reconciliază scanarea dvs. cu întregul volum:

- **Scanat / Acest folder** — cât ocupă folderul analizat.
- **Ascuns** (la rădăcina volumului) sau **Restul volumului** (pentru un subfolder) — tot ce nu este în această scanare, inclusiv folderele protejate de sistem, alți utilizatori și instantaneele.
- **Purjabil** — spațiu pe care macOS îl poate recupera automat, mai ales instantanee Time Machine locale și cache-uri.
- **Liber** — spațiu disponibil chiar acum.

Când volumul are instantanee locale, bara arată un element **· N instantanee (ⓘ)**; faceți clic pe el pentru o listă doar-citire, cu un indiciu de a le gestiona în Utilitar disc sau Time Machine. Hartă disc nu șterge niciodată instantaneele ea însăși.

## Cele mai mari fișiere

Activați **Arată lista celor mai mari fișiere** pentru a vedea cele mai mari fișiere din folderul curent clasate după dimensiune, fiecare cu un jeton de culoare pentru categoria sa. Faceți clic pe unul pentru a-l evidenția pe hartă.

## Curățenie de pe hartă

Faceți clic dreapta pe orice bloc pentru acțiuni:

- **Deschide în panoul stâng** / **Deschide în panoul drept** — dezvăluie elementul într-un panou de fișiere.
- **Dezvăluie în Finder**.
- **Mută în Coș** — șterge doar acel element; harta se actualizează fără o rescanare completă.

Pentru a elimina mai multe elemente deodată, folosiți **colectorul**: clic dreapta ▸ **Marchează pentru colector** pe fiecare element, apoi faceți clic pe butonul **🗑 N** din antet pentru a muta tot ce ați marcat în Coș într-un singur pas confirmat.

## Setări

Hartă disc adaugă propria pagină la fereastra Setări (**Configurare ▸ Setări ▸ Hartă disc**):

- **Stil de grafic** — hartă arborescentă sau explozie solară.
- **Codificare pe culori** — după tipul fișierului (categorie) sau după dimensiune (hartă termică).
- **Rămâi pe volumul de pornire** — nu trece pe alte discuri montate.
- **Arată bara de volum** și **Arată lista celor mai mari fișiere**.

Modificările se aplică imediat unei Hărți disc deschise.

## Note

- Hartă disc măsoară dimensiunea **alocată** (pe disc) și numără fișierele cu **legături hard** doar o dată, astfel încât totalurile ei se aliniază cu spațiul folosit al volumului în loc să-l supraevalueze.
- Implicit, scanarea rămâne pe volumul de pornire, astfel încât nu va rătăci pe alte discuri montate sau partajări de rețea.
