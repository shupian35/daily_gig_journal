# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

```bash
flutter pub get          # Install dependencies
flutter run              # Run on connected device/emulator
flutter analyze          # Static analysis (uses package:flutter_lints/flutter.yaml)
flutter test             # Run widget tests
flutter build apk --release  # Build Android APK
flutter build ios --release --no-codesign  # Build iOS IPA (macOS only)
```

## Architecture

**Purpose:** A Flutter journal app for daily gig workers. Track work entries per day (title, location, time, hourly wage, hours, daily wage), rich-text notes with images, a drawing canvas, and monthly wage statistics.

**State management:** Riverpod (`flutter_riverpod`). Providers wrap database queries as `FutureProvider`/`FutureProvider.family`. Mutations (save/delete) are `FutureProvider.autoDispose.family` that call the DB and invalidate read providers to refresh UI.

**Database:** SQLite via `sqflite`. Single table `work_notes` with fields for date, title, work_location, start/end time, hourly_wage, work_hours, daily_wage, note_content (Quill Delta JSON string). `DatabaseHelper` is a singleton (`_instance`) — access via `DatabaseHelper()` or the `databaseHelperProvider` Riverpod provider. DB version 3, migrations handled in `_onUpgrade`.

**Navigation flow:**
- `HomeScreen` — 3-tab `BottomNavigationBar` + `IndexedStack`: Calendar / Statistics / Settings
- `CalendarScreen` — Week/month calendar via `table_calendar`, monthly wage summary card, upcoming week plan. Tapping a day or "today" FAB navigates to `DayEntriesScreen`.
- `DayEntriesScreen` — Lists all work entries for a given date. Tapping a card navigates to `NoteEditScreen(noteId: entry.id)`. FAB navigates to `NoteEditScreen(noteId: null)` for new entry.
- `NoteEditScreen` — Form (title, location, time, wage) + Quill rich text editor + image insertion (gallery/camera/drawing canvas). Save/delete via Riverpod mutation providers.
- `DrawingScreen` — Full-screen infinite canvas. `InteractiveViewer` for pan/zoom. Custom `_DrawingPainter` renders dot grid background, imported background image (with opacity/scale), and bezier-smoothed stroke paths. Single-finger draws, two-finger pans. Supports crop mode and export as PNG.

**Settings:** `SharedPreferences` stores theme mode (system/light/dark index), `hide_income` (mask wage amounts), `hide_statistics` (hide stats tab). Loaded in `main.dart` init, changes auto-saved via `ref.listenManual`.

**Theme:** Defined in `AppConstants.lightTheme` / `AppConstants.darkTheme`. Warm orange primary (`#F4A261`), Material 3. Light scaffold `#FAF8F5`, dark scaffold `#1A1A2E`.

## Key Patterns

- **Date format:** Dates stored as `YYYY-MM-DD` strings in SQLite and passed between screens. `Helpers.formatDate(DateTime)` and `Helpers.parseDate(String)` for conversion. `Helpers.toMonthKey()` gives `YYYY-MM` for monthly queries.
- **Provider invalidation cascade:** After save/delete, invalidate `workDatesProvider`, `wageNotesProvider`, `monthlySummaryProvider`, `monthlyTotalWageProvider`, `monthlyWorkDaysProvider`, and the date-specific `notesByDateListProvider`. This refreshes calendar dots, stats, and entry lists.
- **One day can have multiple entries:** `date` field is NOT UNIQUE (migrated in DB v3). `getNotesByDateList(date)` returns all entries for a day, ordered by start time.
- **Note content:** Stored as Quill Delta JSON (`noteContent` field). Serialized via `jsonEncode(quillController.document.toDelta().toJson())`. Empty note defaults to `'[]'`.
- **Image handling:** Images copied to app documents `/images/` directory. Embedded in Quill via `BlockEmbed.image(filePath)`. Custom `_ImageFileEmbedBuilder` renders thumbnails with tap-to-fullscreen gallery.
- **Drawing canvas positions:** Image position in canvas coordinates (not screen). `_toCanvasCoords()` transforms via inverse of `TransformationController` matrix. `InteractiveViewer.onInteractionStart/Update/End` callbacks receive `localFocalPoint` which is already in child (canvas) coordinates.
