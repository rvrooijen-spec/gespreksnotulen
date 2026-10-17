# Opdracht "Gesprek uitschrijven" – eenvoudige versie

Een iPhone-opdracht (Shortcut) die een Dictafoon-opname laat uitschrijven door **AssemblyAI (EU-server)**
en het resultaat als notitie in **Notities** zet. Zo kort mogelijk gehouden: 27 acties.
Werkt dit, dan breiden we hem uit (tijden, namen, delen met ChatGPT/Claude).

Uitkomst in Notities:
```
Teamoverleg

Spreker A: Goedemorgen allemaal, zullen we beginnen?
Spreker B: Ja, prima.
```

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

Grijze blokken kopieer en plak je precies zoals ze zijn.
"Tik boven het toetsenbord op …" = in de balk met variabelen die boven het toetsenbord verschijnt.

### 1. Sleutel

**Actie 1 – Tekst**
1. Tik onderaan op het zoekveld en typ: `tekst`
2. Tik op **Tekst**.
3. Tik in het tekstvak, wis wat er staat en plak je eigen AssemblyAI-sleutel.

---

**Actie 2 – Stel variabele in**
1. Tik op het zoekveld en typ: `stel variabele in`
2. Tik op **Stel variabele in**.
3. Tik op **Variabelenaam** en plak:
```
Sleutel
```
4. Controleer: achter **op** staat **Tekst**.

---

### 2. Uploaden

**Actie 3 – Haal inhoud van URL op**
1. Tik onderaan op het zoekveld en typ: `inhoud van url`
2. Tik op **Haal inhoud van URL op**.
3. Tik in de actie op het blauwe woord **URL** en plak:
```
https://api.eu.assemblyai.com/v2/upload
```
4. Tik op het pijltje **›** rechts in de actie. Er klappen extra regels open.
5. Tik achter **Methode** op **GET** en kies **POST**.
6. Tik op **Headers** en daarna op **Voeg nieuwe header toe**.
7. Tik op **Sleutel** en plak:
```
authorization
```
8. Tik op **Tekst** (rechts naast authorization). Tik boven het toetsenbord op **Sleutel**.
9. Tik achter **Hoofdtekst verzoek** op **JSON** en kies **Bestand**.
10. Tik op **Bestand** en kies **Opdrachtinvoer**.

---

**Actie 4 – Haal woordenboekwaarde op**
1. Tik op het zoekveld en typ: `woordenboekwaarde`
2. Tik op **Haal woordenboekwaarde op**.
3. Tik op het blauwe woord **Sleutel** en plak:
```
upload_url
```
4. Controleer: achter **in** staat **Inhoud van URL**.

---

### 3. Uitschrijven starten

**Actie 5 – Haal inhoud van URL op**
1. Tik op het zoekveld en typ: `inhoud van url`
2. Tik op **Haal inhoud van URL op**.
3. Tik op **URL** en plak:
```
https://api.eu.assemblyai.com/v2/transcript
```
4. Tik op het pijltje **›**.
5. Tik achter **Methode** op **GET** en kies **POST**.
6. Tik op **Headers** → **Voeg nieuwe header toe**.
7. Tik op **Sleutel** en plak:
```
authorization
```
8. Tik op **Tekst** ernaast. Tik boven het toetsenbord op **Sleutel**.
9. Controleer: achter **Hoofdtekst verzoek** staat **JSON**. Zo niet: tik erop en kies **JSON**.
10. Tik op **Voeg nieuw veld toe** → kies **Tekst**.
    Tik op **Sleutel** en plak:
```
audio_url
```
    Tik op **Tekst** ernaast. Tik boven het toetsenbord op **Woordenboekwaarde**.
11. Tik op **Voeg nieuw veld toe** → kies **Tekst**.
    Tik op **Sleutel** en plak:
```
language_code
```
    Tik op **Tekst** ernaast en plak:
```
nl
```
12. Tik op **Voeg nieuw veld toe** → kies **Booleaanse waarde**.
    Tik op **Sleutel** en plak:
```
speaker_labels
```
    Zet de schakelaar ernaast **aan**.
13. Tik op **Voeg nieuw veld toe** → kies **Array**.
    Tik op **Sleutel** en plak:
```
speech_models
```
    Tik op het veld ernaast (**0 onderdelen**). Tik op **Voeg nieuw onderdeel toe** → **Tekst** en plak:
```
universal-3-5-pro
```
    Tik nog een keer op **Voeg nieuw onderdeel toe** → **Tekst** en plak:
```
universal-2
```
    Tik op **Gereed**.

---

**Actie 6 – Haal woordenboekwaarde op**
1. Tik op het zoekveld en typ: `woordenboekwaarde`
2. Tik op **Haal woordenboekwaarde op**.
3. Tik op **Sleutel** en plak:
```
id
```
4. Controleer: achter **in** staat **Inhoud van URL**.

---

**Actie 7 – Stel variabele in**
1. Tik op het zoekveld en typ: `stel variabele in`
2. Tik op **Stel variabele in**.
3. Tik op **Variabelenaam** en plak:
```
ID
```
4. Controleer: achter **op** staat **Woordenboekwaarde**.

---

**Actie 8 – Tekst**
1. Tik op het zoekveld en typ: `tekst`
2. Tik op **Tekst**.
3. Tik in het tekstvak en plak:
```
queued
```

---

**Actie 9 – Stel variabele in**
1. Tik op het zoekveld en typ: `stel variabele in`
2. Tik op **Stel variabele in**.
3. Tik op **Variabelenaam** en plak:
```
Status
```
4. Controleer: achter **op** staat **Tekst**.

---

### 4. Wachten tot het klaar is

**Actie 10 – Herhaal**
1. Tik op het zoekveld en typ: `herhaal`
2. Tik op **Herhaal** (niet "Herhaal met elk").
3. Tik op het getal (**10**) en vervang het door:
```
200
```
Er staan nu twee regels: **Herhaal 200 keer** en **Einde herhaal**.

---

**Actie 11 – Als**
1. Tik op het zoekveld en typ: `als`
2. Tik op **Als**.
3. Houd de nieuwe actie **Als** vast en sleep hem tussen **Herhaal 200 keer** en **Einde herhaal**.
   (De regels **Anders** en **Einde als** schuiven mee.)
4. Tik op **Invoer** en kies **Status**.
5. Tik op **Voorwaarde** en kies **is niet**.
6. Tik op **Tekst** en plak:
```
completed
```

---

**Actie 12 – Als**
1. Tik op het zoekveld en typ: `als`
2. Tik op **Als**.
3. Sleep hem direct onder **Als Status is niet completed** (dus vóór de eerste **Anders**).
4. Tik op **Invoer** en kies **Status**.
5. Tik op **Voorwaarde** en kies **is niet**.
6. Tik op **Tekst** en plak:
```
error
```

---

**Actie 13 – Wacht**
1. Tik op het zoekveld en typ: `wacht`
2. Tik op **Wacht**.
3. Sleep hem direct onder **Als Status is niet error**.
4. Tik op het getal (**1**) en vervang het door:
```
3
```

---

**Actie 14 – Haal inhoud van URL op**
1. Tik op het zoekveld en typ: `inhoud van url`
2. Tik op **Haal inhoud van URL op**.
3. Sleep hem direct onder **Wacht 3 seconden**.
4. Tik op **URL** en plak:
```
https://api.eu.assemblyai.com/v2/transcript/
```
5. Laat de cursor aan het eind staan. Tik boven het toetsenbord op **ID**.
6. Tik op het pijltje **›**.
7. Laat **Methode** op **GET** staan.
8. Tik op **Headers** → **Voeg nieuwe header toe**.
9. Tik op **Sleutel** en plak:
```
authorization
```
10. Tik op **Tekst** ernaast. Tik boven het toetsenbord op **Sleutel**.

---

**Actie 15 – Stel variabele in**
1. Tik op het zoekveld en typ: `stel variabele in`
2. Tik op **Stel variabele in**.
3. Sleep hem direct onder actie 14.
4. Tik op **Variabelenaam** en plak:
```
Resultaat
```
5. Controleer: achter **op** staat **Inhoud van URL**.

---

**Actie 16 – Haal woordenboekwaarde op**
1. Tik op het zoekveld en typ: `woordenboekwaarde`
2. Tik op **Haal woordenboekwaarde op**.
3. Sleep hem direct onder actie 15.
4. Tik op **Sleutel** en plak:
```
status
```
5. Tik op het woord achter **in** en kies **Resultaat**.

---

**Actie 17 – Stel variabele in**
1. Tik op het zoekveld en typ: `stel variabele in`
2. Tik op **Stel variabele in**.
3. Sleep hem direct onder actie 16.
4. Tik op **Variabelenaam** en plak:
```
Status
```
5. Controleer: achter **op** staat **Woordenboekwaarde**.

Controle blok 4 – zo moet het eruitzien:
```
Herhaal 200 keer
    Als Status is niet completed
        Als Status is niet error
            Wacht 3 seconden
            Haal inhoud van URL op
            Stel variabele in Resultaat
            Haal woordenboekwaarde op status
            Stel variabele in Status
        Anders
        Einde als
    Anders
    Einde als
Einde herhaal
```

---

### 5. Regels maken

Deze acties komen **onder Einde herhaal** (ze komen daar vanzelf, niet slepen).

**Actie 18 – Haal woordenboekwaarde op**
1. Tik op het zoekveld en typ: `woordenboekwaarde`
2. Tik op **Haal woordenboekwaarde op**.
3. Tik op **Sleutel** en plak:
```
utterances
```
4. Tik op het woord achter **in** en kies **Resultaat**.

---

**Actie 19 – Herhaal met elk**
1. Tik op het zoekveld en typ: `herhaal met elk`
2. Tik op **Herhaal met elk**.
3. Controleer: er staat **Herhaal met elk onderdeel in Woordenboekwaarde**.

---

**Actie 20 – Haal woordenboekwaarde op**
1. Tik op het zoekveld en typ: `woordenboekwaarde`
2. Tik op **Haal woordenboekwaarde op**.
3. Sleep hem tussen **Herhaal met elk** en **Einde herhaal**.
4. Tik op **Sleutel** en plak:
```
speaker
```
5. Tik op het woord achter **in** en kies **Herhaalonderdeel**.

---

**Actie 21 – Stel variabele in**
1. Tik op het zoekveld en typ: `stel variabele in`
2. Tik op **Stel variabele in**.
3. Sleep hem direct onder actie 20.
4. Tik op **Variabelenaam** en plak:
```
Spreker
```

---

**Actie 22 – Haal woordenboekwaarde op**
1. Tik op het zoekveld en typ: `woordenboekwaarde`
2. Tik op **Haal woordenboekwaarde op**.
3. Sleep hem direct onder actie 21.
4. Tik op **Sleutel** en plak:
```
text
```
5. Tik op het woord achter **in** en kies **Herhaalonderdeel**.

---

**Actie 23 – Tekst**
1. Tik op het zoekveld en typ: `tekst`
2. Tik op **Tekst**.
3. Sleep hem direct onder actie 22.
4. Tik in het tekstvak en wis wat er staat.
5. Typ het woord Spreker en een spatie.
6. Tik boven het toetsenbord op **Spreker**.
7. Typ een dubbele punt en een spatie.
8. Tik boven het toetsenbord op **Woordenboekwaarde**.

In de notitie wordt dat bijvoorbeeld: `Spreker A: Goedemorgen.`

---

**Actie 24 – Combineer tekst**
Deze komt onder **Einde herhaal**.
1. Tik op het zoekveld en typ: `combineer`
2. Tik op **Combineer tekst**.
3. Controleer: er staat **Combineer Herhaalresultaten met Nieuwe regel**.
   Staat er **Spaties**: tik erop en kies **Nieuwe regel**.

---

### 6. Opslaan in Notities

**Actie 25 – Haal naam op**
1. Tik op het zoekveld en typ: `haal naam op`
2. Tik op **Haal naam op**.
3. Tik op het woord in de actie en kies **Opdrachtinvoer**.

---

**Actie 26 – Tekst**
1. Tik op het zoekveld en typ: `tekst`
2. Tik op **Tekst**.
3. Tik in het tekstvak en wis wat er staat.
4. Tik boven het toetsenbord op **Naam**.
5. Druk twee keer op Enter.
6. Tik boven het toetsenbord op **Gecombineerde tekst**.

---

**Actie 27 – Maak notitie aan**
1. Tik op het zoekveld en typ: `maak notitie`
2. Tik op **Maak notitie aan**.
3. Controleer: er staat **Tekst** in de actie.

---

**Klaar.** Tik rechtsboven op **Gereed**.

---

## Testen

1. Neem in Dictafoon 30 seconden op met twee stemmen.
2. Tik op de opname → **•••** → **Deel** → **Gesprek uitschrijven**.
3. De eerste keer vraagt iOS of de opdracht verbinding mag maken met `api.eu.assemblyai.com`:
   kies **Sta altijd toe**.
4. Na ±30 seconden staat de notitie in Notities.

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
