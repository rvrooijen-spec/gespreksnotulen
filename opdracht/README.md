# Opdracht "Gesprek uitschrijven" (iPhone, zonder app)

Een iPhone-opdracht (Shortcut) die een Nederlands gesprek laat uitschrijven door **AssemblyAI (EU-server)**,
met sprekers, en het resultaat opslaat en deelt met ChatGPT of Claude.

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
3. Je kiest wie jij bent uit een lijstje met de eerste zin van elke spreker. Je naam wordt onthouden.
   De anderen heten **Persoon 2**, **Persoon 3**, … en je mag ze een naam geven.
4. Tekst in de vorm:
   ```
   Teamoverleg
   vrijdag 17 oktober 2026 om 14:30

   [00:03] Ruben: Goedemorgen allemaal.
   [00:05] Persoon 2: Goedemorgen.
   ```
5. Opslaan in **Notities**, op het klembord, en het **Deel**-menu opent (kies ChatGPT, Claude, Mail, …).
   Het gesprek gaat ongewijzigd mee; alleen een instructie wordt erboven gezet.

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
- **Niet automatisch versturen naar ChatGPT/Claude.** De opdracht opent het deelmenu en zet de tekst op
  het klembord; je kiest zelf de app en tikt op versturen. Bij lange tekst maakt de app er soms een
  bijlage van; de inhoud blijft gelijk.
- **Datum bij gedeelde opnames** is de aanmaakdatum van het bestand; bij sommige opnames is dat het
  moment van delen in plaats van opnemen. Pas het dan aan in de titel.
- **Lange gesprekken**: 1 uur ≈ 600–800 regels; het omzetten op de iPhone kan dan een halve minuut duren.
- **Sprekerherkenning is niet perfect**: soms worden twee mensen samengevoegd of één persoon gesplitst.
- **Privacy**: de audio gaat naar AssemblyAI in de EU. Wat je daarna deelt met ChatGPT/Claude gaat naar die dienst.

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

Sprekers A, B, … krijgen nummers 1, 2, … in de volgorde waarin ze voor het eerst praten.
In de regels komt eerst een tijdelijke code zoals `{S1}`; die wordt in blok 8 vervangen door de naam.

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
55         Zoek overeenkomsten  ^.{1,80}  in  [Zin]              (Match Text)
56         Tekst   [Aantal]: [Overeenkomsten]…
57         Voeg toe aan variabele  Keuzes                        (Add to Variable)
58     Einde als
59     Haal woordenboekwaarde op  Waarde  voor  [Letter]  in  [Sprekers]
60     Stel variabele in  Nr  op  [Woordenboekwaarde]

       -- tijd mm:ss --
61     Haal woordenboekwaarde op  Waarde  voor  start  in  [Herhaalonderdeel]
62     Bereken  [Woordenboekwaarde]  ÷  1000
63     Rond getal af  [Rekenresultaat]  naar beneden             (Round Number → Always Round Down)
64     Stel variabele in  Sec  op  [Afgerond getal]
65     Bereken  [Sec]  ÷  60
66     Rond getal af  [Rekenresultaat]  naar beneden
67     Tekst   0[Afgerond getal]
68     Vervang  ^0(\d\d)  door  $1  in  [Tekst]                  (Replace Text)
          tik op ›: Reguliere expressie aan
69     Stel variabele in  MM  op  [Bijgewerkte tekst]
70     Bereken  [Sec]  …  Modulus  60        (tik op de bewerking → ••• / wetenschappelijk → "Modulus" of "%")
71     Tekst   0[Rekenresultaat]
72     Vervang  ^0(\d\d)  door  $1  in  [Tekst]     (Reguliere expressie aan)
73     Stel variabele in  SS  op  [Bijgewerkte tekst]

74     Tekst   [[MM]:[SS]] {S[Nr]}: [Zin]
75     Voeg toe aan variabele  Regels
76 Einde herhaal

77 Combineer  [Regels]  met  Nieuwe regel                        (Combine Text)
78 Stel variabele in  Gesprek  op  [Gecombineerde tekst]
```
Toelichting regel 74: de buitenste blokhaken typ je zelf, `MM` en `SS` zijn variabelen, `{S` en `}` typ je
zelf met de variabele `Nr` ertussen. Resultaat: `[03:12] {S2}: Dat klopt.`

## Blok 7 – Wie ben jij? (verplicht, naam wordt onthouden)

```
79 Haal bestand op uit map                                       (Get File from Folder)
       Map: Opdrachten (iCloud Drive)  ·  Pad: mijnnaam.txt
       Fout indien niet gevonden: uit
80 Vraag om invoer  "Hoe heet jij?"     Standaardantwoord: [Bestand]
81 Stel variabele in  MijnNaam  op  [Gevraagde invoer]
82 Tekst   [MijnNaam]
83 Bewaar bestand  [Tekst]                                       (Save File)
       Vraag waar op te slaan: uit  ·  Map: Opdrachten  ·  Subpad: mijnnaam.txt
       Overschrijf indien bestand bestaat: aan

84 Kies uit lijst  [Keuzes]       Prompt: "Wie ben jij?"         (Choose from List)
85 Splits tekst  [Gekozen onderdeel]  door  Aangepast  :          (Split Text)
86 Haal onderdeel uit lijst  Eerste onderdeel  van  [Gesplitste tekst]   (Get Item from List)
87 Stel variabele in  IkNr  op  [Onderdeel uit lijst]
```
De eerste keer typ je je naam; daarna staat hij al ingevuld en tik je alleen op **Gereed**.
In het lijstje zie je bijvoorbeeld `1: Goedemorgen allemaal, zullen we beginnen…` en `2: Ja prima…`.

## Blok 8 – Namen invullen

```
88  Kies uit menu  "Namen van de anderen invullen?"              (Choose from Menu)
        Opties:  Nee  /  Ja
89  ‣ Nee:   Tekst  nee   →  Stel variabele in  Invullen
90  ‣ Ja:    Tekst  ja    →  Stel variabele in  Invullen
91  Einde menu

92  Getal  2
93  Stel variabele in  Volgnummer  op  [Getal]
94  Herhaal  [Aantal]  keer
95      Als  [Herhaalindex]  is  [IkNr]
96          Stel variabele in  Naam  op  [MijnNaam]
97      Anders
98          Tekst   Persoon [Volgnummer]
99          Stel variabele in  Naam  op  [Tekst]
100         Als  [Invullen]  is  ja
101             Haal onderdeel uit lijst  Onderdeel op index  [Herhaalindex]  van  [Keuzes]
102             Vraag om invoer  "Naam voor [Onderdeel uit lijst]"   Standaardantwoord: [Naam]
103             Stel variabele in  Naam  op  [Gevraagde invoer]
104         Einde als
105         Bereken  [Volgnummer]  +  1
106         Stel variabele in  Volgnummer  op  [Rekenresultaat]
107     Einde als
108     Vervang  {S[Herhaalindex]}  door  [Naam]  in  [Gesprek]      (Reguliere expressie uit)
109     Stel variabele in  Gesprek  op  [Bijgewerkte tekst]
110 Einde herhaal

111 Tekst
        [Titel]
        [Datum]

        [Gesprek]
112 Stel variabele in  Verslag  op  [Tekst]
```
Ben jij bijvoorbeeld spreker 2, dan heet spreker 1 "Persoon 2" en spreker 3 "Persoon 3": jij telt altijd als nummer 1.

## Blok 9 – Opslaan

```
113 Maak notitie aan  met  [Verslag]                             (Create Note)
        (optioneel: kies een map, bijv. "Gesprekken")
```
Liever een bestand? Gebruik dan in plaats daarvan: **Stel naam in** (Set Name) `[Titel].txt` op `[Verslag]`
→ **Bewaar bestand** (Map bijv. iCloud Drive/Gesprekken, Vraag waar op te slaan: uit).

## Blok 10 – Delen met ChatGPT of Claude

```
114 Kies uit menu  "Wat wil je ermee doen?"
        Opties:  Samenvatting en actiepunten
                 Notulen maken
                 Mijn inbreng: zakelijk verslag functioneren
                 Alleen de tekst
115 ‣ Samenvatting en actiepunten:
        Tekst  (zie instructie A hieronder, met daaronder [Verslag])
        Stel variabele in  Bericht
116 ‣ Notulen maken:
        Tekst  (instructie B + [Verslag])  →  Stel variabele in  Bericht
117 ‣ Mijn inbreng: zakelijk verslag functioneren:
        Tekst  (instructie C + [Verslag])  →  Stel variabele in  Bericht
118 ‣ Alleen de tekst:
        Stel variabele in  Bericht  op  [Verslag]
119 Einde menu

120 Kopieer naar klembord  [Bericht]                             (Copy to Clipboard)
121 Deel  [Bericht]                                              (Share)
```
In het deelmenu kies je **ChatGPT** of **Claude** (de apps moeten geïnstalleerd zijn). Staat de app er niet
bij, open hem dan zelf en plak (de tekst staat al op het klembord).

### Instructieteksten

Zet in elk Tekst-blok eerst de instructie, dan een lege regel, `---`, en daaronder de variabele **[Verslag]**.

**A – Samenvatting en actiepunten**
```
Hieronder staat een automatisch uitgeschreven gesprek (sprekerherkenning en woorden kunnen fouten bevatten).
Maak in het Nederlands:
1. Een korte samenvatting (max. 10 zinnen).
2. De genomen besluiten.
3. Actiepunten als lijst: wie – wat – wanneer (als dat genoemd is).
Verzin niets dat niet in het gesprek staat.
```

**B – Notulen maken**
```
Hieronder staat een automatisch uitgeschreven gesprek (sprekerherkenning en woorden kunnen fouten bevatten).
Maak er zakelijke notulen van in het Nederlands met: titel, datum, aanwezigen (de sprekers),
besproken onderwerpen per agendapunt, besluiten en actiepunten (wie – wat – wanneer).
Schrijf in de verleden tijd en in de derde persoon. Verzin niets dat niet in het gesprek staat.
```

**C – Mijn inbreng: zakelijk verslag functioneren** (zet hier de variabele **[MijnNaam]** in)
```
Hieronder staat een automatisch uitgeschreven gesprek (sprekerherkenning en woorden kunnen fouten bevatten).
Ik ben [MijnNaam]. Maak een puur zakelijk verslag van mijn inbreng, bedoeld voor mijn functioneren:
wat ik heb ingebracht, voorgesteld, toegezegd, uitgelegd en besloten.
- Gebruik alleen wat [MijnNaam] zelf zegt; uitspraken van anderen alleen als korte context.
- Laat privézaken, smalltalk, gezondheid, familie en andere randzaken volledig weg.
- Zakelijke, neutrale toon, in de ik-vorm, als opsomming per onderwerp.
- Verzin niets dat niet in het gesprek staat.
```

---

## Testen

1. Neem in Dictafoon een kort gesprekje op (twee stemmen, 30 s) → ••• → **Deel** → **Gesprek uitschrijven**.
2. De eerste keer vraagt iOS of de opdracht verbinding mag maken met `api.eu.assemblyai.com`
   en bestanden mag lezen/bewaren: kies **Sta altijd toe**.
3. Controleer de notitie: staan er regels als `[00:03] Jouw naam: …`?

## Problemen oplossen

| Wat je ziet | Oplossing |
|---|---|
| `Uitschrijven mislukt: …speech_models…` | Controleer de spelling `universal-3-5-pro` en dat `speech_models` een **Array** is, geen Tekst. |
| Fout `Unauthorized` / `401` | Header moet precies `authorization` heten, waarde = sleutel zonder extra spaties. |
| Lege notitie | Kijk of blok 5 bij `completed` stopt (kleine letters) en of regel 43 `utterances` heet. |
| Er staat nog `{S1}` in de tekst | Regel 108: `{S`, variabele **Herhaalindex**, `}` – zonder spaties. Reguliere expressie uit. |
| Tijden kloppen niet | Regel 68/72: "Reguliere expressie" aanzetten. Regel 63/66: afronden **naar beneden**. |
| Datum leeg | Vervang in regel 13 **Aanmaakdatum** door **Huidige datum**. |
| Opdracht verschijnt niet in Dictafoon-deelmenu | (i) → **Toon in deelmenu** aan, invoertypen **Media** en **Bestanden**; scroll in het deelmenu naar beneden of kies **Wijzig acties**. |
| "Kan niet delen: te veel gegevens" | Zie Voorbereiding stap 1. |

Werkt het niet? Tik onderaan op ▶︎ terwijl de opdracht open staat: Opdrachten laat dan bij elke actie zien
wat er gebeurt en waar het misgaat.
