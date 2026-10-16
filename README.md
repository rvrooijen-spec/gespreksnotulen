# Notulen

iPhone-app die gesprekken opneemt en ze via **AssemblyAI** (EU-server) in het Nederlands uitschrijft, met wie wat zegt.

- Opnemen, ook met het scherm uit
- Uitschrijven en sprekers herkennen met AssemblyAI (EU-endpoint, `api.eu.assemblyai.com`)
- Verplicht aangeven wie "ik" ben; anderen heten standaard Persoon 2, 3, ... (aanpasbaar)
- Tik op een uitspraak om die terug te luisteren
- Delen of kopiëren als tekst; opnames staan ook in de Bestanden-app
- Opnames uit Dictafoon (ook van de Apple Watch) via **Deel → Notulen**, of importeren (m4a/mp3/wav)
- Zoeken in alle gesprekken
- Crashbestendig: er wordt opgenomen in CAF (blijft leesbaar na een crash) en daarna
  automatisch gecomprimeerd naar m4a; tijdens een opname pauzeert het uitschrijven
- Uitschrijven gaat door met het scherm uit; zonder internet opnieuw zodra de app weer open is

## Hoe de app gebouwd wordt

Er is geen Mac nodig. Bij elke push naar `main` bouwt GitHub Actions de app op een Mac in de cloud
(`.github/workflows/build.yml`). Het resultaat, `Notulen.ipa`, staat daarna bij
**Releases → laatste** (en als artefact bij de workflow-run).

Het Xcode-project wordt gegenereerd uit `project.yml` met [XcodeGen](https://github.com/yonaskolb/XcodeGen).

## Automatische tests

- **Schermtest** (`.github/workflows/schermtest.yml`): opent de app in de iPhone-simulator met voorbeeldgesprekken,
  tikt alle schermen door en zet schermafbeeldingen op de branch `schermafbeeldingen`.
- **Transcribeer testopnames** (`.github/workflows/transcribeer.yml`): zet een audiobestand in `testopnames/`
  en het wordt via AssemblyAI uitgeschreven; resultaat op de branch `transcripties`.
  Vereist de repository secret `ASSEMBLYAI_API_KEY`.

## Installeren op je iPhone (Windows-pc)

Eenmalig:

1. Installeer op de pc **iTunes** en **iCloud** van de Apple-website (níet de Microsoft Store-versies).
2. Installeer **AltServer** voor Windows van https://altstore.io en start het (icoon rechtsonder in de taakbalk).
3. Sluit de iPhone met een kabel aan, kies in iTunes "Vertrouw deze computer" en zet in iTunes
   **"Synchroniseer met deze iPhone via wifi"** aan.
4. Klik op het AltServer-icoon → **Install AltStore** → kies je iPhone → log in met je Apple ID.
5. Op de iPhone: **Instellingen → Algemeen → VPN en apparaatbeheer** → vertrouw je Apple ID.
   Zet ook **Instellingen → Privacy en beveiliging → Ontwikkelaarsmodus** aan (iPhone herstart).

App installeren of bijwerken:

1. Download `Notulen.ipa` van de release **laatste** en zet het bestand op de iPhone (bijv. via iCloud Drive).
2. Open **AltStore** → tabblad **My Apps** → **+** → kies `Notulen.ipa`.

Verlengen: een gratis Apple ID ondertekent apps voor 7 dagen. AltStore verlengt automatisch zolang
AltServer op de pc draait en de iPhone op **hetzelfde wifi-netwerk** zit. Je opnames blijven altijd bewaard,
ook als de app een keer verloopt: gewoon opnieuw verlengen.

## Eerste gebruik

Open de app, tik op het tandwiel en plak je **AssemblyAI API-sleutel** (assemblyai.com › Dashboard).
De sleutel wordt in de sleutelhanger van de iPhone bewaard. Opnames die je maakt zonder sleutel of zonder internet
worden daarna vanzelf uitgeschreven.
