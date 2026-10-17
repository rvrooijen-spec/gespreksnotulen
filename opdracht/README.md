# Opdracht "Gesprek uitschrijven" – eenvoudige versie

Een iPhone-opdracht (Shortcut) die een Dictafoon-opname laat uitschrijven door **AssemblyAI (EU-server)**
en het resultaat als notitie in **Notities** zet. Zo kort mogelijk gehouden: 37 acties.
Werkt dit, dan breiden we hem uit (tijden, namen, delen met ChatGPT/Claude).

Uitkomst in Notities:
```
Teamoverleg – 17 oktober 2026 14:30

Spreker A: Goedemorgen allemaal, zullen we beginnen?
Spreker B: Ja, prima.
```

> De Nederlandse naam van een actie staat vooraan, de Engelse tussen haakjes.
> Vind je een actie niet, typ dan een deel van de naam in het zoekveld (bijv. "URL", "woordenboek").

## Zo gebruik je hem

- **Vanuit Dictafoon** (aanbevolen): tik op een opname → **•••** → **Deel** → **Gesprek uitschrijven**.
  Werkt ook voor opnames van je Apple Watch (die komen vanzelf op de iPhone).
- **Opdracht direct starten**: de opdracht opent Dictafoon. Kies daar de opname en doe hetzelfde als hierboven.

### Waarom niet "kies een opname" in de opdracht zelf?
Opdrachten kan de opnames van Dictafoon niet als bestand ophalen. De Dictafoon-acties in Opdrachten kunnen
een opname alleen **openen of afspelen**, niet doorgeven aan een volgende stap. De enige manier om de audio
in de opdracht te krijgen is via **Deel** in Dictafoon.

---

## Voorbereiding (eenmalig)

1. **Instellingen → Apps → Opdrachten → Geavanceerd** → zet **Sta delen van grote hoeveelheden gegevens toe** aan.
2. Open **Opdrachten** → **+**. Tik bovenaan op de naam → **Wijzig naam** → `Gesprek uitschrijven`.
3. Tik op **(i)** (of het pijltje naast de naam → **Details**) → zet **Toon in deelmenu** aan.
4. Bovenaan staat nu **Ontvang … uit Deelmenu**. Tik op het eerste woord en laat alleen **Media** en
   **Bestanden** aangevinkt. Zet **Als er geen invoer is** op **Ga door**.

Variabelen kies je door in een veld te tikken en boven het toetsenbord de naam te kiezen
(of **Variabele selecteren**). Hieronder staan ze als **[Naam]**. Inspringen = binnen een Als/Herhaal-blok.

---

## De acties

### 1. Geen opname gedeeld? Open Dictafoon

```
1  Als  [Opdrachtinvoer]  heeft geen waarde                      (If)
2      Toon melding  "Kies een opname en tik op Deel → Gesprek uitschrijven"   (Show Notification)
3      Open app  Dictafoon                                       (Open App)
4      Stop deze opdracht                                        (Stop This Shortcut)
5  Einde als
```

### 2. Sleutel

```
6  Tekst   <plak hier je AssemblyAI-sleutel>                     (Text)
7  Stel variabele in  Sleutel  op  [Tekst]                       (Set Variable)
```

### 3. Uploaden

```
8  Haal inhoud van URL op                                        (Get Contents of URL)
       URL:  https://api.eu.assemblyai.com/v2/upload
       tik op ›:  Methode: POST
       Headers: + Nieuwe header  →  authorization  =  [Sleutel]
       Hoofdtekst verzoek: Bestand  →  [Opdrachtinvoer]
9  Haal woordenboekwaarde op  Waarde  voor  upload_url  in  [Inhoud van URL]   (Get Dictionary Value)
```

### 4. Uitschrijven starten

```
10 Haal inhoud van URL op
       URL:  https://api.eu.assemblyai.com/v2/transcript
       Methode: POST
       Headers: authorization = [Sleutel]
       Hoofdtekst verzoek: JSON  (+ Nieuw veld):
          audio_url       Tekst              [Woordenboekwaarde]     ← uitkomst van actie 9
          language_code   Tekst              nl
          speaker_labels  Booleaanse waarde  Waar
          speech_models   Array              →  Tekst  universal-3-5-pro
                                             →  Tekst  universal-2
11 Haal woordenboekwaarde op  Waarde  voor  id  in  [Inhoud van URL]
12 Stel variabele in  ID  op  [Woordenboekwaarde]
13 Tekst   queued
14 Stel variabele in  Status  op  [Tekst]
```
Let op: precies `universal-3-5-pro` met streepjes.

### 5. Wachten tot het klaar is

```
15 Herhaal  200  keer                                            (Repeat)
16     Als  [Status]  is niet  completed
17         Als  [Status]  is niet  error
18             Wacht  3  seconden                                (Wait)
19             Haal inhoud van URL op
                   URL: https://api.eu.assemblyai.com/v2/transcript/[ID]
                   Methode: GET  ·  Headers: authorization = [Sleutel]
20             Stel variabele in  Resultaat  op  [Inhoud van URL]
21             Haal woordenboekwaarde op  Waarde  voor  status  in  [Resultaat]
22             Stel variabele in  Status  op  [Woordenboekwaarde]
23         Einde als
24     Einde als
25 Einde herhaal
```
Opdrachten heeft geen "herhaal tot klaar". Na `completed` slaat hij de resterende rondes in een flits over.
Maximaal wachten: 200 × 3 s = 10 minuten.

### 6. Regels maken

```
26 Haal woordenboekwaarde op  Waarde  voor  utterances  in  [Resultaat]
27 Herhaal met elk  [Woordenboekwaarde]                          (Repeat with Each)
28     Haal woordenboekwaarde op  Waarde  voor  speaker  in  [Herhaalonderdeel]
29     Stel variabele in  Spreker  op  [Woordenboekwaarde]
30     Haal woordenboekwaarde op  Waarde  voor  text  in  [Herhaalonderdeel]
31     Tekst   Spreker [Spreker]: [Woordenboekwaarde]
32 Einde herhaal
33 Combineer  [Herhaalresultaten]  met  Nieuwe regel             (Combine Text)
```
Bij 31 typ je `Spreker ` en `: ` zelf; **[Spreker]** is de variabele, **[Woordenboekwaarde]** de uitkomst van 30.

### 7. Opslaan in Notities

```
34 Haal naam op  [Opdrachtinvoer]                                (Get Name)
35 Tekst
       [Naam] – [Huidige datum]

       [Gecombineerde tekst]
36 Maak notitie aan  met  [Tekst]                                (Create Note)
37 Toon notitie  [Notitie]                                       (Show Note)
```
Bij 35: tik op **[Huidige datum]** → kies datumnotatie **Lang** en tijd **Kort**.
Actie 37 is optioneel: die opent de notitie meteen.

Mislukt het uitschrijven (bijvoorbeeld door een verkeerde sleutel)? Dan blijft de notitie leeg op de titel na.
Een duidelijke foutmelding voegen we toe in de uitgebreide versie.

---

## Testen

1. Neem in Dictafoon 30 seconden op met twee stemmen.
2. Opname → **Deel** → **Gesprek uitschrijven**.
3. De eerste keer vraagt iOS of de opdracht verbinding mag maken met `api.eu.assemblyai.com`:
   kies **Sta altijd toe**.
4. Na ±30 seconden opent de notitie.

## Problemen oplossen

| Wat je ziet | Oplossing |
|---|---|
| Opdracht staat niet in het Dictafoon-deelmenu | (i) → **Toon in deelmenu** aan; invoer **Media** en **Bestanden**. Scroll in het deelmenu naar beneden of kies **Wijzig acties**. |
| Notitie bevat alleen de titel | Laat de opdracht vanuit de editor lopen (▶︎) en kijk bij actie 19/20 wat er terugkomt. Staat er `error`, dan zie je daar de reden. |
| `Unauthorized` / `401` | Header precies `authorization`, sleutel zonder spaties. |
| Iets over `speech_models` | Moet een **Array** zijn met `universal-3-5-pro` en `universal-2`. |
| "Te veel gegevens" | Zie Voorbereiding stap 1. |

## Goed om te weten

- **Je API-sleutel staat leesbaar in de opdracht.** Deel de opdracht nooit (ook niet als iCloud-link).
- Sprekers heten A, B, C … in de volgorde waarin AssemblyAI ze herkent (bijna altijd: wie het eerst praat is A).
  Herkenning is niet perfect.
- De audio gaat naar AssemblyAI in de EU.
- De vorige, uitgebreide bouwinstructie (tijden `[mm:ss]`, namen, delen) staat in de git-geschiedenis van dit
  bestand en is de basis voor de uitbreiding.
