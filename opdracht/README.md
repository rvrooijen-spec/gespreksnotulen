# Opdracht "Gesprek uitschrijven" – eenvoudige versie

Een iPhone-opdracht (Shortcut) die een Dictafoon-opname laat uitschrijven door **AssemblyAI (EU-server)**
en het resultaat als notitie in **Notities** zet. Zo kort mogelijk gehouden: 32 acties.
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

Open **Dictafoon** → tik op een opname → **•••** → **Deel** → kies **Gesprek uitschrijven**.
Na ±30 seconden (langer bij lange opnames) staat het gesprek als nieuwe notitie in Notities.
Werkt ook voor opnames van je Apple Watch: die staan vanzelf in Dictafoon op de iPhone.

---

## Voorbereiding (eenmalig)

1. **Instellingen → Apps → Opdrachten → Geavanceerd** → zet **Sta delen van grote hoeveelheden gegevens toe** aan.
2. Open **Opdrachten** → **+**. Tik bovenaan op de naam → **Wijzig naam** → `Gesprek uitschrijven`.
3. Tik op **(i)** (of het pijltje naast de naam → **Details**) → zet **Toon in deelmenu** aan.
4. Bovenaan staat nu **Ontvang … uit Deelmenu**. Tik op het eerste woord en laat alleen **Media** en
   **Bestanden** aangevinkt. Zet **Als er geen invoer is** op **Stop**.

Variabelen kies je door in een veld te tikken en boven het toetsenbord de naam te kiezen
(of **Variabele selecteren**). Hieronder staan ze als **[Naam]**. Inspringen = binnen een Als/Herhaal-blok.

---

## De acties

### 1. Sleutel

```
1  Tekst   <plak hier je AssemblyAI-sleutel>                     (Text)
2  Stel variabele in  Sleutel  op  [Tekst]                       (Set Variable)
```

### 2. Uploaden

```
3  Haal inhoud van URL op                                        (Get Contents of URL)
       URL:  https://api.eu.assemblyai.com/v2/upload
       tik op ›:  Methode: POST
       Headers: + Nieuwe header  →  authorization  =  [Sleutel]
       Hoofdtekst verzoek: Bestand  →  [Opdrachtinvoer]
4  Haal woordenboekwaarde op  Waarde  voor  upload_url  in  [Inhoud van URL]   (Get Dictionary Value)
```

### 3. Uitschrijven starten

```
5  Haal inhoud van URL op
       URL:  https://api.eu.assemblyai.com/v2/transcript
       Methode: POST
       Headers: authorization = [Sleutel]
       Hoofdtekst verzoek: JSON  (+ Nieuw veld):
          audio_url       Tekst              [Woordenboekwaarde]     ← uitkomst van actie 4
          language_code   Tekst              nl
          speaker_labels  Booleaanse waarde  Waar
          speech_models   Array              →  Tekst  universal-3-5-pro
                                             →  Tekst  universal-2
6  Haal woordenboekwaarde op  Waarde  voor  id  in  [Inhoud van URL]
7  Stel variabele in  ID  op  [Woordenboekwaarde]
8  Tekst   queued
9  Stel variabele in  Status  op  [Tekst]
```
Let op: precies `universal-3-5-pro` met streepjes.

### 4. Wachten tot het klaar is

```
10 Herhaal  200  keer                                            (Repeat)
11     Als  [Status]  is niet  completed
12         Als  [Status]  is niet  error
13             Wacht  3  seconden                                (Wait)
14             Haal inhoud van URL op
                   URL: https://api.eu.assemblyai.com/v2/transcript/[ID]
                   Methode: GET  ·  Headers: authorization = [Sleutel]
15             Stel variabele in  Resultaat  op  [Inhoud van URL]
16             Haal woordenboekwaarde op  Waarde  voor  status  in  [Resultaat]
17             Stel variabele in  Status  op  [Woordenboekwaarde]
18         Einde als
19     Einde als
20 Einde herhaal
```
Opdrachten heeft geen "herhaal tot klaar". Na `completed` slaat hij de resterende rondes in een flits over.
Maximaal wachten: 200 × 3 s = 10 minuten.

### 5. Regels maken

```
21 Haal woordenboekwaarde op  Waarde  voor  utterances  in  [Resultaat]
22 Herhaal met elk  [Woordenboekwaarde]                          (Repeat with Each)
23     Haal woordenboekwaarde op  Waarde  voor  speaker  in  [Herhaalonderdeel]
24     Stel variabele in  Spreker  op  [Woordenboekwaarde]
25     Haal woordenboekwaarde op  Waarde  voor  text  in  [Herhaalonderdeel]
26     Tekst   Spreker [Spreker]: [Woordenboekwaarde]
27 Einde herhaal
28 Combineer  [Herhaalresultaten]  met  Nieuwe regel             (Combine Text)
```
Bij 26 typ je `Spreker ` en `: ` zelf; **[Spreker]** is de variabele, **[Woordenboekwaarde]** de uitkomst van 25.

### 6. Opslaan in Notities

```
29 Haal naam op  [Opdrachtinvoer]                                (Get Name)
30 Tekst
       [Naam] – [Huidige datum]

       [Gecombineerde tekst]
31 Maak notitie aan  met  [Tekst]                                (Create Note)
32 Toon notitie  [Notitie]                                       (Show Note)
```
Bij 30: tik op **[Huidige datum]** → kies datumnotatie **Lang** en tijd **Kort**.
Actie 32 is optioneel: die opent de notitie meteen.

Mislukt het uitschrijven (bijvoorbeeld door een verkeerde sleutel)? Dan blijft de notitie leeg op de titel na.
Een duidelijke foutmelding voegen we toe in de uitgebreide versie.

---

## Testen

1. Neem in Dictafoon 30 seconden op met twee stemmen.
2. Tik op de opname → **•••** → **Deel** → **Gesprek uitschrijven**.
3. De eerste keer vraagt iOS of de opdracht verbinding mag maken met `api.eu.assemblyai.com`:
   kies **Sta altijd toe**.
4. Na ±30 seconden opent de notitie.

## Problemen oplossen

| Wat je ziet | Oplossing |
|---|---|
| Opdracht staat niet in het Dictafoon-deelmenu | (i) → **Toon in deelmenu** aan; invoer **Media** en **Bestanden**. Scroll in het deelmenu helemaal naar beneden, of tik op **Wijzig acties** en zet hem bij Favorieten. |
| Opdracht doet niets als je hem los start | Klopt: hij werkt alleen via **Deel** in Dictafoon. |
| Notitie bevat alleen de titel | Laat de opdracht vanuit de editor lopen (▶︎) en kijk bij actie 14/15 wat er terugkomt. Staat er `error`, dan zie je daar de reden. |
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
