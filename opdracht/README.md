# Opdracht "Gesprek uitschrijven" (iPhone, zonder app)

Een iPhone-opdracht (Shortcut) die een Nederlands gesprek laat uitschrijven door **AssemblyAI (EU-server)**,
met sprekers, en het resultaat opslaat in **Notities**.

Je bouwt hem zelf na in de **Opdrachten**-app. Een kant-en-klaar `.shortcut`-bestand kan niet:
Apple accepteert alleen bestanden die op een Mac of iPhone ondertekend zijn.

> **Namen van acties.** De Nederlandse naam staat **vetgedrukt**, de Engelse naam tussen haakjes.
> Kun je een actie niet vinden, typ dan een deel van de naam in het zoekveld onderaan
> (bijv. "URL", "woordenboek", "herhaal"). Apple verandert soms een woord per iOS-versie.

---

## Wat je krijgt

1. Starten door de opdracht te openen (je neemt dan direct op), **of** vanuit Dictafoon:
   opname → ••• → **Deel** → **Gesprek uitschrijven** (werkt ook voor opnames van je Apple Watch).
2. Uploaden naar `api.eu.assemblyai.com`, wachten tot het klaar is (meestal 30 s – 2 min).
3. De sprekers heten **Persoon 1**, **Persoon 2**, … in de volgorde waarin ze voor het eerst praten.
4. Tekst in de vorm:
   ```
   Teamoverleg
   vrijdag 17 oktober 2026 om 14:30

   [00:03] Persoon 1: Goedemorgen allemaal.
   [00:05] Persoon 2: Goedemorgen.
   ```
5. De tekst wordt opgeslagen als nieuwe notitie in **Notities**.

## Wat níet kan in Opdrachten (eerlijk)

- **Geen ondertekend bestand zonder Mac** → zelf nabouwen (±30–45 min, eenmalig).
- **Geen "herhaal tot klaar"**. De opdracht herhaalt een vast aantal keren (200 × 3 s = max. 10 min)
  en slaat de rest snel over zodra het klaar is.
- **De API-sleutel staat leesbaar in de opdracht.** Deel de opdracht dus nooit met iemand
  (ook geen iCloud-link), anders kunnen zij op jouw kosten uitschrijven.
- **Opnemen ín de opdracht** stopt mogelijk als je de iPhone vergrendelt of naar een andere app gaat.
  Voor lange gesprekken: neem op met **Dictafoon** (iPhone of Apple Watch, werkt met scherm uit) en deel daarna.
- **De opdracht draait niet op de Apple Watch.** Neem op het horloge op met Dictafoon; de opname komt
  vanzelf op de iPhone en die deel je daar.
- **Datum bij gedeelde opnames** is de aanmaakdatum van het bestand; bij sommige opnames is dat het
  moment van delen in plaats van opnemen. Pas het dan aan in de titel.
- **Lange gesprekken**: 1 uur ≈ 600–800 regels; het omzetten op de iPhone kan dan een halve minuut duren.
- **Sprekerherkenning is niet perfect**: soms worden twee mensen samengevoegd of één persoon gesplitst.
- **Privacy**: de audio gaat naar AssemblyAI in de EU.

---

## Voorbereiding (eenmalig)

1. **Instellingen → Apps → Opdrachten → Geavanceerd** → zet **Sta delen van grote hoeveelheden gegevens toe** aan.
   (Anders vraagt iOS bij elke upload om toestemming of blokkeert het grote bestanden.)
2. Open **Opdrachten** → **+** (nieuwe opdracht). Tik bovenaan op de naam → **Wijzig naam** →
   `Gesprek uitschrijven`.
3. Tik onderaan op de **(i)** (of het pijltje naast de naam → **Details**) en zet **Toon in deelmenu** aan.
   Bovenaan verschijnt nu een blok **Ontvang … uit Deelmenu**.
   - Tik op het eerste woord en laat alleen **Media** en **Bestanden** aangevinkt.
   - Bij **Als er geen invoer is** kies **Ga door**.

## Werkwijze bij het bouwen

- Een actie toevoegen: zoekveld onderaan → actie aantikken.
- **Variabelen**: met de actie **Stel variabele in** (Set Variable) geef je een uitkomst een naam.
  Later kies je die naam via **Variabele selecteren** of door in een tekstveld te tikken en boven het
  toetsenbord de variabele te kiezen. Hieronder staan variabelen als **[Naam]**.
- "Uitkomst van de vorige actie" heet in Opdrachten een *magische variabele* (bijv. **Inhoud van URL**,
  **Woordenboekwaarde**, **Herhaalonderdeel**). Die kies je ook boven het toetsenbord.
- Inspringing hieronder = binnen een **Als** of **Herhaal**-blok.

---

## Blok 1 – Audio: opnemen of gedeeld bestand

```
1  Als  [Opdrachtinvoer]  heeft geen waarde                     (If)
2      Neem audio op                                             (Record Audio)
          tik op ›: Begin met opnemen: Direct · Eindig met opnemen: Bij tik
3      Stel variabele in  Audio  op  [Opgenomen audio]
4  Anders
5      Stel variabele in  Audio  op  [Opdrachtinvoer]
6  Einde als
```

## Blok 2 – Sleutel, titel en datum

```
7  Tekst   <plak hier je AssemblyAI-sleutel>                    (Text)
8  Stel variabele in  Sleutel  op  [Tekst]

9  Haal naam op  [Audio]                                         (Get Name)
10 Vraag om invoer  "Titel van het gesprek"                      (Ask for Input)
       Standaardantwoord: [Naam]
11 Stel variabele in  Titel  op  [Gevraagde invoer]

12 Haal details van bestanden op  Aanmaakdatum  van  [Audio]     (Get Details of Files)
13 Formatteer datum  [Aanmaakdatum]                              (Format Date)
       Datumnotatie: Aangepast →  EEEE d MMMM yyyy 'om' HH:mm
14 Stel variabele in  Datum  op  [Opgemaakte datum]
```
Met een Nederlandse iPhone geeft dit bijvoorbeeld `vrijdag 17 oktober 2026 om 14:30`.

## Blok 3 – Uploaden naar AssemblyAI (EU)

```
15 Haal inhoud van URL op                                        (Get Contents of URL)
       URL:     https://api.eu.assemblyai.com/v2/upload
       tik op ›: Methode: POST
       Headers: + Nieuwe header →  authorization  =  [Sleutel]
       Hoofdtekst verzoek: Bestand  →  [Audio]
16 Haal woordenboekwaarde op  Waarde  voor  upload_url  in  [Inhoud van URL]   (Get Dictionary Value)
17 Stel variabele in  UploadURL  op  [Woordenboekwaarde]
```

## Blok 4 – Uitschrijven starten

```
18 Haal inhoud van URL op
       URL:     https://api.eu.assemblyai.com/v2/transcript
       Methode: POST
       Headers: authorization = [Sleutel]
       Hoofdtekst verzoek: JSON, met deze velden (+ Nieuw veld):
          audio_url       Tekst              [UploadURL]
          language_code   Tekst              nl
          speaker_labels  Booleaanse waarde  Waar (aan)
          speech_models   Array (Reeks)      →  Tekst  universal-3-5-pro
                                              →  Tekst  universal-2
19 Haal woordenboekwaarde op  Waarde  voor  id  in  [Inhoud van URL]
20 Stel variabele in  ID  op  [Woordenboekwaarde]
21 Tekst   queued
22 Stel variabele in  Status  op  [Tekst]
```
Let op: precies `universal-3-5-pro` met streepjes (met puntjes wordt geweigerd).
Weet je vooraf hoeveel mensen er praten, dan kun je een veld `speakers_expected` (Getal) toevoegen;
meestal is dat niet nodig.

## Blok 5 – Wachten tot het klaar is

```
23 Herhaal  200  keer                                            (Repeat)
24     Als  [Status]  is niet  completed
25         Als  [Status]  is niet  error
26             Wacht  3  seconden                                (Wait)
27             Haal inhoud van URL op
                   URL: https://api.eu.assemblyai.com/v2/transcript/[ID]
                   Methode: GET ·  Headers: authorization = [Sleutel]
28             Stel variabele in  Resultaat  op  [Inhoud van URL]
29             Haal woordenboekwaarde op  Waarde  voor  status  in  [Resultaat]
30             Stel variabele in  Status  op  [Woordenboekwaarde]
31         Einde als
32     Einde als
33 Einde herhaal

34 Als  [Status]  is niet  completed
35     Haal woordenboekwaarde op  Waarde  voor  error  in  [Resultaat]
36     Toon waarschuwing  "Uitschrijven mislukt: [Woordenboekwaarde]"   (Show Alert)
37     Stop deze opdracht                                        (Stop This Shortcut)
38 Einde als
```
Typ bij 24, 25 en 34 de woorden `completed` en `error` precies zo (kleine letters).

## Blok 6 – Regels maken en sprekers nummeren

Sprekers A, B, … worden Persoon 1, 2, … in de volgorde waarin ze voor het eerst praten.

```
39 Woordenboek   (leeg laten)                                    (Dictionary)
40 Stel variabele in  Sprekers  op  [Woordenboek]
41 Getal  0                                                      (Number)
42 Stel variabele in  Aantal  op  [Getal]

43 Haal woordenboekwaarde op  Waarde  voor  utterances  in  [Resultaat]
44 Herhaal met elk  [Woordenboekwaarde]                          (Repeat with Each)

45     Haal woordenboekwaarde op  Waarde  voor  speaker  in  [Herhaalonderdeel]
46     Stel variabele in  Letter  op  [Woordenboekwaarde]
47     Haal woordenboekwaarde op  Waarde  voor  text  in  [Herhaalonderdeel]
48     Stel variabele in  Zin  op  [Woordenboekwaarde]

49     Haal woordenboekwaarde op  Waarde  voor  [Letter]  in  [Sprekers]
50     Als  [Woordenboekwaarde]  heeft geen waarde
51         Bereken  [Aantal]  +  1                               (Calculate)
52         Stel variabele in  Aantal  op  [Rekenresultaat]
53         Stel woordenboekwaarde in  [Letter]  op  [Aantal]  in  [Sprekers]   (Set Dictionary Value)
54         Stel variabele in  Sprekers  op  [Woordenboek]
55     Einde als
56     Haal woordenboekwaarde op  Waarde  voor  [Letter]  in  [Sprekers]
57     Stel variabele in  Nr  op  [Woordenboekwaarde]

       -- tijd mm:ss --
58     Haal woordenboekwaarde op  Waarde  voor  start  in  [Herhaalonderdeel]
59     Bereken  [Woordenboekwaarde]  ÷  1000
60     Rond getal af  [Rekenresultaat]  naar beneden             (Round Number → Always Round Down)
61     Stel variabele in  Sec  op  [Afgerond getal]
62     Bereken  [Sec]  ÷  60
63     Rond getal af  [Rekenresultaat]  naar beneden
64     Tekst   0[Afgerond getal]
65     Vervang  ^0(\d\d)  door  $1  in  [Tekst]                  (Replace Text)
          tik op ›: Reguliere expressie aan
66     Stel variabele in  MM  op  [Bijgewerkte tekst]
67     Bereken  [Sec]  …  Modulus  60        (tik op de bewerking → ••• / wetenschappelijk → "Modulus" of "%")
68     Tekst   0[Rekenresultaat]
69     Vervang  ^0(\d\d)  door  $1  in  [Tekst]     (Reguliere expressie aan)
70     Stel variabele in  SS  op  [Bijgewerkte tekst]

71     Tekst   [[MM]:[SS]] Persoon [Nr]: [Zin]
72     Voeg toe aan variabele  Regels                         (Add to Variable)
73 Einde herhaal

74 Combineer  [Regels]  met  Nieuwe regel                        (Combine Text)
75 Stel variabele in  Gesprek  op  [Gecombineerde tekst]
```
Toelichting regel 71: de blokhaken, de dubbele punten en het woord `Persoon` typ je zelf; `MM`, `SS`, `Nr` en
`Zin` zijn variabelen. Resultaat: `[03:12] Persoon 2: Dat klopt.`

## Blok 7 – Opslaan in Notities

```
76 Tekst
       [Titel]
       [Datum]

       [Gesprek]
77 Maak notitie aan  met  [Tekst]                                (Create Note)
       (optioneel: kies een map, bijv. "Gesprekken")
78 Toon notitie  [Notitie]   (Show Note — optioneel: opent de notitie meteen)
```
Notities gebruikt de eerste regel (de titel) als naam van de notitie.

Wil je de sprekers later een naam geven, doe dat dan in Notities: ••• → **Zoek in notitie** → het
vergrootglas/de pijl → **Zoek en vervang** (bijv. `Persoon 1` → `Ruben`).

---

## Testen

1. Neem in Dictafoon een kort gesprekje op (twee stemmen, 30 s) → ••• → **Deel** → **Gesprek uitschrijven**.
2. De eerste keer vraagt iOS of de opdracht verbinding mag maken met `api.eu.assemblyai.com`
   en bestanden mag lezen/bewaren: kies **Sta altijd toe**.
3. Controleer de notitie: staan er regels als `[00:03] Persoon 1: …`?

## Problemen oplossen

| Wat je ziet | Oplossing |
|---|---|
| `Uitschrijven mislukt: …speech_models…` | Controleer de spelling `universal-3-5-pro` en dat `speech_models` een **Array** is, geen Tekst. |
| Fout `Unauthorized` / `401` | Header moet precies `authorization` heten, waarde = sleutel zonder extra spaties. |
| Lege notitie | Kijk of blok 5 bij `completed` stopt (kleine letters) en of regel 43 `utterances` heet. |
| Tijden kloppen niet | Regel 65/69: "Reguliere expressie" aanzetten. Regel 60/63: afronden **naar beneden**. |
| Datum leeg | Vervang in regel 13 **Aanmaakdatum** door **Huidige datum**. |
| Opdracht verschijnt niet in Dictafoon-deelmenu | (i) → **Toon in deelmenu** aan, invoertypen **Media** en **Bestanden**; scroll in het deelmenu naar beneden of kies **Wijzig acties**. |
| "Kan niet delen: te veel gegevens" | Zie Voorbereiding stap 1. |

Werkt het niet? Tik onderaan op ▶︎ terwijl de opdracht open staat: Opdrachten laat dan bij elke actie zien
wat er gebeurt en waar het misgaat.
