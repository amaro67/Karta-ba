# Karta Mobile

Karta Mobile is a Flutter application for event ticketing, designed for end users to browse and purchase tickets, and for scanners to validate tickets at events.

## Features

### User Role
- **Event Discovery**: Browse events by category, city, and date
- **Event Details**: View detailed event information with images and descriptions
- **Ticket Purchase**: Buy tickets through Stripe Checkout (WebView)
- **My Tickets**: View all purchased tickets with QR codes
- **Ticket Detail**: Display ticket QR code for scanning at events

### Scanner Role
- **Scanner Dashboard**: View all assigned events
- **QR Scanner**: Scan tickets using device camera
- **Manual Entry**: Enter ticket codes manually
- **Ticket Validation**: Validate and mark tickets as used

## Architecture

The app uses a shared package (`karta_shared`) for common code between mobile and desktop applications:

```
karta_UI/
├── karta_shared/         # Shared models, services, and providers
├── karta_desktop/        # Desktop application (existing)
└── karta_mobile/         # Mobile application (this project)
```

## Getting Started

### Prerequisites
- Flutter SDK (^3.9.2)
- Android Studio / Xcode
- Running Karta.WebAPI backend

### Installation

1. Navigate to the project directory:
```bash
cd karta_UI/karta_mobile
```

2. Install dependencies:
```bash
flutter pub get
```

3. Configure API endpoint in `karta_shared/lib/services/api_service.dart`:
```dart
static const String baseUrl = 'YOUR_API_URL';
```

4. Run the app:
```bash
flutter run
```

## Configuration

### API Client Type
The app automatically sets the client type to `karta_mobile` in `main.dart`:
```dart
ApiClient.clientType = 'karta_mobile';
```

This ensures that new user registrations are automatically assigned the "User" role on the backend.

### Android Permissions

The following permissions are required for QR scanning:
- Camera access (configured automatically by `qr_code_scanner` package)

## Project Structure

```
lib/
├── config/
│   ├── theme.dart          # App theme and colors
│   └── routes.dart         # Route definitions
├── screens/
│   ├── auth/              # Login and registration
│   ├── user/              # User role screens
│   └── scanner/           # Scanner role screens
├── widgets/               # Reusable widgets
└── main.dart             # App entry point
```

## Dependencies

### Core
- `karta_shared`: Shared package with models, services, and providers
- `provider`: State management
- `http`: API communication

### Features
- `qr_code_scanner`: QR code scanning
- `qr_flutter`: QR code generation/display
- `webview_flutter`: Stripe checkout integration
- `intl`: Date formatting

## State Management

The app uses Provider for state management with the following providers:
- `AuthProvider`: Authentication and user session
- `EventProvider`: Event browsing and filtering
- `TicketProvider`: Ticket management

All providers are shared from `karta_shared` package.

## Authentication Flow

1. User opens app → SplashScreen
2. Check if user is authenticated
3. If authenticated:
   - User role → HomeScreen
   - Scanner role → ScannerHomeScreen
4. If not authenticated → LoginScreen

## Payment Flow

1. User selects event and ticket tier
2. Taps "Check out"
3. WebView opens with Stripe Checkout URL
4. User completes payment in Stripe
5. On success → Redirects to My Tickets
6. On cancel → Returns to event detail

## Scanner Flow

1. Scanner logs in
2. Views list of assigned events
3. Selects event to scan
4. Scans QR code or enters code manually
5. Validates ticket against backend
6. Marks valid tickets as used

## Build for Release

### Android
```bash
flutter build apk --release
```

### Generate signed APK
```bash
flutter build apk --split-per-abi --release
```

## Troubleshooting

### Camera not working
- Ensure camera permissions are granted
- Check AndroidManifest.xml has camera permissions
- Restart app after granting permissions

### API connection issues
- Verify backend is running
- Check API URL in api_service.dart
- Ensure device/emulator can reach the backend URL

### WebView not loading
- Check internet connection
- Verify Stripe is configured correctly in backend
- Check console for JavaScript errors

## Known Limitations

- Currently Android only
- Offline mode not implemented (future enhancement)
- Ticket cancellation UI present but not fully implemented
- Event images need to be loaded from actual CDN/backend

## Future Enhancements

- iOS support
- Offline scanning for scanners
- Push notifications
- In-app native Stripe payment
- Digital wallet integration (Google Pay)
- Multi-language support

## Contributing

This is part of the Karta.ba monorepo. See main project README for contribution guidelines.

## License

Proprietary - Karta.ba
