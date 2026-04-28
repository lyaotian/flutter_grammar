# Japanese Grammar Dictionary

A modern, offline-first Japanese Grammar Dictionary application built with Flutter. It provides a comprehensive database of JLPT grammar points, complete with detailed explanations, example sentences, and search functionality.

## Features

- **Offline Database**: Powered by SQLite (`sqflite`), the app bundles a pre-populated grammar database allowing fully offline use without network requests.
- **Search & Filter**: Search for specific grammar points (e.g., てある) and filter results by JLPT level (N1-N5).
- **Favorites System**: Save and easily access your most important or difficult grammar points in a dedicated Favorites tab.
- **Detailed Grammar Breakdown**: View detailed information parsed from structured knowledge data, including:
  - Meaning and detailed explanations
  - JLPT level indicators
  - Highlighted example sentences
  - Usage caveats and discriminations
- **Theme Support**: Includes full support for Light and Dark mode, with dynamic customizable color themes.
- **Tabbed Interface**: Easy navigation between Search, Favorites, and Settings.

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (version ^3.11.5 or newer)
- Dart SDK

### Installation

1. Open the project directory.
2. Get the required dependencies:
   ```bash
   flutter pub get
   ```
3. Run the application:
   ```bash
   flutter run
   ```

## Architecture & Libraries

- **Database**: The app relies on `sqflite` and `path_provider` to securely copy and load the bundled `assets/grammar.sqlite3` database to the device's local storage for efficient querying.
- **State Management**: Uses native Flutter state management (`StatefulWidget`, `ValueNotifier`) for tab navigation, favorites toggling, and theme configuration.
- **UI/UX**: Utilizes Material 3 design principles for a modern, responsive look across devices.

## Project Structure

- `lib/main.dart`: Contains the main application entry point, theming logic, tab navigation, and all primary UI components (Search Tab, Favorites Tab, Settings Tab, and Grammar Detail View).
- `lib/database_helper.dart`: Singleton service class responsible for initializing the SQLite database and handling all database queries (searching grammar, retrieving favorites, toggling favorite status).
- `assets/grammar.sqlite3`: The bundled SQLite database file containing the structured Japanese grammar data.
