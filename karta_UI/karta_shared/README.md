# Karta Shared

Shared Flutter package containing models, services, and providers used by both `karta_desktop` and `karta_mobile` applications.

## Purpose

This package centralizes common code to:
- Avoid code duplication
- Ensure consistency across apps
- Simplify maintenance
- Share API contracts

## Structure

```
karta_shared/
├── lib/
│   ├── karta_shared.dart          # Main export file
│   ├── models/
│   │   ├── auth/                  # Authentication DTOs
│   │   ├── event/                 # Event DTOs
│   │   ├── order/                 # Order and ticket DTOs
│   │   └── scanner/               # Scanner DTOs
│   ├── services/
│   │   └── api_service.dart       # API client
│   ├── providers/
│   │   ├── auth_provider.dart     # Auth state management
│   │   ├── event_provider.dart    # Event state management
│   │   └── ticket_provider.dart   # Ticket state management
│   └── utils/
│       ├── constants.dart
│       └── validators.dart
└── pubspec.yaml
```

## Usage

### Adding to Your Project

Add to `pubspec.yaml`:

```yaml
dependencies:
  karta_shared:
    path: ../karta_shared
```

### Importing

Import the main package:

```dart
import 'package:karta_shared/karta_shared.dart';
```

This exports all models, services, and providers.

## API Service

### Configuration

Set the client type before making API calls:

```dart
// In desktop app
ApiClient.clientType = 'karta_desktop';

// In mobile app
ApiClient.clientType = 'karta_mobile';
```

### Usage Examples

```dart
// Authentication
final authResponse = await ApiClient.login(loginRequest);

// GET request
final events = await ApiClient.getList('/Event', token: token);

// POST request
final order = await ApiClient.post('/Order', orderData, token: token);

// PUT request
final updated = await ApiClient.put('/Event/$id', data, token: token);

// DELETE request
await ApiClient.delete('/Event/$id', token: token);
```

## Providers

### AuthProvider

Handles authentication and user session:

```dart
final authProvider = context.read<AuthProvider>();

// Login
await authProvider.login(email, password);

// Register
await authProvider.register(email, password, firstName, lastName);

// Logout
await authProvider.logout();

// Check authentication
if (authProvider.isAuthenticated) {
  // User is logged in
}

// Get current user
final user = authProvider.currentUser;

// Check roles
if (authProvider.hasRole('Admin')) {
  // User is admin
}
```

### EventProvider

Manages event browsing and filtering:

```dart
final eventProvider = context.read<EventProvider>();

// Load events with filters
await eventProvider.loadEvents(
  query: 'concert',
  category: 'Music',
  city: 'Sarajevo',
);

// Access events
final events = eventProvider.events?.items ?? [];

// Check loading state
if (eventProvider.isLoading) {
  // Show loading indicator
}
```

### TicketProvider

Manages user tickets:

```dart
final ticketProvider = context.read<TicketProvider>();

// Load user's tickets
await ticketProvider.getMyTickets();

// Access tickets
final tickets = ticketProvider.myTickets ?? [];
```

## Models

All models use `json_serializable` for JSON serialization.

### Auth Models

- `AuthResponse`: Login/register response with tokens
- `LoginRequest`: Login credentials
- `RegisterRequest`: Registration data
- `RefreshTokenRequest`: Token refresh
- `UserInfo`: User information

### Event Models

- `EventDto`: Event information
- `PriceTierDto`: Ticket pricing
- `PagedResult<T>`: Paginated results

### Order Models

- `OrderDto`: Order information
- `OrderItemDto`: Order line items
- `TicketDto`: Ticket details

## Code Generation

After modifying models, regenerate serialization code:

```bash
cd karta_shared
dart run build_runner build --delete-conflicting-outputs
```

## Development

### Adding New Models

1. Create model file in appropriate folder
2. Add JSON annotations:
```dart
import 'package:json_annotation/json_annotation.dart';

part 'my_model.g.dart';

@JsonSerializable()
class MyModel {
  final String id;
  final String name;

  MyModel({required this.id, required this.name});

  factory MyModel.fromJson(Map<String, dynamic> json) =>
      _$MyModelFromJson(json);

  Map<String, dynamic> toJson() => _$MyModelToJson(this);
}
```

3. Run code generation
4. Export from `karta_shared.dart`:
```dart
export 'models/path/my_model.dart';
```

### Adding New API Endpoints

Add methods to `ApiClient` in `api_service.dart`:

```dart
static Future<MyDto> getMyData(String token) async {
  final response = await get('/MyEndpoint', token: token);
  return MyDto.fromJson(response);
}
```

## Dependencies

- `http`: HTTP client
- `jwt_decoder`: JWT token handling
- `flutter_secure_storage`: Secure storage
- `shared_preferences`: Settings storage
- `provider`: State management
- `intl`: Internationalization
- `json_annotation`: JSON serialization
- `json_serializable`: Code generation (dev)
- `build_runner`: Code generation (dev)

## Testing

Run tests:

```bash
flutter test
```

## License

Proprietary - Karta.ba
