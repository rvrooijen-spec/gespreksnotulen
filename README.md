# Notulen

iPhone-app die gesprekken opneemt, ze **op de iPhone zelf** in het Nederlands uitschrijft en herkent wie wat zegt.

- Opnemen, ook met het scherm uit
- Uitschrijven met Whisper large-v3 turbo (WhisperKit), offline
- Sprekers herkennen met Pyannote (SpeakerKit) en namen geven aan Spreker 1, 2, ...
- Tik op een uitspraak om die terug te luisteren
- Delen of kopiëren als tekst; opnames staan ook in de Bestanden-app
- Opnames uit Dictafoon (ook van de Apple Watch) via **Deel → Notulen**, of importeren (m4a/mp3/wav)
- Zoeken in alle gesprekken
- Crashbestendig: er wordt opgenomen in CAF (blijft leesbaar na een crash) en daarna
  automatisch gecomprimeerd naar m4a; tijdens een opname pauzeert het uitschrijven
- Uitschrijven gaat door met het scherm uit; lukt het toch niet, dan opnieuw zodra de app open is

## Hoe de app gebouwd wordt

Er is geen Mac nodig. Bij elke push naar `main` bouwt GitHub Actions de app op een Mac in de cloud
(`.github/workflows/build.yml`). Het resultaat, `Notulen.ipa`, staat daarna bij
**Releases → laatste** (en als artefact bij de workflow-run).

Het Xcode-project wordt gegenereerd uit `project.yml` met [XcodeGen](https://github.com/yonaskolb/XcodeGen).

## Automatische test

`.github/workflows/test.yml` (**Spraaktest**) maakt met de Nederlandse stemmen van macOS een
testgesprek tussen twee sprekers (`PipelineTest/dialoog.json`) en haalt dat door exact dezelfde
rekenkern als de app (`TranscriptionPipeline.swift`): modellen downloaden, uitschrijven, sprekers
herkennen, samenvoegen, comprimeren en afbreken. De test draait vanzelf als die code verandert,
of handmatig via Actions → Spraaktest → Run workflow.

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

Open de app en tik op **Nu downloaden** (ca. 700 MB, eenmalig, bij voorkeur op wifi).
Daarna werkt alles offline. Opnames die je maakt voordat de modellen er zijn, worden daarna vanzelf uitgeschreven.
