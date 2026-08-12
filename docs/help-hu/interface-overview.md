---
title: A főablak
slug: interface-overview
section: Első lépések
order: 12
related: [navigating, panels-and-tabs]
---

A Peach Commander két fájllistát jelenít meg egymás mellett, így egyszerre láthatja, honnan jönnek a fájlok és hova tartanak. Munkája nagy része ebben a két panelben zajlik; a körülöttük lévő sávok lehetővé teszik a meghajtóváltást, egy mappára ugrást és a gyakori fájlparancsok futtatását anélkül, hogy elhagyná a billentyűzetet. Ez az áttekintés megnevezi az ablak minden részét, hogy a súgó többi része érthető legyen.

![A Peach Commander főablaka a két paneljével és a körülvevő sávokkal](screenshots/main-window.png)
*(Ábra: a főablak — két panel a gombsávval, meghajtósávval és útvonalsávokkal fent, valamint a funkcióbillentyű-sávval lent.)*

## A két panel és az aktív panel

Az ablak bal és jobb panelre oszlik, mindegyik egy mappa tartalmát mutatja. Egyszerre csak egy panel aktív: ez jeleníti meg a kurzort (egy kiemelt sort), és útvonalsávja színes háttérrel rajzolódik. A másolás és áthelyezés parancsok mindig az aktív panelen hatnak, és a másikba küldik a fájlokat.

1. Kattintson bárhová egy panelbe, hogy aktívvá tegye, vagy nyomja meg a Tab billentyűt a köztük váltáshoz.
2. A nyílbillentyűkkel mozgassa a kurzort fel és le az aktív panelben.
3. Nyomja meg az Entert egy mappán a megnyitásához, vagy a lista tetején lévő `..` bejegyzésen egy szinttel feljebb lépéshez.

## A panelek körüli sávok

- **Gombsáv** (fent): lapos gombok sora a gyakori parancsokhoz. Kattintson egy gombra a parancsa futtatásához; kattintson jobb gombbal a sáv szerkesztéséhez.
- **Meghajtósáv**: minden elérhető lemezhez vagy kötethez egy gomb, mindegyiken a szabad hellyel. Kattintson egy kötetre, hogy az a panel oda váltson; a jobb kattintás kiadja — cserélhető köteteknél és csatolt lemezképeknél elérhető, az indítólemeznél és a hálózati megosztásoknál szürke.
- **Útvonalsáv**: az aktuális mappát kattintható morzsaútként mutatja. Kattintson egy szakaszra, hogy egyenesen arra a mappára ugorjon, vagy kattintson az útvonalra egy hely beírásához.
- **Állapotsáv** (minden lista alatt): a panel folyamatos összefoglalója — hány fájl és mappa van kijelölve, és azok teljes mérete.
- **Parancssor** (lent): egy szövegmező, ahová shell-stílusú parancsot írhat, ami az aktuális mappában fut.
- **Funkcióbillentyű-sáv** (legalul): hat gomb F3 Megtekintés, F4 Szerkesztés, F5 Másolás, F6 Áthelyezés, F7 ÚjMappa és F8 Törlés felirattal. Kattintson egy gombra vagy nyomja meg a megfelelő billentyűt.

![A meghajtósáv közelképe a kötetgombokkal és a szabad hellyel](screenshots/drive-bar-crop.png)
*(Ábra: a meghajtósáv — kötetenként egy gomb, a fennmaradó szabad hellyel; a köteten jobb kattintás kiadja azt.)*

## Billentyűparancsok

| Művelet | Billentyűparancs |
|---|---|
| Aktív panel váltása | Tab |
| Kurzor alatti mappa / elem megnyitása | Enter |
| Egy mappával feljebb | Backspace |
| Fájl megtekintése | F3 |
| Fájl szerkesztése | F4 |
| Másolás a másik panelre | F5 |
| Áthelyezés / átnevezés a másik panelre | F6 |
| Új mappa | F7 |
| Törlés (a Kukába) | F8 |

## Megjegyzések

- A funkcióbillentyű-sáv élőben újracímkézi magát, amikor lenyom egy módosítót. A Shift lenyomásával például az F6 helyben-átnevezés műveletté válik, így a gombok mindig azt mutatják, amit a billentyűk éppen tesznek.
- Szinte minden sáv megjeleníthető vagy elrejthető. Nézze meg a Nézet és Konfiguráció menüket a gombsáv, meghajtósáv, parancssor vagy funkcióbillentyű-sáv be- és kikapcsolásához, vagy a két panel egymás fölé rendezéséhez egymás mellett helyett.
- Sok Mac billentyűzeten az F-billentyűk alapértelmezetten média- és fényerő-vezérlőként működnek. Tartsa lenyomva az Fn billentyűt az F3–F8-cal együtt, vagy kapcsolja be a „Használja az F1, F2 stb. billentyűket standard funkcióbillentyűként” lehetőséget a Rendszerbeállításokban a közvetlen használatukhoz.
