---
title: Uninstaller
slug: uninstaller
section: Programtillegg
order: 126
related: [plugins, deleting-files]
---

Å dra en app til Papirkurven etterlater støttefilene, hurtiglagrene, innstillingene og beholderne dens spredt utover Library-mappene dine. Uninstaller-programtillegget fjerner et program **og** disse restene: det finner alt appen etterlot seg, viser deg listen med en størrelse for hvert element, og flytter alt til Papirkurven når du bekrefter. Det er et programtillegg, så du kan slå det av eller fjerne det i **Konfigurasjon ▸ Programtillegg…**.

## Avinstaller en app under markøren

1. Sett markøren på et program (`.app`) i et panel.
2. Velg **Fil ▸ Avinstaller program…**, eller høyreklikk ▸ **Avinstaller program…**, eller trykk **Cmd+Shift+U**.
3. Gjennomgangsvinduet åpnes og lister appen pluss hver relatert fil den fant, hver merket med sin kategori, sti og størrelse.
4. Fjern merket for alt du vil beholde, og klikk deretter **Flytt til Papirkurv** (eller **Slett permanent**).

![Avinstalleringsvinduet som lister en apps gjenværende filer med avkrysningsruter og størrelser](screenshots/uninstaller.png)
*(Figur: gå gjennom nøyaktig hva som skal fjernes før noe slettes.)*

## Bla gjennom alle installerte apper

Velg **Kommandoer ▸ Avinstaller program…** for å åpne en søkbar liste over appene som er installert på Mac-en din, med hver apps navn, størrelse og installasjonsdato. Velg en (eller flere), klikk **Avinstaller…**, og du havner i det samme gjennomgangsvinduet. Du kan filtrere listen ved å skrive i søkefeltet.

## Finn gjenværende filer

Velg **Kommandoer ▸ Finn gjenværende filer…** for å søke etter støttefiler, hurtiglagre og innstillinger som tilhører apper du **allerede** har slettet. Gå gjennom dem på samme måte og rydd dem bort. Hvis ingenting blir funnet, forteller programtillegget deg det.

## Hvor grundig skal søket være

Gjennomgangsvinduet har en tillitskontroll:

- **Presis** – filer forankret til appens bundle-identifikator. Høy tillit; forhåndsvalgt.
- **Utvidet** – legger til navnematchede filer; blir stående umerket så du kan bestemme.
- **Dyp** – Utvidet pluss et Spotlight-søk etter alt annet som nevner appen; også stående umerket.

## Merknader

- Ingenting slettes direkte av programtillegget – elementer går gjennom appens Papirkurv eller permanent sletting, akkurat som enhver annen filoperasjon. Å fjerne filer i `/Library` eller `/var` kan kreve et administratorpassord.
- Før fjerning avslutter programtillegget appen som kjører og laster ut bakgrunnselementene dens (launchd), og tilbyr deretter å rydde opp i eventuelle nå tomme leverandørmapper.
- Hvis appen ble installert med **Homebrew**, advarer programtillegget deg og foreslår `brew uninstall --cask` slik at Homebrew holder seg synkronisert. App Store-apper noteres også.
- Utvidede og Dype treff har lavere tillit av design og starter umerket – gå gjennom dem før fjerning. Noen bakgrunnselementer installert via det moderne login-items-API-et kan ikke fjernes her.
