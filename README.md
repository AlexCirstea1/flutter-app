# Response (VaultX)

A privacy-focused, secure messaging application built with Flutter. Response provides end-to-end encrypted communication with blockchain audit trails, biometric authentication, and ephemeral messaging capabilities.

---

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Architecture](#architecture)
- [Project Structure](#project-structure)
- [Core Modules](#core-modules)
  - [Configuration](#configuration)
  - [Services](#services)
  - [Database](#database)
  - [Utilities](#utilities)
  - [Theme System](#theme-system)
- [Features Modules](#features-modules)
  - [Authentication](#authentication)
  - [Home](#home)
  - [Chat](#chat)
  - [Profile](#profile)
  - [Activity](#activity)
  - [Blockchain](#blockchain)
  - [Settings](#settings)
- [State Management](#state-management)
- [Navigation & Routing](#navigation--routing)
- [Security Architecture](#security-architecture)
- [Data Flow](#data-flow)
- [Key Business Flows](#key-business-flows)
- [Dependencies](#dependencies)
- [Getting Started](#getting-started)

---

## Overview

**Response** (internally named VaultX) is a Flutter-based secure messaging application designed for privacy-conscious users. The app implements hybrid RSA/AES encryption for messages, WebSocket-based real-time communication via STOMP protocol, and optional blockchain audit trails for user actions.

**Version:** 2.0.0  
**Platforms:** iOS, Android, macOS, Linux, Windows, Web

---

## Features

- **End-to-End Encryption**: Hybrid RSA-2048/AES-256-CBC encryption for all messages
- **Biometric Authentication**: Face ID / Fingerprint support with PIN fallback
- **Real-Time Messaging**: STOMP WebSocket-based instant messaging
- **Ephemeral Messages**: One-time view messages that self-destruct after reading
- **File Sharing**: Encrypted file transfer support (images, documents)
- **Chat Requests**: Request-based contact system with encrypted initial messages
- **Blockchain Audit Trail**: Optional DID-based event logging for regulatory compliance
- **Activity Logging**: Complete user activity history
- **Multi-Theme Support**: Light, Dark, Cyber (neon), and System-following themes
- **Screenshot Prevention**: Platform-level secure mode blocking screen capture
- **Certificate Management**: Self-signed X.509 certificates for key identification

---

## Architecture

The application follows a **feature-first** architecture with **clean architecture principles**:

```
lib/
├── main.dart              # App entry point
├── core/                  # Shared infrastructure
│   ├── config/            # Environment & logging configuration
│   ├── data/              # Core services & database
│   ├── domain/            # Shared domain models
│   ├── theme/             # App theming system
│   ├── utils/             # Helper utilities
│   └── widget/            # Shared widgets
│
└── features/              # Feature modules
    ├── auth/              # Authentication feature
    ├── home/              # Home/chat list feature
    ├── chat/              # Messaging feature
    ├── profile/           # User profile feature
    ├── activity/          # Activity log feature
    ├── blockchain/        # Blockchain events feature
    └── settings/          # App settings feature
```

Each feature follows a layered structure:
- **presentation/** – Pages and widgets (UI layer)
- **data/** – Services, repositories, and API clients
- **domain/** – Models and business entities

---

## Project Structure

```
vaultx_app/
├── lib/
│   ├── main.dart                    # App bootstrap & route definitions
│   ├── core/
│   │   ├── config/
│   │   │   ├── environment.dart     # API/WebSocket URL configuration
│   │   │   └── logger_config.dart   # Centralized logging
│   │   ├── data/
│   │   │   ├── database/
│   │   │   │   └── app_database.dart    # Drift SQLite database
│   │   │   └── services/
│   │   │       ├── api_service.dart         # HTTP client wrapper
│   │   │       ├── storage_service.dart     # Secure storage abstraction
│   │   │       ├── websocket_service.dart   # STOMP WebSocket client
│   │   │       ├── service_locator.dart     # GetIt DI container setup
│   │   │       ├── data_preload_service.dart # App data preloader
│   │   │       └── push_service.dart        # Push notification handling
│   │   ├── domain/models/
│   │   │   ├── certificate_info.dart
│   │   │   ├── distinguished_name.dart
│   │   │   └── public_key_data.dart
│   │   ├── theme/
│   │   │   ├── app_theme.dart       # Theme definitions (light/dark/cyber)
│   │   │   └── theme_provider.dart  # Theme state management
│   │   ├── utils/
│   │   │   ├── crypto_helper.dart       # RSA encryption utilities
│   │   │   ├── key_cert_helper.dart     # Certificate generation
│   │   │   ├── ui_overlay_helper.dart   # Status bar & secure mode
│   │   │   └── datetime_utils.dart      # Date formatting helpers
│   │   └── widget/
│   │       ├── bottom_nav_bar.dart  # Main navigation bar
│   │       ├── pin_screen.dart      # PIN entry screen
│   │       ├── consent_dialog.dart  # Blockchain consent dialog
│   │       └── lifecycle_observer.dart
│   │
│   └── features/
│       ├── auth/
│       │   ├── data/services/
│       │   │   ├── auth_service.dart          # Login/register/PIN APIs
│       │   │   └── biometric_auth_service.dart # Face ID/fingerprint
│       │   ├── domain/models/
│       │   │   ├── user.dart
│       │   │   └── user_profile.dart
│       │   └── presentation/pages/
│       │       ├── splash_screen.dart    # Boot screen with preloading
│       │       ├── login_page.dart       # Login with recent accounts
│       │       └── register_page.dart    # User registration
│       │
│       ├── home/
│       │   └── presentation/pages/
│       │       └── home_page.dart        # Chat list & WebSocket hub
│       │
│       ├── chat/
│       │   ├── data/
│       │   │   ├── repositories/
│       │   │   │   ├── message_repository.dart      # Message CRUD
│       │   │   │   └── chat_request_repository.dart # Request handling
│       │   │   └── services/
│       │   │       ├── chat_service.dart           # Chat façade
│       │   │       ├── message_crypto_service.dart # Message encryption
│       │   │       ├── key_management_service.dart # Public key fetching
│       │   │       ├── file_download_service.dart  # Encrypted file handling
│       │   │       └── file_validation_service.dart
│       │   ├── domain/models/
│       │   │   ├── message_dto.dart
│       │   │   ├── chat_history_dto.dart
│       │   │   ├── chat_request_dto.dart
│       │   │   ├── file_info.dart
│       │   │   └── read_receipt_notification.dart
│       │   └── presentation/
│       │       ├── pages/
│       │       │   ├── chat_page.dart         # Individual chat screen
│       │       │   ├── chat_request_page.dart # Pending requests
│       │       │   └── select_user_page.dart  # User search
│       │       └── widgets/
│       │           ├── chat_app_bar.dart
│       │           ├── chat_background.dart
│       │           ├── chat_input.dart
│       │           ├── chat_message_list.dart
│       │           ├── message_buble.dart
│       │           ├── file_message_widget.dart
│       │           └── ... (other chat widgets)
│       │
│       ├── profile/
│       │   ├── data/services/
│       │   │   └── avatar_service.dart   # User avatar fetching
│       │   └── presentation/pages/
│       │       └── profile_page.dart     # User profile & certificate info
│       │
│       ├── activity/
│       │   └── presentation/pages/
│       │       └── activity_page.dart    # Activity log viewer
│       │
│       ├── blockchain/
│       │   ├── data/
│       │   │   └── blockchain_api.dart   # Blockchain event API client
│       │   ├── domain/models/
│       │   │   └── did_event.dart        # DID event model
│       │   └── presentation/pages/
│       │       ├── events_page.dart      # Event list
│       │       └── event_detail_page.dart
│       │
│       └── settings/
│           └── presentation/pages/
│               ├── settings_page.dart        # Main settings
│               ├── setpin_page.dart          # PIN setup
│               ├── about_page.dart
│               ├── notifications_page.dart
│               └── privacy_policy_page.dart
│
├── assets/
│   ├── icon/         # App icons (PNG, SVG)
│   └── images/       # Backgrounds & logos
│
├── android/          # Android platform code
├── ios/              # iOS platform code
├── macos/            # macOS platform code
├── linux/            # Linux platform code
├── windows/          # Windows platform code
└── web/              # Web platform code
```

---

## Core Modules

### Configuration

**`environment.dart`** – Manages API and WebSocket URLs across environments:
- `LOCAL` – Development with localhost
- `TEST` – Staging server
- `PRODUCTION` – Production server

Automatically handles Android emulator (`10.0.2.2`) and iOS simulator differences.

**`logger_config.dart`** – Centralized logging via the `logger` package.

---

### Services

#### `ApiService`
HTTP client wrapper with:
- Automatic JWT token injection
- 401 handling with automatic logout
- Network error detection and recovery
- Centralized response parsing

#### `StorageService`
Secure storage abstraction using `flutter_secure_storage`:
- JWT token management (`access_token`, `refresh_token`)
- User profile persistence
- Private key storage (versioned per user)
- Certificate storage
- Biometric preference storage
- Recent accounts tracking

Key methods:
```dart
saveAuthData(Map<String, dynamic> authResponse)
getUserProfile() → UserProfile?
savePrivateKey(String version, String privateKey, [String? userId])
getPrivateKey([String? version, String? userId])
isBiometricEnabled() → bool
```

#### `WebSocketService`
STOMP-based real-time messaging singleton:
- Auto-reconnect with 5-second delay
- Multiple subscription channels:
  - `/user/queue/messages` – Incoming messages
  - `/user/queue/sent` – Sent confirmations with server IDs
  - `/user/queue/read-receipts` – Read receipt notifications
  - `/user/queue/chatRequests` – Chat request notifications
  - `/user/queue/files` – File metadata echoes
  - `/user/queue/notifications` – Message deletion events
- Broadcast streams for UI consumption

#### `DataPreloadService`
Optimizes app startup by preloading data in parallel:
- WebSocket connection
- Chat history
- Profile data
- Blockchain events
- Activity log

#### `ServiceLocator` (GetIt)
Dependency injection setup registering all services as singletons or factories:
```dart
serviceLocator<ChatService>()
serviceLocator<AuthService>()
serviceLocator<StorageService>()
// etc.
```

---

### Database

**`AppDatabase`** (Drift/SQLite)

Local message caching with the `CachedMessages` table:
- Message metadata and encrypted content
- Chat partitioning by `chatUserId`
- Read status tracking
- File attachment metadata

Key operations:
```dart
getMessagesForChat(String chatUserId)
cacheMessages(List<CachedMessagesCompanion> messages)
clearChatCache(String chatUserId)
```

---

### Utilities

#### `CryptoHelper`
RSA encryption/decryption using PKCS#1 v1.5:
```dart
rsaEncrypt(String plaintext, String publicKeyPem) → String (base64)
rsaDecrypt(String base64Cipher, String privateKeyPem) → String
```

#### `KeyCertHelper`
X.509 certificate and RSA key pair generation:
```dart
generateRSAKeyPair({int keySize = 2048})
generateSelfSignedCert() → (privateKeyPem, certificatePem, publicKeyPem)
parseCertificate(String pemCertificate) → CertificateInfo
```

#### `UIOverlayHelper`
Platform UI management:
- `enableSecureMode()` – Block screenshots/recordings
- `refreshStatusBarIconsForTheme()` – Theme-aware status bar

---

### Theme System

**`ThemeProvider`** (ChangeNotifier)

Four-state theme selector with persistence:
- `system` – Follow device setting
- `light` – Light theme
- `dark` – Dark theme  
- `cyber` – Neon cyberpunk theme (dark base + cyan/purple accents)

Theme persistence via `SharedPreferences`. Can auto-set theme based on user role (e.g., admin users get cyber theme).

**`AppTheme`**

Centralized theme definitions:
- `lightTheme` – Blue primary, white surfaces
- `darkTheme` – Cyan primary, dark surfaces
- `cyberTheme` – Neon cyan/purple, deep dark surfaces

---

## Features Modules

### Authentication

#### Pages
- **`SplashScreen`** – Boot animation with parallel data preloading, token validation, and route determination
- **`LoginPage`** – Username/password login with recent account quick-select and avatar display
- **`RegisterPage`** – New user registration with optional dummy account creation

#### Services
- **`AuthService`** – Login, register, logout, PIN save/validate, token refresh
- **`BiometricAuthService`** – Face ID/fingerprint authentication via `local_auth`

#### Flow
1. App starts → `SplashScreen` validates tokens
2. Valid token → Check PIN requirement → `PinScreen` or `/home`
3. Invalid/missing → `/login`

---

### Home

**`MyHomePage`** – Central hub of the application:
- Displays chat list sorted by last activity
- Shows unread message counts per chat
- Handles incoming WebSocket events
- Provides access to new chat creation and pending requests

WebSocket message types handled:
- `INCOMING_MESSAGE` / `SENT_MESSAGE` – Update chat list
- `READ_RECEIPT` – Update read status
- `MESSAGE_DELETED` – Remove deleted messages

---

### Chat

The most complex feature with full end-to-end encryption.

#### `ChatService` (Façade)
High-level API coordinating all chat operations:
- `sendMessage()` – Encrypt and send via STOMP
- `fetchChatHistory()` – Load and decrypt message history
- `handleIncomingOrSentMessage()` – Process real-time events
- `sendChatRequest()` / `acceptChatRequest()` / `rejectChatRequest()`

#### `MessageCryptoService`
Hybrid encryption implementation:
```dart
encryptMessage({content, senderKey, recipientKey}) → {
  ciphertext,        // AES-256-CBC encrypted message (base64)
  iv,                // Initialization vector (base64)
  encryptedKeyForSender,    // RSA-encrypted AES key for sender
  encryptedKeyForRecipient, // RSA-encrypted AES key for recipient
  senderKeyVersion,
  recipientKeyVersion
}

decryptMessage({ciphertext, iv, encryptedKey, privateKey}) → plaintext
```

File encryption uses the same hybrid scheme via `encryptData()` / `decryptData()`.

#### `KeyManagementService`
Public key caching and fetching:
```dart
getOrFetchPublicKeyAndVersion(userId) → PublicKeyData?
```
Caches keys in secure storage to avoid repeated API calls.

#### `MessageRepository` / `ChatRequestRepository`
Data layer handling API communication and local state.

#### Key DTOs
- **`MessageDTO`** – Complete message with crypto fields, timestamps, read status
- **`ChatRequestDTO`** – Pending contact request with encrypted message
- **`FileInfo`** – File attachment metadata

#### Widgets
- **`ChatPage`** – Full conversation view with real-time updates
- **`ChatMessageList`** – Scrollable message list with positioned scrolling
- **`MessageBubble`** – Individual message rendering with status indicators
- **`ChatInput`** – Message composer with ephemeral toggle
- **`FileMessageWidget`** – Encrypted file preview/download
- **`ChatRequestGate`** – Blocks messaging until request accepted

---

### Profile

**`ProfilePage`** – User profile display:
- Username, email, avatar
- X.509 certificate details (issuer, validity, serial number)
- PIN and blockchain consent status
- Cache-aware data loading (2-hour cache)

**`AvatarService`** – Fetches and caches user avatars (base64 → PNG bytes).

---

### Activity

**`ActivityPage`** – Paginated activity log with filtering:
- Login events
- Message events
- Security events
- Filterable by activity type

---

### Blockchain

**`EventsPage`** – DID event viewer for users who opted into blockchain audit trails:
- Event type filtering (USER_REGISTERED, KEY_ROTATED, etc.)
- Event detail drill-down
- Event history tracking

**`BlockchainApi`** – API client for:
- `fetchEvents()` – List user's blockchain events
- `fetchEventDetail()` – Single event details
- `fetchEventHistory()` – Event modification history

---

### Settings

**`SettingsPage`** – Comprehensive settings:
- Theme switching (system/light/dark/cyber)
- Biometric toggle (with availability check)
- Key regeneration
- Blockchain consent management
- Account deletion
- Logout

**`SetPinPage`** – PIN creation with confirmation.

---

## State Management

The app uses a **hybrid approach**:

| Component | State Management |
|-----------|-----------------|
| Theme | `Provider` + `ChangeNotifier` (`ThemeProvider`) |
| Authentication | Service-based with `StorageService` |
| Chat Messages | Repository pattern with in-memory lists |
| Real-time Events | Dart `Stream` broadcasts (`WebSocketService`) |
| UI State | `StatefulWidget` + `setState()` |

Services are accessed via **GetIt** service locator pattern.

---

## Navigation & Routing

Named route navigation defined in `main.dart`:

| Route | Page | Description |
|-------|------|-------------|
| `/` | `SplashScreen` | Boot/loading screen |
| `/login` | `LoginPage` | User login |
| `/register` | `RegisterPage` | New user registration |
| `/home` | `MyHomePage` | Chat list (main screen) |
| `/profile` | `ProfilePage` | User profile |
| `/settings` | `SettingsPage` | App settings |
| `/pin` | `PinScreen` | PIN entry |
| `/set-pin` | `SetPinPage` | PIN creation |
| `/about` | `AboutPage` | App information |
| `/activity` | `ActivityPage` | Activity log |
| `/blockchain` | `EventsPage` | Blockchain events |
| `/notifications` | `NotificationsPage` | Notification settings |
| `/privacy-policy` | `PrivacyPolicyPage` | Privacy policy |

**Bottom Navigation Bar** provides access to 5 main sections:
1. Chat (Home)
2. Profile
3. Blockchain
4. Activity
5. Settings

---

## Security Architecture

### Encryption

**Message Encryption (Hybrid RSA/AES):**
1. Generate random 256-bit AES key
2. Generate random 128-bit IV
3. Encrypt message with AES-256-CBC
4. Encrypt AES key with recipient's RSA-2048 public key
5. Encrypt AES key with sender's RSA-2048 public key (for sent copy)
6. Transmit: `{ciphertext, iv, encryptedKeyForSender, encryptedKeyForRecipient, keyVersions}`

**File Encryption:** Same hybrid scheme applied to file bytes.

### Key Management

- RSA-2048 key pairs generated client-side
- Private keys stored in `flutter_secure_storage` (versioned)
- Public keys uploaded to server with version identifiers
- Self-signed X.509 certificates for key identification
- Key rotation support with version tracking

### Authentication

1. **Primary:** Username/password → JWT tokens
2. **Secondary (optional):** PIN verification
3. **Tertiary (optional):** Biometric (Face ID/fingerprint)

Token storage in secure storage; automatic refresh on expiry.

### Platform Security

- Screenshot/screen recording blocked via `FlutterWindowManager`
- Secure storage backed by Keychain (iOS) / Keystore (Android)
- No plaintext storage of sensitive data

---

## Data Flow

### Sending a Message

```
User Input → ChatPage._sendMessage()
    ↓
ChatService.sendMessage()
    ↓
KeyManagementService.getOrFetchPublicKeyAndVersion() [sender + recipient]
    ↓
MessageCryptoService.encryptMessage()
    ↓
WebSocketService.sendMessage('/app/sendPrivateMessage', payload)
    ↓
Server broadcasts to /user/queue/sent (sender) + /user/queue/messages (recipient)
    ↓
WebSocketService._handleIncomingFrame() → StreamController
    ↓
ChatPage._messageSubscription → ChatService.handleIncomingOrSentMessage()
    ↓
MessageRepository._upsert() → setState()
```

### Receiving a Message

```
Server → WebSocket /user/queue/messages
    ↓
WebSocketService._handleIncomingFrame()
    ↓
_messageController.add(data) → Stream broadcast
    ↓
HomePage/ChatPage subscription
    ↓
ChatService.handleIncomingOrSentMessage()
    ↓
StorageService.getPrivateKey(recipientKeyVersion)
    ↓
MessageCryptoService.decryptMessage()
    ↓
Repository.messages.add() + setState()
```

---

## Key Business Flows

### App Startup Flow

```
main() → setupServiceLocator() → UIOverlayHelper.enableSecureMode()
    ↓
SplashScreen._checkLoginStatus()
    ↓
├─ No tokens → /login
├─ Valid token + hasPin → PinScreen
└─ Valid token + no PIN → /home

Parallel: DataPreloadService.preloadAppData()
```

### Chat Request Flow

```
UserA searches UserB → SelectUserPage
    ↓
UserA sends request → ChatRequestRepository.sendChatRequest()
    ↓
Server notifies UserB → /user/queue/chatRequests
    ↓
UserB views requests → ChatRequestPage.fetchPendingChatRequests()
    ↓
UserB accepts → ChatRequestRepository.acceptChatRequest()
    ↓
Chat unlocked → Both users can exchange messages
```

### Key Regeneration Flow

```
SettingsPage._regenerateKeys()
    ↓
KeyCertHelper.generateSelfSignedCert() → (private, cert, public)
    ↓
POST /user/publicKey with public key → Server returns version
    ↓
StorageService.savePrivateKey(version, private)
    ↓
StorageService.saveCertificate(version, cert)
```

---

## Dependencies

### Core

| Package | Purpose |
|---------|---------|
| `provider` | State management for themes |
| `get_it` | Dependency injection container |
| `http` | HTTP client |
| `stomp_dart_client` | WebSocket STOMP protocol |
| `web_socket_channel` | WebSocket transport |

### Storage & Database

| Package | Purpose |
|---------|---------|
| `flutter_secure_storage` | Encrypted key-value storage |
| `shared_preferences` | Non-sensitive preferences |
| `drift` | SQLite ORM for message caching |
| `sqlite3_flutter_libs` | SQLite native libraries |
| `path_provider` | File system paths |

### Security & Cryptography

| Package | Purpose |
|---------|---------|
| `encrypt` | AES/RSA encryption |
| `pointycastle` | Crypto primitives |
| `basic_utils` | Certificate utilities |
| `x509` | X.509 certificate parsing |
| `local_auth` | Biometric authentication |
| `flutter_windowmanager` | Screenshot prevention |

### UI & UX

| Package | Purpose |
|---------|---------|
| `flutter_svg` | SVG asset rendering |
| `scrollable_positioned_list` | Chat message scrolling |
| `flutter_speed_dial` | FAB menu |
| `intl` | Date/time formatting |
| `icons_flutter` | Extended icon sets |

### File Handling

| Package | Purpose |
|---------|---------|
| `file_picker` | File selection |
| `image_picker` | Camera/gallery access |
| `open_filex` | Open files with native apps |

### Utilities

| Package | Purpose |
|---------|---------|
| `uuid` | Unique ID generation |
| `rxdart` | Reactive extensions |
| `logger` | Structured logging |
| `json_annotation` / `json_serializable` | JSON serialization |

---

## Getting Started

### Prerequisites

- Flutter SDK 3.5.3+
- Dart SDK 3.5.3+
- Xcode (for iOS/macOS)
- Android Studio (for Android)

### Installation

```bash
# Clone the repository
git clone <repository-url>
cd vaultx_app

# Install dependencies
flutter pub get

# Generate code (Drift database, JSON serialization)
flutter pub run build_runner build --delete-conflicting-outputs

# Run on device/emulator
flutter run
```

### Environment Configuration

Edit `lib/core/config/environment.dart` to set the app flavor:

```dart
static Flavor appFlavor = Flavor.PRODUCTION; // or LOCAL, TEST
```

### Running Tests

```bash
flutter test
```

### Building for Release

```bash
# Android
flutter build apk --release

# iOS
flutter build ios --release

# macOS
flutter build macos --release
```

---

## License

This is a private application. All rights reserved.

