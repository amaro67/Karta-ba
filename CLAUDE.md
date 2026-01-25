# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Karta.ba is a full-stack event ticketing platform with three main components:
- **.NET 8 Backend API** - REST API with SQL Server, Stripe payments, RabbitMQ for email queuing
- **Flutter Desktop App** - For event organizers to manage events and tickets
- **Flutter Mobile App** - For users to browse events and purchase tickets

## Build & Run Commands

### Backend (Docker - recommended)
```bash
docker-compose up --build           # Start all services (API, SQL Server, RabbitMQ, Worker)
docker-compose down                 # Stop all services
docker volume rm karta_sqlserver_data  # Reset database (deletes all data)
```

### Backend (Local development)
```bash
dotnet restore Karta.sln
dotnet build Karta.sln
dotnet run --project Karta.WebAPI   # API runs on http://localhost:8080
dotnet run --project Karta.Worker   # Email worker (requires RabbitMQ)
```

### Flutter Apps
```bash
# Desktop app (for organizers)
cd karta_UI/karta_desktop
flutter pub get
flutter run -d macos  # or -d windows, -d linux

# Mobile app (for users)
cd karta_UI/karta_mobile
flutter pub get
flutter run

# Shared library (regenerate models after changes)
cd karta_UI/karta_shared
dart run build_runner build --delete-conflicting-outputs
```

### Tests
```bash
dotnet test Karta.sln                           # Run all tests
dotnet test Karta.Tests                         # Unit tests
dotnet test Karta.IntegrationTests              # Integration tests
dotnet test --filter "FullyQualifiedName~TestName"  # Single test
```

## Architecture

### Backend Layer Structure

```
Karta.Model/         → Entity Framework entities, ApplicationDbContext
Karta.Service/       → Business logic, DTOs, service interfaces
Karta.WebAPI/        → Controllers, middleware, Program.cs configuration
Karta.Worker/        → Background email worker consuming RabbitMQ queue
```

**Key Services:**
- `EventService` - Event CRUD, search, image upload
- `OrderService` - Order processing, payment flow coordination
- `StripeService` - Payment intents, checkout sessions
- `TicketService` - Ticket generation, QR code validation
- `RabbitMQService` - Email queue publishing
- `EmailService` - SMTP email sending (used by Worker)

**Background Services (in WebAPI):**
- `DatabaseInitializationService` - Migrations and seeding on startup
- `RabbitMQInitializationService` - Queue setup
- `OrderCleanupService` - Cancels expired unpaid orders
- `PaymentMonitorService` - Polls Stripe for payment status
- `EventArchiveService` - Archives past events
- `DailyResetService` - Resets daily view counters

### Flutter Layer Structure

```
karta_UI/
├── karta_shared/    → Shared models, providers, services (used by both apps)
├── karta_desktop/   → Organizer app (event management, analytics)
└── karta_mobile/    → User app (event browsing, ticket purchase, QR scanner)
```

**karta_shared contains:**
- `models/` - Data models with json_serializable annotations
- `providers/` - ChangeNotifier state management (auth, events, tickets, favorites)
- `services/` - API communication layer

### Database Entities

Core entities in `Karta.Model/Entities/`:
- `Event` - Event details, links to Venue and Category
- `Venue` - Event locations with capacity
- `Category` - Event categories
- `Ticket` - Individual tickets with QR codes
- `Order` / `OrderItem` - Purchase records
- `PriceTier` - Ticket pricing tiers per event
- `Review` - User reviews for events
- `UserFavorite` - User favorited events

### User Roles

Three user types with different permissions:
- **Admin** - Full system access, can create other admins
- **Organizer** - Creates/manages own events (registers via desktop app)
- **User** - Browses events, purchases tickets (registers via mobile app)

Authorization uses permission-based policies defined in `Program.cs`.

## Key Endpoints

- API: `http://localhost:8080`
- Swagger: `http://localhost:8080/swagger`
- RabbitMQ Management: `http://localhost:15672` (guest/guest)

## Configuration

Environment variables override `appsettings.json`. Key variables:
- `CONNECTION_STRING` - SQL Server connection
- `JWT_SECRET_KEY` - JWT signing key
- `STRIPE_SECRET_KEY` / `STRIPE_PUBLISHABLE_KEY` - Payment processing
- `RabbitMQ__HostName` / `RabbitMQ__UserName` / `RabbitMQ__Password`

## Test Accounts

All use password: `Password123!`
- Admin: `amar.omerovic0607@gmail.com`
- Organizer: `adil+1@edu.fit.ba`
- User: `adil@edu.fit.ba`

## Stripe Test Cards

- Success: `4242 4242 4242 4242`
- Declined: `4000 0000 0000 0002`
