# UL Fitness – Flutter Standalone App Spec (v3)

> **Zielplattform:** Android (Flutter)
> **Datenhaltung:** Lokal (SQLite / Drift) — kein Server, kein Internet nötig
> **Sprache:** Deutsch (UI), Englisch (Code)
> **Modus:** Single-User — kein Login, kein Auth

---

## 1. Architektur

```
lib/
├── main.dart
├── models/           # Datenbank-Entitys & DTOs
│   ├── gym.dart
│   ├── exercise.dart
│   ├── exercise_alias.dart
│   ├── workout.dart
│   ├── workout_exercise.dart
│   ├── workout_set.dart
│   └── workout_template.dart
├── database/         # Drift (SQLite) Database + DAOs
│   ├── app_database.dart
│   └── daos/
├── screens/          # Alle Bildschirme
│   ├── home_screen.dart
│   ├── active_workout_screen.dart
│   ├── workout_detail_screen.dart
│   ├── exercise_list_screen.dart
│   ├── gym_management_screen.dart   # NEU (v3)
│   ├── analyse_screen.dart
│   └── splash_screen.dart
├── widgets/          # Wiederverwendbare Komponenten
│   ├── exercise_card.dart
│   ├── exercise_picker_dialog.dart
│   ├── exercise_edit_dialog.dart
│   ├── gym_edit_dialog.dart         # NEU (v3)
│   ├── template_editor_dialog.dart  # NEU (v3)
│   ├── finish_dialog.dart
│   ├── rest_timer_overlay.dart
│   ├── simple_line_chart.dart
│   ├── pr_card.dart
│   └── stat_card.dart
├── utils/            # Hilfsfunktionen
│   ├── constants.dart
│   └── formatters.dart
└── theme/            # Farben, TextStyles, Theme
    └── app_theme.dart
```

**Empfohlene Libraries:**
| Library | Zweck |
|---|---|
| `drift` (ehem. moor) | SQLite ORM mit Type-Safety |
| `sqlite3_flutter_libs` | Native SQLite für Android |
| `path_provider` | Datenbank-Pfad |
| `fl_chart` | Diagramme (besser als Canvas-Canvas) oder Custom Canvas |
| `intl` | Datums-/Zahlenformatierung |
| `uuid` | Eindeutige IDs |
| `material3` / `flutter_material_pickers` | DropDowns, DatumsPicker |

---

## 2. Datenbank-Schema (SQLite)

### Tabelle: `gyms`
| Spalte | Typ | Constraints |
|---|---|---|
| `id` | INTEGER | PK, autoincrement |
| `name` | TEXT | NOT NULL |
| `city` | TEXT | NULLABLE |
| `is_system` | INTEGER | NOT NULL, DEFAULT 0 |
| `created_at` | TEXT | NOT NULL (ISO8601) |

> **v3, geklärt:** Nutzer können eigene Studios anlegen, bearbeiten und löschen (siehe neuer Screen 4.7 "Studios verwalten"). `is_system = 1` markiert nur die beiden vorinstallierten Studios ("Thomas Sport Center", "All Inclusive Fitness") und verhindert deren Löschung (Umbenennen bleibt erlaubt), damit die App nie komplett ohne Studio dasteht. Nutzer-eigene Studios (`is_system = 0`) können frei gelöscht werden — beim Löschen greift `ON DELETE SET NULL` bei zugehörigen `exercises`/`workouts`, sodass historische Trainingsdaten erhalten bleiben, auch wenn das Studio weg ist.

### Tabelle: `exercises`
| Spalte | Typ | Constraints |
|---|---|---|
| `id` | INTEGER | PK, autoincrement |
| `gym_id` | INTEGER | NULLABLE, FK → gyms(id) ON DELETE SET NULL |
| `name` | TEXT | NOT NULL |
| `category` | TEXT | NOT NULL, DEFAULT 'Sonstiges' |
| `kind` | TEXT | NOT NULL, DEFAULT 'free_weight' |
| `icon_key` | TEXT | NOT NULL, DEFAULT 'dumbbell' |
| `is_system` | INTEGER | NOT NULL, DEFAULT 0 |
| `created_at` | TEXT | NOT NULL |

> **Wichtig (v2):** Übungen sind konzeptionell **studio-gebunden**. Existiert dieselbe Übung (z.B. "Beinpresse") in zwei Studios, werden **zwei getrennte `exercises`-Zeilen** angelegt (jeweils mit eigenem `gym_id`) statt einer geteilten Zeile — unterschiedliche Geräte/Winkel führen zu unterschiedlichem Gewichtsverhalten, das nicht vermischt werden soll. `gym_id` bleibt technisch NULLABLE (für generische/globale Katalogeinträge, z.B. Körpergewichtsübungen), aber die Seed-Daten und die Übungsverwaltung sollen pro Studio getrennte Einträge erzeugen, sobald ein Studio ausgewählt ist.

### Tabelle: `exercise_aliases`
| Spalte | Typ | Constraints |
|---|---|---|
| `id` | INTEGER | PK, autoincrement |
| `exercise_id` | INTEGER | NOT NULL, FK → exercises(id) ON DELETE CASCADE |
| `alias` | TEXT | NOT NULL |
| `created_at` | TEXT | NOT NULL |

Unique: `(alias, exercise_id)`

### Tabelle: `workouts`
| Spalte | Typ | Constraints |
|---|---|---|
| `id` | INTEGER | PK, autoincrement |
| `gym_id` | INTEGER | NULLABLE, FK → gyms(id) ON DELETE SET NULL |
| `started_at` | TEXT | NOT NULL (ISO8601) |
| `ended_at` | TEXT | NULLABLE (ISO8601) |
| `notes` | TEXT | NULLABLE |
| `created_at` | TEXT | NOT NULL |

Index: `(gym_id, started_at)`

### Tabelle: `workout_exercises`
| Spalte | Typ | Constraints |
|---|---|---|
| `id` | INTEGER | PK, autoincrement |
| `workout_id` | INTEGER | NOT NULL, FK → workouts(id) ON DELETE CASCADE |
| `exercise_id` | INTEGER | NOT NULL, FK → exercises(id) |
| `order_idx` | INTEGER | NOT NULL |

### Tabelle: `workout_sets`
| Spalte | Typ | Constraints |
|---|---|---|
| `id` | INTEGER | PK, autoincrement |
| `workout_exercise_id` | INTEGER | NOT NULL, FK → workout_exercises(id) ON DELETE CASCADE |
| `set_no` | INTEGER | NOT NULL |
| `reps` | INTEGER | NOT NULL, CHECK ≥ 0 |
| `weight_kg` | REAL | NOT NULL, CHECK ≥ 0 |
| `is_warmup` | INTEGER | NOT NULL, DEFAULT 0 |
| `rpe` | INTEGER | NULLABLE, CHECK 1–10 |
| `is_failure` | INTEGER | NOT NULL, DEFAULT 0 |
| `note` | TEXT | NULLABLE |
| `created_at` | TEXT | NOT NULL |

### Tabelle: `workout_templates`
| Spalte | Typ | Constraints |
|---|---|---|
| `id` | INTEGER | PK, autoincrement |
| `gym_id` | INTEGER | NOT NULL, FK → gyms(id) |
| `name` | TEXT | NOT NULL |
| `created_at` | TEXT | NOT NULL |
| `updated_at` | TEXT | NOT NULL |

Unique: `(gym_id, name)`

### Tabelle: `workout_template_exercises`
| Spalte | Typ | Constraints |
|---|---|---|
| `id` | INTEGER | PK, autoincrement |
| `template_id` | INTEGER | NOT NULL, FK → workout_templates(id) ON DELETE CASCADE |
| `exercise_id` | INTEGER | NOT NULL, FK → exercises(id) |
| `order_idx` | INTEGER | NOT NULL |

> **v3, geklärt:** `default_sets`, `default_reps`, `default_weight_kg` wurden entfernt. Eine Vorlage speichert ausschließlich die **Übungsliste** (welche Übungen, in welcher Reihenfolge) — keine Standardwerte für Sätze/Reps/Gewicht. Beim Start aus einer Vorlage wird jede Übung ohne vorausgefüllte Sätze angelegt; die normalen Ghost-Daten (Abschnitt 9) greifen dann wie bei jeder anderen neu hinzugefügten Übung.

> **v3, Konsistenzregel:** Da Übungen studio-gebunden sind (Abschnitt 2), muss die Anwendungsschicht beim Speichern sicherstellen, dass jede `exercise_id` in `workout_template_exercises` zum `gym_id` des zugehörigen `workout_templates`-Eintrags gehört (SQLite kann diese Cross-Table-Bedingung nicht selbst erzwingen). Dieselbe Regel gilt analog für `workout_exercises.exercise_id` gegenüber `workouts.gym_id`.

---

## 3. Seed-Daten (beim ersten Start)

### Studios
| ID | Name | Stadt |
|---|---|---|
| 1 | Thomas Sport Center | NULL |
| 2 | All Inclusive Fitness | NULL |

### Übungen (mit Kategorie, Art, Icon, Aliase)

> **Hinweis (v2):** Übungen, die in beiden Studios vorkommen können (z.B. "Beinpresse horizontal", "Latzug"), werden beim Seeding **für jedes Studio als eigene Zeile** angelegt (siehe Hinweis in Abschnitt 2). Die folgende Liste beschreibt die Übungsnamen/Metadaten; beim Import ist pro Studio zu iterieren.
>
> **v3, geklärt:** Jede Übung bekommt jetzt eine explizite `category` (einer der 10 Werte aus Abschnitt 6) statt der reinen Muskelgruppen-Überschrift ("Push"/"Pull" waren nur Gliederungshilfen in diesem Dokument, keine echten Kategorien). Außerdem wurde das Duplikat entfernt: "Beinpresse" existierte sowohl als eigener Übungsname als auch als Alias von "Beinpresse horizontal" — die eigenständige Zeile "Beinpresse" wurde gestrichen, der Alias auf "Beinpresse horizontal" bleibt bestehen.

**Beine:**
| Name | Kategorie | Kind | Icon | Aliase |
|---|---|---|---|---|
| Hackenschmidt | Beine | free_weight | leg_press | Hackschmitt, Hack Squat |
| Hip Thrust Machine | Beine | machine | leg_press | — |
| Beinpresse horizontal | Beine | machine | leg_press | Beinpresse |
| Wadenpresse horizontal | Beine | machine | leg_press | — |
| Beinpresse 45° | Beine | machine | leg_press | — |
| Wadenpresse 45° | Beine | machine | leg_press | — |
| Wadenheber sitzend | Beine | machine | leg_press | — |
| Beinstrecker | Beine | machine | leg_press | — |
| Beinbeuger | Beine | machine | leg_press | — |
| Beinbeuger liegend | Beine | machine | leg_press | — |
| Wadenmaschine | Beine | machine | leg_press | — |

**Push:**
| Name | Kategorie | Kind | Icon | Aliase |
|---|---|---|---|---|
| Brustpresse | Brust | machine | bench | Brust |
| Brustfly | Brust | machine | bench | Chest fly |
| Schulterpresse | Schulter | machine | dumbbell | — |
| Seitheben | Schulter | cable | dumbbell | — |
| Trizeps Skull Crush | Arme | free_weight | dumbbell | Skullcrusher |
| Trizeps Kabelzug | Arme | cable | cable | — |

**Pull:**
| Name | Kategorie | Kind | Icon | Aliase |
|---|---|---|---|---|
| Latzug | Rücken | machine | pull_up | — |
| Rudern | Rücken | machine | cable | — |
| Face Pulls | Schulter | cable | cable | — |
| Bizeps Hammer Curls | Arme | free_weight | dumbbell | — |
| Bizeps Kabelzug | Arme | cable | cable | — |
| Rudern Brustgestützt | Rücken | machine | cable | — |

**Core:**
| Name | Kategorie | Kind | Icon | Aliase |
|---|---|---|---|---|
| Hyperextension | Core | machine | bench | — |
| Bauch | Core | machine | dumbbell | — |
| Bauchmaschine | Core | machine | dumbbell | — |

**Unterarme:**
| Name | Kategorie | Kind | Icon | Aliase |
|---|---|---|---|---|
| Unterarm-Innencurls | Unterarme | free_weight | dumbbell | — |
| Unterarm-Außencurls | Unterarme | free_weight | dumbbell | — |

---

## 4. Bildschirme & Funktionen

### 4.1 Splash Screen
- Logo (SVG/PNG) mit Puls-Animation (Alpha + Scale, 2 Sek.)
- App-Name "UL Fitness"
- Lade-Indikator
- Mindestanzeigezeit: 2 Sekunden

### 4.2 Home Screen (Tab: Training)

**Header:**
- "Willkommen!" (headlineLarge, bold)
- Untertitel: "Bleib stark. Trainier konsequent." (bodyLarge, muted)

**"Training starten" Bereich:**
- Pro Studio eine Card mit:
  - Play-Icon in farbigem Quadrat (primaryContainer)
  - Studio-Name (bold)
  - Stadt (falls vorhanden)
  - Tipp-Callback → navigiert zu ActiveWorkoutScreen

**"Vorlagen" Bereich (NEU):**
- Pro Studio: Vorlagen als horizontale Chips
- Tipp auf Chip → startet Workout aus Vorlage: legt für jede Übung der Vorlage eine leere Übungs-Card an (keine vorausgefüllten Sätze, v3 geklärt — siehe Hinweis bei `workout_template_exercises`). Die normalen Ghost-Daten (Abschnitt 9) greifen danach ganz normal beim ersten "Satz"-Klick.
- "Neue Vorlage" Chip mit + Icon → öffnet **TemplateEditorDialog**: Namensfeld + Übungsliste (hinzufügen über ExercisePickerDialog, entfernen, per Drag & Drop sortieren), Speichern legt `workout_template` + `workout_template_exercises` (nur `order_idx`, keine Defaults) an

**"Letzte Trainings" Bereich:**
- Max. 20 Einträge, sortiert nach neuestem
- Pro Card:
  - Studio-Name (bold)
  - Status-Badge: "Fertig" (primary) / "Aktiv" (teal/secondary)
  - Formatierter Startzeitpunkt (dd.MM.yyyy HH:mm)
  - Notizen (falls vorhanden)
  - Tipp-Callback → WorkoutDetailScreen

### 4.3 Aktives Workout Screen

**Header:**
- Studio-Name als headline

**Leerer Zustand:**
- Zentriert: Add-Icon + "Übung hinzufügen um zu starten"

**Übungs-Cards (pro hinzugefügter Übung):**

*Header:*
- Sekundärfarbiges Icon-Quadrat
- Übungsname (bold)
- Kategorie (muted)
- Löschen-Button (Mülleimer, error-farben)

*Satz-Tabelle (in abgerundetem Container):*
- Spaltenüberschriften: "Sat." / "Wdh." / "kg" / "RPE" / (Löschen)
- Pro Satz:
  - Satznummer (bold, primary-farbe)
  - Wiederholungen (OutlinedTextField, numeric, zentriert)
  - Gewicht in kg (OutlinedTextField, decimal, zentriert)
  - RPE 1–10 (OutlinedTextField, numeric, zentriert, Placeholder "-")
  - Warmup-Toggle (Chip: "Aufwärmen") — **NEU**
  - Muskelversagen-Toggle (Chip: "Zum Versagen") — **NEU**
  - Satz-Notiz ( TextField, optional, inline ) — **NEU**
  - Löschen-Button (X-Icon)

*"Satz" Button:*
- TextButton unten rechts
- Fügt neuen Satz hinzu
- **Ghost-Daten (v3, korrigiert):** Es wird **schrittweise durch die Satz-Historie des letzten Trainings dieser Übung im selben Studio** gegangen — 1. Klick auf "Satz" kopiert den 1. Satz dieses letzten Trainings, 2. Klick den 2. Satz, usw. Sobald die Historie erschöpft ist, wird der letzte bekannte Satz wiederholt kopiert. Diese Logik ist identisch mit Abschnitt 9 — die frühere abweichende Kurzbeschreibung ("letzter gespeicherter Satz") war ein Fehler in v1/v2 und ist hiermit korrigiert.

**Untere Leiste (fixiert):**
- "+ Übung" OutlinedButton → öffnet ExercisePickerDialog
- "Fertig" / "Abbrechen" Button:
  - Grün (primary) wenn Übungen vorhanden → öffnet FinishDialog
  - Rot (error) wenn leer → zeigt Abbrechen-Dialog
  - Lade-Spinner beim Speichern

**ExercisePickerDialog:**
- Suchfeld ("Suchen...")
- Filtert nach Name UND Aliase (case-insensitive)
- Zeigt nur Übungen des aktuellen Studios (`gym_id` = aktives Studio, siehe Abschnitt 2)
- Listenelemente: Übungsname + Kategorie
- Bei Auswahl: lädt Ghost-Daten (letzte Sätze), erstellt ActiveExercise

**FinishDialog:**
- Titel: "Training beenden?"
- Zusammenfassung: "{n} Übungen, {m} Sätze"
- Optionales Notiz-Feld ("Notizen (optional)", max. 3 Zeilen)
- Bestätigen: "Speichern & Beenden"
- Abbrechen: "Weiter trainieren"

**Abbrechen-Dialog:**
- Titel: "Training abbrechen?"
- Bestätigen: "Ja, abbrechen" (error)
- Abbrechen: "Weiter"

**Rest-Timer (NEU: verdrahtet):**
- Button "⏸ Rest" in der unteren Leiste (sichtbar wenn mindestens 1 Satz vorhanden)
- Countdown-Overlay ab 90 Sekunden (konfigurierbar)
- Schnell-Reset-Chips: 30s, 60s, 90s, 120s
- Auto-Schließung bei 0
- Haptisches Feedback beim Erreichen von 0

### 4.4 Workout Detail Screen

**Ansichtsmodus:**
- TopBar: "Training ansehen", Zurück-Pfeil
- Inhalt:
  - "Training" Header + Startdatum + Enddatum (falls vorhanden)
  - Notizen-Card (falls vorhanden)
  - Übungs-Cards (read-only):
    - Übungsname (bold)
    - Tabellen-Header: "#" / "Wdh." / "kg" / "RPE"
    - Pro Satz: Nummer, Wdh., Gewicht, RPE (oder "-")

**Bearbeitungsmodus:**
- TopBar: "Training bearbeiten"
- Inhalt:
  - Notiz-Feld (editierbar)
  - Übungs-Cards (editierbar, gleicher ExerciseCard wie aktives Workout)
  - "+ Übung hinzufügen" OutlinedButton
- Untere Leiste:
  - "Übung +" OutlinedButton → ExercisePickerDialog
  - "Speichern" Button mit Lade-Spinner

**Untere Leiste (Ansicht):**
- "Löschen" OutlinedButton (error-farben) → Löschen-Dialog
- "Bearbeiten" Button → wechselt in Bearbeitungsmodus

**Löschen-Dialog:**
- Titel: "Training löschen?"
- Bestätigen: "Löschen" (error)
- Abbrechen: "Abbrechen"

### 4.5 Übungen Verwalten Screen (Tab: Übungen)

**Header:**
- "Übungen verwalten" (headlineMedium)

**Studio-Auswahl:**
- ExposedDropdownMenuBox mit allen Studios + "Alle Studios"-Option
- Auswahl filtert Übungen

**Suchfeld:**
- "Suchen..." — filtert nach Name und Aliase

**Übungsanzahl:**
- "{n} Übungen" (labelMedium, muted)

**Übungsliste (LazyColumn):**
Pro Übung:
- CircleAvatar: erste 2 Buchstaben des IconKeys (farbig)
- Name (bodyLarge, medium)
- Kategorie (bodySmall, muted)
- Art (bodySmall, primary, übersetzt)
- Aliase (bodySmall, muted) — "Aliases: alias1, alias2"
- Bearbeiten-Button (Stift-Icon)
- Löschen-Button (Mülleimer, error)

**"Neue Übung" Button:**
- Full-width Button unten
- Add-Icon + Text
- Neue Übungen werden immer dem aktuell ausgewählten Studio zugeordnet (kein "Alle Studios"-Anlegen möglich; ist "Alle Studios" aktiv, muss vorher ein konkretes Studio gewählt werden)

**ExerciseEditDialog:**
- Titel: "Übung bearbeiten" / "Neue Übung"
- Felder:
  - Name (Required, OutlinedTextField)
  - Kategorie (Dropdown: Brust, Rücken, Beine, Schulter, Arme, Core, Ganzkörper, Cardio, Sonstiges)
  - Art (Dropdown: Maschine, Freigewicht, Kabelzug, Körpergewicht)
  - Icon (Dropdown: Hantel, Beine, Langhantel, Kabelzug, Bank, Klimmzug, Laufband, Fahrrad)
  - Aliase (TextField, kommasepariert)
- Validierung: Name darf nicht leer sein
- Speichern: aktualisiert Übung + diffed Aliase (hinzufügen/entfernen)

**Löschen-Dialog:**
- Titel: "Übung löschen?"
- Text: '"${ex.name}" wirklich löschen?'
- Bestätigen: "Löschen" (error)
- Abbrechen: "Abbrechen"

### 4.6 Analyse Screen (Tab: Analyse)

**Header:**
- "Analyse" (headlineMedium)

**Studio-Filter:**
- ExposedDropdownMenuBox: "Alle Studios" + pro Studio

**Zeitraum-Filter (Chips):**
- 4W (28 Tage), 12W (84 Tage), 6M (180 Tage), 1J (365 Tage), Alle (9999 Tage)

**Übungsauswahl:**
- OutlinedButton ("Übung auswählen..." / gewählte Übung)
- Öffnet ExercisePickerDialog (gefiltert nach gewähltem Studio; bei "Alle Studios" werden alle studio-spezifischen Varianten der Übung separat gelistet, da sie getrennte `exercises`-Zeilen sind)

**Metrik-Filter (Chips, wenn Übung gewählt):**
- e1RM, Volumen, Max Gewicht

**Fortschritts-Diagramm (wenn Übung + Daten vorhanden):**
- Card mit Titel: "{Metrik} — {Übungsname}"
- SimpleLineChart:
  - Y-Achse: 5 Horizontal-Linien mit Labels (auto-scaled)
  - Linie: Pfad-basiert, 3px, primary-Farbe
  - Datenpunkte: Kreise (4dp)
  - X-Achse: Datumslabels (vertikal rotiert -90°, auto-gespaced)
  - Einzelpunkt: einzelner Punkt
- "{n} Trainingspunkte" Text

**Persönliche Rekorde (NEU):**
- Section: "Persönliche Rekorde"
- 3 PrCards:
  - "Max Gewicht" — Wert in kg, Datum
  - "Beste e1RM" — Wert in kg, Datum
  - "Max Volumen" — Wert in kg, Datum
- **v3, geklärt:** Rekorde sind immer **All-Time** (unabhängig vom Zeitraum-Filter) — ein "Rekord", der nach 4 Wochen wieder verschwindet, wäre kein echter Rekord. Nur der Studio-Filter wirkt sich aus.

**Dashboard-Statistik (NEU):**
- Section: "Dashboard"
- 2 Reihen à 3 StatCards:
  - Reihe 1: "Trainings" / "Sätze" / "Pro Woche"
  - Reihe 2: "Volumen" / "Übungen" / "Zeitraum" (Tage)
- **v3, geklärt:** Das Dashboard bezieht sich auf **alle Trainings** (nicht auf eine einzelne ausgewählte Übung) und respektiert sowohl Studio- als auch Zeitraum-Filter — anders als die Persönlichen Rekorde, die absichtlich zeitraum-unabhängig sind.

**Monatliches Volumen (NEU):**
- Section: "Monatliches Volumen"
- Card mit pro-Monat-Zeilen:
  - Monatslabel (80dp breit)
  - LinearProgressIndicator (proportional zum Maximum)
  - Volumen-Text (z.B. "12345 kg")
  - Workout-Anzahl (z.B. "(8)")

### 4.7 Studios Verwalten Screen (NEU, v3)

**Zugang:** Zahnrad-/Settings-Icon oben rechts im HomeScreen (Tab: Training) → öffnet als Stack-Screen "Studios verwalten"

**Header:**
- "Studios verwalten" (headlineMedium)

**Studioliste (LazyColumn):**
Pro Studio:
- Name (bodyLarge, medium)
- Stadt (bodySmall, muted, falls vorhanden)
- System-Badge ("Standard") bei `is_system = 1`
- Bearbeiten-Button (Stift-Icon) — immer verfügbar, auch für System-Studios (Umbenennen erlaubt)
- Löschen-Button (Mülleimer, error) — **deaktiviert/ausgeblendet** bei `is_system = 1`

**"Neues Studio" Button:**
- Full-width Button unten, Add-Icon + Text

**GymEditDialog:**
- Titel: "Studio bearbeiten" / "Neues Studio"
- Felder: Name (Required), Stadt (optional)
- Validierung: Name darf nicht leer sein
- Speichern: legt Studio an / aktualisiert bestehendes

**Löschen-Dialog:**
- Titel: "Studio löschen?"
- Hinweistext: Übungen und Trainings dieses Studios bleiben erhalten, verlieren aber die Studio-Zuordnung (`gym_id` wird NULL)
- Bestätigen: "Löschen" (error) — nur bei `is_system = 0` möglich
- Abbrechen: "Abbrechen"

---

## 5. Berechnungen

### e1RM (Estimiertes 1RM)
**Epley-Formel:**
```
e1RM = weight * (1 + reps / 30.0)
```
- Nur für Sätze mit Gewicht > 0 und Reps > 0
- **Aufwärm-Sätze (`is_warmup = 1`) werden ausgeschlossen.**
- **Muskelversagen-Sätze (`is_failure = 1`) werden NICHT ausgeschlossen** — sie zählen normal in die Berechnung mit ein (v2, geklärt).

### Volumen
```
volume = reps * weight_kg
```
- Aufwärm-Sätze werden ausgeschlossen (`is_warmup = 1`)
- Muskelversagen-Sätze zählen normal mit (`is_failure` hat keinen Einfluss auf die Berechnung)

---

## 6. Kategorien & Kataloge

### Übungskategorien (Deutsch)
`Brust`, `Rücken`, `Beine`, `Schulter`, `Arme`, `Core`, `Ganzkörper`, `Cardio`, `Unterarme`, `Sonstiges`

### Übungsarten
| Key | Label |
|---|---|
| `machine` | Maschine |
| `free_weight` | Freigewicht |
| `cable` | Kabelzug |
| `bodyweight` | Körpergewicht |

### Icons
| Key | Label | Emoji/Idee |
|---|---|---|
| `dumbbell` | Hantel | 🏋️ |
| `leg_press` | Beine | 🦵 |
| `barbell` | Langhantel | — |
| `cable` | Kabelzug | — |
| `bench` | Bank | — |
| `pull_up` | Klimmzug | — |
| `treadmill` | Laufband | — |
| `bike` | Fahrrad | — |

---

## 7. Farbschema (Dark Theme)

| Name | Farbe | Verwendung |
|---|---|---|
| primary | `#BB86FC` | Akzente, aktive Buttons, Satznummern |
| onPrimary | `#000000` | Text auf Primary |
| primaryContainer | `#1A1025` | Icon-Hintergründe |
| secondary | `#03DAC5` | Aktiv-Badges, Warmup-Chips |
| background | `#0C0C0F` | Seitenhintergrund |
| surface | `#141418` | Karten-Hintergrund |
| surfaceVariant | `#1C1C22` | Editor-Container |
| surfaceContainerHigh | `#28282F` | Gym-Cards, BottomBars |
| outline | `#3A3A42` | Trennlinien, Rahmen |
| error | `#FFB4AB` | Löschen-Buttons, Fehler |

---

## 8. Navigation

```
BottomNavigationBar (3 Tabs):
├── Training (Icon: Home)    → HomeScreen
├── Übungen (Icon: List)    → ExerciseListScreen
└── Analyse (Icon: DateRange) → AnalyseScreen

Stack-Navigation (von HomeScreen):
├── HomeScreen
│   ├── Tap Gym → ActiveWorkoutScreen
│   ├── Tap Workout → WorkoutDetailScreen
│   └── Tap Settings-Icon → GymManagementScreen   # NEU (v3)
└── WorkoutDetailScreen
    └── (keine tieferen Navigationen)
```

---

## 9. Ghost-Daten (Auto-Fill) — v2, geklärt

Ghost-Daten sind **strikt pro Studio getrennt** — es gibt keinen Studio-übergreifenden Fallback. Da Übungen studio-gebunden sind (siehe Abschnitt 2), ergibt sich das ohnehin direkt aus der `exercise_id`, aber zur Klarheit hier explizit:

1. Suche den letzten abgeschlossenen Workout-Eintrag **im gleichen Studio**, der diese `exercise_id` enthält.
2. Kein Treffer gefunden (erste Ausführung dieser Übung in diesem Studio) → **keine Ghost-Daten**, Felder bleiben leer (kein Fallback auf andere Studios).
3. Treffer gefunden → kopiere die Sätze dieses Trainings als Vorlage:
   - Erster Satz: Reps, Gewicht, RPE aus dem ersten gespeicherten Satz.
   - Beim Klick auf "Satz": nächster Satz aus der Historie.
   - Über Historie hinaus: letzter bekannter Satz wird wiederholt kopiert.

---

## 10. Besondere Features (gegenüber aktuellem Server-App)

| Feature | Status | Beschreibung |
|---|---|---|
| Template-System | NEU | Vorlagen mit reiner Übungsliste pro Studio (keine Standardwerte, v3 geklärt) |
| Letztes Training kopieren | NEU | "Vorlage aus letztem Training" Button auf HomeScreen — Name wird automatisch als `"Vorlage {dd.MM.} {HH:mm}"` generiert (z.B. "Vorlage 29.08. 14:30"), sodass der Unique-Constraint `(gym_id, name)` in der Praxis nicht kollidiert (v2, geklärt) |
| Studio-Verwaltung | NEU (v3) | Eigener Screen zum Anlegen/Bearbeiten/Löschen von Studios (Abschnitt 4.7) |
| Warmup-Toggle | NEU | Pro Satz: "Aufwärmen" Chip, wird aus Statistiken ausgeschlossen |
| Muskelversagen-Toggle | NEU | Pro Satz: "Zum Versagen" Chip (rein informativ, **beeinflusst Statistiken nicht**, v2 geklärt) |
| Satz-Notiz | NEU | Optionales Textfeld pro Satz |
| Rest-Timer verdrahtet | NEU | Button in unterer Leiste, Countdown-Overlay |
| Kein Login | — | Single-User, direkter Start |
| Komplett offline | — | Kein Internet, keine Server-Abhängigkeit |

---

## 11. Datenformat

### Datumsformatierung
- Anzeige: `dd.MM.yyyy HH:mm` (deutsches Locale)
- Speicherung: ISO 8601 (`2026-08-29T14:30:00`)
- Keine Zeitzonumwandlung nötig (lokal gespeichert)

### Zahlenformat
- Gewicht: `0.0` kg (ein Nachkommastelle)
- Reps: Integer
- RPE: Integer 1–10
- Volumen: Ganzzahl
- e1RM: eine Nachkommastelle

---

## 12. Erster Start & Migration

1. App startet → prüft ob DB existiert
2. Falls nein: Erstelle Tabellen + führe Seed-Daten ein (Übungen pro Studio dupliziert wo nötig, siehe Abschnitt 2/3, 6 Aliase, 2 Studios)
3. Falls ja: Prüfe Versionsnummer und führe Migrationen aus (Drift auto-migration)
4. Zeige Splash-Screen (2 Sek.)
5. Starte direkt auf HomeScreen (kein Login)

---

## 13. Technische Hinweise

### Drift Database
```dart
// Example Entity
class Gyms extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 120)();
  TextColumn get city => text().nullable()();
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
}
```

### UI-Komponenten
- Alle Cards: `RoundedCornerShape(14–16.dp)`
- Alle Buttons: `RoundedCornerShape(12.dp)`
- BottomBars: `surfaceContainerHigh` + `shadowElevation = 8.dp`
- TextFields: `OutlinedTextFieldDefaults.colors(focusedBorderColor: primary, unfocusedBorderColor: outline)`
- Status-Badges: `Surface` mit abgerundeten Ecken + halbtransparenter Farbe

---

## 14. Zusammenfassung aller Screens

| Screen | Tab | Beschreibung |
|---|---|---|
| Splash | — | Logo + Animation (2s) |
| HomeScreen | Training | Willkommen, Studios, Vorlagen, letzte Trainings |
| ActiveWorkoutScreen | (Stack) | Workout mit Übungen + Sätzen, Ghost-Daten, Rest-Timer |
| WorkoutDetailScreen | (Stack) | Training ansehen/bearbeiten/löschen |
| ExerciseListScreen | Übungen | Übungen verwalten (CRUD, Suche, Filter) |
| GymManagementScreen | (Stack, v3) | Studios anlegen/bearbeiten/löschen |
| AnalyseScreen | Analyse | Diagramme, Rekorde, Dashboard, Monatsvolumen |

---

## 15. Nicht enthalten (bewusst weggelassen)

- Kein Server/Netzwerk
- Kein Login/Auth
- Kein Multi-User
- Kein Sync
- Keine Push-Notifications
- Kein Export (CSV/PDF) — kann später ergänzt werden

---

## Änderungsprotokoll v1 → v2

1. **Abschnitt 2 / 3 / 4.5:** Übungen sind studio-gebunden — dieselbe Übung in zwei Studios = zwei getrennte `exercises`-Zeilen. Kein Cross-Studio-Sharing von Übungsdaten.
2. **Abschnitt 4.3 / 9:** Ghost-Daten greifen nur innerhalb desselben Studios; ohne Treffer im aktuellen Studio bleiben Felder leer (kein Fallback auf andere Studios).
3. **Abschnitt 10:** Automatisch generierte Vorlagennamen ("Vorlage aus letztem Training") folgen dem Format `Vorlage {dd.MM.} {HH:mm}`, um Kollisionen mit dem Unique-Constraint `(gym_id, name)` praktisch auszuschließen.
4. **Abschnitt 5 / 10:** Muskelversagen-Sätze (`is_failure`) sind rein informativ und werden **nicht** aus e1RM- oder Volumenberechnung ausgeschlossen (nur `is_warmup` schließt aus).
5. Tippfehler "Requ" → "Reps" korrigiert (Abschnitte 4.3, 9, 11).

## Änderungsprotokoll v2 → v3

1. **Abschnitt 4.3 (Ghost-Daten-Widerspruch behoben):** Die kurze Beschreibung in 4.3 widersprach der genaueren Logik in Abschnitt 9. Jetzt gilt einheitlich: schrittweise durch die Satz-Historie des **letzten Trainings** dieser Übung im selben Studio (1. Klick = 1. Satz, 2. Klick = 2. Satz, ...; danach wird der letzte Satz wiederholt).
2. **Neuer Abschnitt 4.7 "Studios verwalten":** Nutzer können jetzt eigene Studios anlegen, umbenennen und löschen (Zugang über Settings-Icon im HomeScreen). Die beiden Seed-Studios (`is_system = 1`) können umbenannt, aber nicht gelöscht werden.
3. **`workout_template_exercises`:** `default_sets`/`default_reps`/`default_weight_kg` entfernt — Vorlagen speichern nur die Übungsliste, keine Standardwerte. Start aus Vorlage erzeugt leere Übungs-Cards, die normalen Ghost-Daten füllen die Sätze.
4. **Seed-Daten (Abschnitt 3):** Jede Übung hat jetzt eine explizite `category`-Spalte (statt nur der "Push"/"Pull"-Gliederung, die keine echte Kategorie war). Duplikat "Beinpresse" (identisch zum Alias von "Beinpresse horizontal") entfernt.
5. **Analyse-Screen:** Persönliche Rekorde sind explizit All-Time (zeitraum-unabhängig, nur Studio-Filter wirkt); Dashboard-Statistik respektiert sowohl Studio- als auch Zeitraum-Filter.
6. **Neue Konsistenzregel (Abschnitt 2):** Anwendungsschicht muss sicherstellen, dass `exercise_id` in `workout_exercises` und `workout_template_exercises` jeweils zum `gym_id` des übergeordneten Workouts/Templates passt — SQLite kann diese Cross-Table-Bedingung nicht selbst prüfen.
