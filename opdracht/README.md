# Opdracht "Gesprek uitschrijven" – eenvoudige versie

Een iPhone-opdracht (Shortcut) die een Dictafoon-opname laat uitschrijven door **AssemblyAI (EU-server)**
en het resultaat als notitie in **Notities** zet. Zo kort mogelijk gehouden: 28 acties.
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

---

## De acties

**Zo lees je dit:**
- Een grijs blok = tekst die je **kopieert en plakt**, precies zoals hij is.
- **🔵 Variabele** = die kun je niet plakken. Tik in het veld en kies hem in de balk boven het toetsenbord
  (of tik op het veld → **Selecteer variabele**). Vaak staat de juiste al ingevuld.
- **Einde als** en **Einde herhaal** komen er automatisch bij; die voeg je niet zelf toe.
  Sleep de acties die "binnen" horen tussen **Als** en **Einde als**.

---

### 1. Sleutel

**Actie 1 – Tekst** (Text)
Plak je eigen AssemblyAI-sleutel in het tekstvak.

---

**Actie 2 – Stel variabele in** (Set Variable)
Variabelenaam:
```
Sleutel
```
Invoer: 🔵 **Tekst**

---

### 2. Uploaden

**Actie 3 – Haal inhoud van URL op** (Get Contents of URL)
URL:
```
https://api.eu.assemblyai.com/v2/upload
```
Tik op **›** (meer opties):
- Methode: **POST**
- Headers → **Voeg nieuwe header toe** → sleutel:
  ```
  authorization
  ```
  waarde: 🔵 **Sleutel**
- Hoofdtekst verzoek: **Bestand** → bestand: 🔵 **Opdrachtinvoer**

---

**Actie 4 – Haal woordenboekwaarde op** (Get Dictionary Value)
Haal **Waarde** op voor sleutel:
```
upload_url
```
in: 🔵 **Inhoud van URL**

---

### 3. Uitschrijven starten

**Actie 5 – Haal inhoud van URL op**
URL:
```
https://api.eu.assemblyai.com/v2/transcript
```
Tik op **›**:
- Methode: **POST**
- Headers → **Voeg nieuwe header toe** → sleutel:
  ```
  authorization
  ```
  waarde: 🔵 **Sleutel**
- Hoofdtekst verzoek: **JSON**. Voeg 4 velden toe met **Voeg nieuw veld toe**:

  **Veld 1** – type **Tekst** – sleutel:
  ```
  audio_url
  ```
  waarde: 🔵 **Woordenboekwaarde** (de uitkomst van actie 4)

  **Veld 2** – type **Tekst** – sleutel:
  ```
  language_code
  ```
  waarde:
  ```
  nl
  ```

  **Veld 3** – type **Booleaanse waarde** – sleutel:
  ```
  speaker_labels
  ```
  waarde: zet de schakelaar **aan** (Waar)

  **Veld 4** – type **Array** – sleutel:
  ```
  speech_models
  ```
  Tik op het veld en voeg 2 onderdelen van type **Tekst** toe:
  ```
  universal-3-5-pro
  ```
  ```
  universal-2
  ```

---

**Actie 6 – Haal woordenboekwaarde op**
Haal **Waarde** op voor sleutel:
```
id
```
in: 🔵 **Inhoud van URL**

---

**Actie 7 – Stel variabele in**
Variabelenaam:
```
ID
```
Invoer: 🔵 **Woordenboekwaarde**

---

**Actie 8 – Tekst**
```
queued
```

---

**Actie 9 – Stel variabele in**
Variabelenaam:
```
Status
```
Invoer: 🔵 **Tekst**

---

### 4. Wachten tot het klaar is

**Actie 10 – Herhaal** (Repeat)
Aantal keer:
```
200
```

---

**Actie 11 – Als** (If) — binnen Herhaal
Invoer: 🔵 **Status** · voorwaarde: **is niet** · tekst:
```
completed
```
Komt er een **Anders** bij? Laat die leeg.

---

**Actie 12 – Als** — binnen actie 11
Invoer: 🔵 **Status** · voorwaarde: **is niet** · tekst:
```
error
```

---

**Actie 13 – Wacht** (Wait) — binnen actie 12
Seconden:
```
3
```

---

**Actie 14 – Haal inhoud van URL op** — binnen actie 12
URL: plak eerst dit (met de schuine streep aan het eind):
```
https://api.eu.assemblyai.com/v2/transcript/
```
en zet er direct daarachter 🔵 **ID** achter.
Tik op **›**:
- Methode: **GET**
- Headers → **Voeg nieuwe header toe** → sleutel:
  ```
  authorization
  ```
  waarde: 🔵 **Sleutel**

---

**Actie 15 – Stel variabele in** — binnen actie 12
Variabelenaam:
```
Resultaat
```
Invoer: 🔵 **Inhoud van URL**

---

**Actie 16 – Haal woordenboekwaarde op** — binnen actie 12
Haal **Waarde** op voor sleutel:
```
status
```
in: 🔵 **Resultaat**

---

**Actie 17 – Stel variabele in** — binnen actie 12
Variabelenaam:
```
Status
```
Invoer: 🔵 **Woordenboekwaarde**

---

### 5. Regels maken — ná **Einde herhaal**

**Actie 18 – Haal woordenboekwaarde op**
Haal **Waarde** op voor sleutel:
```
utterances
```
in: 🔵 **Resultaat**

---

**Actie 19 – Herhaal met elk** (Repeat with Each)
Invoer: 🔵 **Woordenboekwaarde**

---

**Actie 20 – Haal woordenboekwaarde op** — binnen Herhaal met elk
Haal **Waarde** op voor sleutel:
```
speaker
```
in: 🔵 **Herhaalonderdeel**

---

**Actie 21 – Stel variabele in** — binnen Herhaal met elk
Variabelenaam:
```
Spreker
```
Invoer: 🔵 **Woordenboekwaarde**

---

**Actie 22 – Haal woordenboekwaarde op** — binnen Herhaal met elk
Haal **Waarde** op voor sleutel:
```
text
```
in: 🔵 **Herhaalonderdeel**

---

**Actie 23 – Tekst** — binnen Herhaal met elk
Bouw het tekstvak zo op, van links naar rechts:
1. typ `Spreker` en daarna **één spatie**
2. 🔵 **Spreker**
3. typ een **dubbele punt en één spatie**
4. 🔵 **Woordenboekwaarde** (de uitkomst van actie 22)

Het ziet er dan zo uit: `Spreker` 🔵Spreker `: ` 🔵Woordenboekwaarde

---

**Actie 24 – Combineer tekst** (Combine Text) — ná **Einde herhaal**
Invoer: 🔵 **Herhaalresultaten** · combineer met: **Nieuwe regel**

---

### 6. Opslaan in Notities

**Actie 25 – Haal naam op** (Get Name)
Invoer: 🔵 **Opdrachtinvoer**

---

**Actie 26 – Tekst**
Bouw het tekstvak zo op:
1. 🔵 **Naam**
2. typ een spatie, een streepje en een spatie
3. 🔵 **Huidige datum** → tik erop → datumnotatie **Lang**, tijdnotatie **Kort**
4. druk **twee keer op Enter** (lege regel)
5. 🔵 **Gecombineerde tekst**

---

**Actie 27 – Maak notitie aan** (Create Note)
Hoofdtekst: 🔵 **Tekst**

---

**Actie 28 – Toon notitie** (Show Note) — optioneel, opent de notitie meteen
Invoer: 🔵 **Notitie**

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
| Notitie bevat alleen de titel | Laat de opdracht vanuit de editor lopen (▶︎) en kijk bij actie 14 en 15 wat er terugkomt. Staat er `error`, dan zie je daar de reden. |
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
