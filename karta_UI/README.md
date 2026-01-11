# Karta UI Projects

This folder contains all Flutter-based user interface applications for the Karta.ba ticketing platform.

## Project Structure

```
karta_UI/
├── karta_shared/         # Shared package with common models, services, and providers
├── karta_desktop/        # Desktop application for organizers and admins
└── karta_mobile/         # Mobile application for users and scanners
```

## karta_shared

A Flutter package containing shared code used by both desktop and mobile applications:

- **Models**: DTOs for auth, events, orders, tickets, and scanners
- **Services**: API client with configurable client type
- **Providers**: State management providers (auth, event, ticket)
- **Utils**: Common utilities and validators

### Usage

Both desktop and mobile apps reference this package via path:

```yaml
dependencies:
  karta_shared:
    path: ../karta_shared
```

### Client Type Configuration

The API service can be configured for different client types:

```dart
ApiClient.clientType = 'karta_desktop';  // For desktop app
ApiClient.clientType = 'karta_mobile';   // For mobile app
```

This ensures proper role assignment during user registration on the backend.

## karta_desktop

Desktop application built with Flutter for Windows, macOS, and Linux.

**Target Users:**
- Admins (full system management)
- Organizers (event creation and management)

**Key Features:**
- User management
- Event management with price tiers
- Order and ticket management
- Scanner assignment
- Sales analytics
- Role-based access control

**Platforms:** Windows, macOS, Linux

## karta_mobile

Mobile application built with Flutter for Android.

**Target Users:**
- Users (event browsing and ticket purchasing)
- Scanners (ticket validation at events)

**Key Features:**

### User Role:
- Browse events by category/city
- View event details
- Purchase tickets via Stripe Checkout
- View tickets with QR codes

### Scanner Role:
- View assigned events
- Scan ticket QR codes
- Validate tickets
- Manual ticket entry
- Mark tickets as used

**Platforms:** Android (iOS support planned)

## Development Setup

### Prerequisites
- Flutter SDK (^3.9.2)
- Dart SDK (included with Flutter)
- Running Karta.WebAPI backend

### Installation

1. Navigate to the karta_UI folder:
```bash
cd karta_UI
```

2. Install shared package dependencies:
```bash
cd karta_shared
flutter pub get
dart run build_runner build
cd ..
```

3. Install desktop app dependencies (if using):
```bash
cd karta_desktop
flutter pub get
cd ..
```

4. Install mobile app dependencies:
```bash
cd karta_mobile
flutter pub get
```

### Configuration

Update the API endpoint in `karta_shared/lib/services/api_service.dart`:

```dart
static const String baseUrl = 'http://your-api-url:port';
```

### Running the Apps

**Desktop:**
```bash
cd karta_desktop
flutter run -d windows  # or macos, linux
```

**Mobile:**
```bash
cd karta_mobile
flutter run -d android
```

## Shared Architecture

### State Management
Both apps use Provider for state management with these key providers:
- `AuthProvider`: Authentication and user session
- `EventProvider`: Event browsing and management
- `TicketProvider`: Ticket management

### API Communication
- Centralized API client in `karta_shared`
- JWT token authentication
- Automatic token refresh
- Configurable client type headers

### Models
All DTOs are shared between apps and use `json_serializable` for serialization:
- Auth models (login, register, user info)
- Event models (event, price tier, paged results)
- Order models (order, order item, ticket)
- Scanner models

## Building for Production

### Desktop (Windows)
```bash
cd karta_desktop
flutter build windows --release
```

### Mobile (Android)
```bash
cd karta_mobile
flutter build apk --release
# Or for split APKs per ABI:
flutter build apk --split-per-abi --release
```

## Project Dependencies

### Shared (karta_shared)
- `http`: API communication
- `jwt_decoder`: JWT token handling
- `flutter_secure_storage`: Secure token storage
- `shared_preferences`: Settings storage
- `provider`: State management
- `intl`: Date formatting
- `json_annotation`: JSON serialization

### Desktop Only
- `go_router`: Navigation
- `flutter_stripe`: Payment processing (planned)
- `qr_flutter`: QR code generation

### Mobile Only
- `qr_code_scanner`: QR code scanning
- `qr_flutter`: QR code display
- `webview_flutter`: Stripe checkout integration
- `url_launcher`: Open external links

## Authentication Flow

1. User opens app
2. `AuthProvider.initialize()` checks for saved tokens
3. If valid token exists:
   - Decode user info from JWT
   - Check user roles
   - Route to appropriate screen
4. If no valid token:
   - Show login screen

### Role-Based Routing

**Desktop:**
- Admin → Admin Dashboard
- Organizer → Organizer Dashboard
- Others → Access denied

**Mobile:**
- Scanner → Scanner Dashboard
- User/Other → Home Screen

## API Integration

All API calls go through `ApiClient` in `karta_shared`:

```dart
// GET request
final events = await ApiClient.getList('/Event', token: token);

// POST request
final response = await ApiClient.post('/Order', data, token: token);

// With client type header
final response = await ApiClient.register(request);
// Automatically sends X-Client-Type header
```

## Code Generation

After modifying models in `karta_shared`, regenerate code:

```bash
cd karta_shared
dart run build_runner build --delete-conflicting-outputs
```

## Testing

Run tests for each app:

```bash
# Shared package
cd karta_shared
flutter test

# Desktop
cd karta_desktop
flutter test

# Mobile
cd karta_mobile
flutter test
```

## Troubleshooting

### karta_shared changes not reflected
After updating karta_shared, run `flutter pub get` in dependent apps:
```bash
cd karta_desktop && flutter pub get
cd karta_mobile && flutter pub get
```

### API connection issues
- Verify backend is running
- Check API URL in `api_service.dart`
- Ensure device/emulator can reach backend
- Check firewall settings

### Build errors
```bash
# Clean and rebuild
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

## Contributing

When adding new features:

1. **If shared code**: Add to `karta_shared`
2. **If desktop-specific**: Add to `karta_desktop`
3. **If mobile-specific**: Add to `karta_mobile`

Update models in `karta_shared` and regenerate code when changing API contracts.

## License

Proprietary - Karta.ba
