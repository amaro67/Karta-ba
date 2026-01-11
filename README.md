# Karta.ba

Event ticketing platform with desktop management and mobile app for attendees and scanners.

## What's in the box

This is a full-stack event ticketing system with three main parts:
- **Backend API** - .NET 8 API with SQL Server, Stripe payments, and email notifications
- **Desktop App** - Flutter app for organizers to manage events and tickets
- **Mobile App** - Flutter app for users to buy tickets and scanners to validate them

## Getting Started

### Prerequisites

You'll need these installed:
- Docker and Docker Compose (for running the backend)
- .NET 8 SDK (if you want to run the API locally without Docker)
- Flutter SDK (for the mobile/desktop apps)
- An IDE (VS Code, Rider, or Visual Studio)

### Quick Start - Backend

# Start all services (database, API, RabbitMQ)
docker-compose up --build

The API should now be running at `http://localhost:8080/swagger/index.html`

### Running the Desktop App

```bash
cd karta_UI/karta_desktop

# Get dependencies
flutter pub get

# Run it
flutter run
```

When it asks which device to use, pick your OS (macOS, Windows, or Linux).

### Running the Mobile App

```bash
cd karta_UI/karta_mobile

# Get dependencies
flutter pub get

# Run on an emulator or connected device
flutter run
```

You'll need either an Android emulator, iOS simulator, or a physical device connected.

## Understanding Account Types

There are four different account types, each with different access:

### 1. Admin (Super User)
- Can do literally everything
- Only admins can create other admin accounts
- Used for platform management

**Test Admin Login:**
- Email: `amar.omerovic0607@gmail.com`
- Password: `Password123!`

### 2. Organizer
- Created when someone registers through the **desktop app**
- Can create and manage their own events
- Can create scanner accounts for their events
- Can view sales and analytics

### 3. User (Regular Customer)
- Created when someone registers on the **mobile app**
- Can browse events and buy tickets
- Can view their purchased tickets
- Can use QR codes for event entry

### 4. Scanner
- Created by organizers (not through registration)
- Can only scan tickets at events they're assigned to
- Uses mobile app in scanner mode
- Cannot buy tickets or create events

## Account Creation Flow

Here's how to create each type of account:

**Admin accounts:**
- Only existing admins can create new admins
- There's no self-registration for admin

**Organizer accounts:**
- Open the desktop app
- Click "Register"
- Fill out your info
- You'll automatically get organizer permissions

**User accounts:**
- Open the mobile app
- Tap "Register" 
- Fill out your info
- You can now browse and buy tickets

**Scanner accounts:**
- Organizers create these from the desktop app
- Go to an event and assign scanners
- Scanners get login credentials to use on mobile

## Database Migrations

If you need to reset the database or run migrations manually:

```bash
# Stop containers
docker-compose down

# Remove the database volume (WARNING: deletes all data)
docker volume rm karta_sqlserver_data

# Start fresh
docker-compose up --build
```

The migrations run automatically when the API starts up.

## Project Structure

```
.
├── Karta.WebAPI/          # Backend API
├── Karta.Service/         # Business logic layer
├── Karta.Model/           # Database models
├── karta_UI/
│   ├── karta_desktop/     # Desktop app (organizers)
│   ├── karta_mobile/      # Mobile app (users/scanners)
│   └── karta_shared/      # Shared code between apps
├── scripts/               # Database and setup scripts
└── docker-compose.yml     # Docker configuration
```


### Important API URLs

- API: `http://localhost:8080`
- RabbitMQ Management: `http://localhost:15672` (guest/guest)
- Swagger Docs: `http://localhost:8080/swagger`

## Common Issues

**Docker containers won't start:**
- Make sure nothing else is using ports 1433, 5672, 8080, or 15672
- Try `docker-compose down` then `docker-compose up --build`

**Can't login:**
- Use the admin credentials above for first login
- Make sure the database initialized properly (check logs)
- Try creating a new user through registrationß


**Connect to the database:**
- Host: `localhost`
- Port: `1433`
- User: `sa`
- Password: Check your `.env` file (`KartaPassword2024!`)
- Database: `KartaDb`

## Testing Payments

Use Stripe's test card numbers:
- Success: `4242 4242 4242 4242`
- Decline: `4000 0000 0000 0002`
- Any future expiry date and CVC


