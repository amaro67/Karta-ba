# Karta.WebAPI - Setup i pokretanje

## 📋 Sadržaj
- [Preduslovi](#-preduslovi)
- [Kloniranje projekta](#-kloniranje-projekta)
- [Konfiguracija](#-konfiguracija)
- [Pokretanje baze podataka](#-pokretanje-baze-podataka)
- [Migracije baze](#-migracije-baze)
- [Pokretanje aplikacije](#-pokretanje-aplikacije)
- [Testiranje API-ja](#-testiranje-api-ja)
- [Dodatne informacije](#-dodatne-informacije)
- [Rješavanje problema](#-rješavanje-problema)

---

## 🔧 Preduslovi

Prije pokretanja projekta, potrebno je instalirati sljedeće:

### 1. .NET 8.0 SDK
```bash
# Provjera instalacije
dotnet --version

# Trebalo bi prikazati: 8.0.x ili novije
```
📥 Download: [https://dotnet.microsoft.com/download/dotnet/8.0](https://dotnet.microsoft.com/download/dotnet/8.0)

### 2. SQL Server
Možete koristiti:
- **SQL Server (full)**: [Download](https://www.microsoft.com/en-us/sql-server/sql-server-downloads)
- **SQL Server Express** (besplatna verzija): [Download](https://www.microsoft.com/en-us/sql-server/sql-server-downloads)
- **Docker** (preporučeno za razvoj):
  ```bash
  docker run -e "ACCEPT_EULA=Y" -e "MSSQL_SA_PASSWORD=YourStrongPassword123!" \
    -p 1433:1433 --name sql-server \
    -d mcr.microsoft.com/mssql/server:2022-latest
  ```

### 3. Git
```bash
# Provjera instalacije
git --version
```
📥 Download: [https://git-scm.com/downloads](https://git-scm.com/downloads)

### 4. IDE (opciono, ali preporučeno)
- **Visual Studio 2022** (Community Edition je besplatna)
- **Visual Studio Code** sa C# ekstenzijom
- **JetBrains Rider**

---

## 📦 Kloniranje projekta

```bash
# 1. Klonirajte repozitorijum
git clone [URL_VAŠEG_REPOZITORIJUMA]

# 2. Uđite u direktorijum projekta
cd Karta.ba2/Karta.WebAPI

# 3. Restore NuGet paketa
dotnet restore
```

---

## ⚙️ Konfiguracija

### 1. Kreiranje `appsettings.Development.json` fajla

U root folderu `Karta.WebAPI` projekta, kreirajte novi fajl `appsettings.Development.json` koristeći `appsettings.Development.example.json` kao template:

```bash
# Linux/Mac
cp appsettings.Development.example.json appsettings.Development.json

# Windows (PowerShell)
Copy-Item appsettings.Development.example.json appsettings.Development.json

# Windows (CMD)
copy appsettings.Development.example.json appsettings.Development.json
```

### 2. Konfiguracija baze podataka

Otvorite `appsettings.Development.json` i ažurirajte connection string:

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=localhost,1433;Database=KartaDb;User Id=sa;Password=VašaJakaSifra123!;TrustServerCertificate=true;MultipleActiveResultSets=true;"
  }
}
```

**Važno:**
- Zamijenite `VašaJakaSifra123!` sa stvarnom lozinkom vašeg SQL Server-a
- Ako koristite Windows Authentication, connection string izgleda ovako:
  ```
  Server=localhost;Database=KartaDb;Integrated Security=true;TrustServerCertificate=true;
  ```

### 3. Konfiguracija JWT tokena

```json
{
  "Jwt": {
    "Key": "your_super_secret_jwt_key_here_at_least_32_characters_long_change_this",
    "Issuer": "Karta.ba.Dev",
    "Audience": "Karta.ba.Users.Dev",
    "ExpiryMinutes": 60,
    "RefreshTokenExpiryDays": 7
  }
}
```

**⚠️ SIGURNOSNO UPOZORENJE:**
- Promijenite `Key` na nešto jedinstveno i sigurno (minimum 32 karaktera)
- Nikada ne commitujte stvarne production ključeve u Git!

### 4. Konfiguracija Email servisa (opciono)

Ako želite testirati slanje emailova, konfigurirajte Gmail SMTP:

```json
{
  "Email": {
    "FromEmail": "vas.email@gmail.com",
    "FromName": "Karta.ba Team (Dev)",
    "SmtpHost": "smtp.gmail.com",
    "SmtpPort": 587,
    "SmtpUsername": "vas.email@gmail.com",
    "SmtpPassword": "vaša_gmail_app_lozinka",
    "EnableSsl": true,
    "UseRabbitMQ": false
  }
}
```

**Gmail App Password:**
1. Idite na [Google Account Security](https://myaccount.google.com/security)
2. Omogućite 2-Step Verification
3. Generirajte "App Password" za Mail
4. Koristite generisanu lozinku umjesto vaše obične lozinke

### 5. Konfiguracija Stripe plaćanja (opciono)

```json
{
  "Stripe": {
    "SecretKey": "sk_test_your_test_key_here",
    "PublishableKey": "pk_test_your_test_key_here",
    "WebhookSecret": "whsec_your_webhook_secret_here"
  }
}
```

📘 Više informacija: Pogledajte `STRIPE_SETUP.md` u root folderu projekta

---

## 🗄️ Pokretanje baze podataka

### Opcija 1: Docker (Preporučeno)

```bash
# Pokrenite SQL Server u Docker containeru
docker run -e "ACCEPT_EULA=Y" \
  -e "MSSQL_SA_PASSWORD=YourStrongPassword123!" \
  -p 1433:1433 \
  --name karta-sqlserver \
  -d mcr.microsoft.com/mssql/server:2022-latest

# Provjera da li container radi
docker ps

# Pregled logova (opciono)
docker logs karta-sqlserver
```

### Opcija 2: Lokalna SQL Server instalacija

Ako koristite lokalno instalirani SQL Server, samo provjerite da li servis radi:

**Windows:**
1. Otvorite Services (`Win + R`, unesite `services.msc`)
2. Pronađite "SQL Server (MSSQLSERVER)"
3. Kliknite desni klik → Start (ako nije već pokrenut)

**macOS/Linux:**
SQL Server mora biti instaliran ili koristite Docker opciju iznad.

---

## 🔄 Migracije baze

Nakon što je SQL Server pokrenut i appsettings konfigurisan:

```bash
# 1. Uđite u Karta.WebAPI folder (ako već niste)
cd Karta.WebAPI

# 2. Instalirajte EF Core tools (jednom, globalno)
dotnet tool install --global dotnet-ef

# 3. Ažurirajte bazu podataka (primijeni sve migracije)
dotnet ef database update

# Trebalo bi vidjeti output sličan ovome:
# Build started...
# Build succeeded.
# Applying migration '20251203200826_InitialCreate'.
# Applying migration '20251208175317_AddUserDailyEventView'.
# Done.
```

**Provjera:**
- Poveže se na SQL Server koristeći SQL Server Management Studio (SSMS) ili Azure Data Studio
- Provjerite da li postoji baza `KartaDb` sa tabelama

---

## 🚀 Pokretanje aplikacije

### 1. Pokretanje iz komandne linije

```bash
# Development mod
dotnet run

# Ili sa watch modom (automatski restart pri promjenama)
dotnet watch run
```

Aplikacija će se pokrenuti na:
- **HTTP**: `http://localhost:5000`
- **HTTPS**: `https://localhost:5001`

### 2. Pokretanje iz Visual Studio

1. Otvorite `Karta.WebAPI.sln`
2. Pritisnite `F5` ili kliknite na "Start Debugging"
3. Ili `Ctrl+F5` za "Start Without Debugging"

### 3. Pokretanje iz VS Code

1. Otvorite folder u VS Code
2. Pritisnite `F5`
3. Izaberite ".NET Core" ako se pita

---

## 🧪 Testiranje API-ja

### 1. Swagger UI (Preporučeno)

Nakon pokretanja aplikacije, otvorite browser i idite na:

```
https://localhost:5001/swagger
```

ili

```
http://localhost:5000/swagger
```

Swagger UI omogućava:
- ✅ Pregled svih dostupnih endpointa
- ✅ Testiranje API poziva direktno iz browsera
- ✅ Pregled request/response modela
- ✅ Testiranje autentifikacije

### 2. Testiranje osnovnog endpointa

```bash
# Provjera da li API radi
curl http://localhost:5000/

# Trebalo bi vratiti: "Karta.ba API is running! Visit /swagger for API documentation."
```

### 3. Testiranje autentifikacije

```bash
# Primer: Registracija novog korisnika
curl -X POST "http://localhost:5000/api/auth/register" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "Test123!@#$%",
    "firstName": "Test",
    "lastName": "User"
  }'
```

### 4. Default Admin nalog

Aplikacija automatski kreira admin nalog pri prvom pokretanju:

```
Email: admin@karta.ba
Password: Admin123!@#$%
```

**⚠️ VAŽNO:** Promijenite ovu lozinku odmah nakon prvog logovanja u production okruženju!

---

## 📚 Dodatne informacije

### Ports

| Servis | Port | URL |
|--------|------|-----|
| Karta.WebAPI (HTTP) | 5000 | http://localhost:5000 |
| Karta.WebAPI (HTTPS) | 5001 | https://localhost:5001 |
| Swagger UI | 5000/5001 | https://localhost:5001/swagger |
| SQL Server | 1433 | localhost,1433 |

### Background Services

Aplikacija automatski pokreće sljedeće background servise:

1. **DatabaseInitializationService**: Inicijalizuje bazu i default podatke
2. **OrderCleanupService**: Čisti expired narudžbe (svaki sat)
3. **EventArchiveService**: Arhivira završene evente (svaki sat)
4. **DailyResetService**: Dnevni reset view limita
5. **PaymentMonitorService**: Monitoring Stripe plaćanja

### Logovanje

Logovi se čuvaju u:
```
Karta.WebAPI/logs/karta-dev-YYYYMMDD.log
```

Možete pratiti logove u real-time:
```bash
# Linux/Mac
tail -f logs/karta-dev-*.log

# Windows (PowerShell)
Get-Content logs/karta-dev-*.log -Wait -Tail 50
```

### Environment Variables (opciono)

Umjesto appsettings fajla, možete koristiti environment variables:

```bash
# Primjer za connection string
export CONNECTION_STRING="Server=localhost,1433;Database=KartaDb;User Id=sa;Password=YourPass123!;TrustServerCertificate=true;"

# Pokrenite aplikaciju
dotnet run
```

---

## 🔧 Rješavanje problema

### Problem: "Cannot connect to SQL Server"

**Rješenje:**
1. Provjerite da li SQL Server radi:
   ```bash
   # Docker
   docker ps | grep sql
   
   # Lokalni SQL Server (Windows)
   sc query MSSQLSERVER
   ```

2. Testiranje konekcije:
   ```bash
   # Instalirajte sqlcmd (ako nije instaliran)
   # Docker
   docker exec -it karta-sqlserver /opt/mssql-tools/bin/sqlcmd \
     -S localhost -U sa -P 'YourStrongPassword123!'
   ```

3. Provjerite firewall postavke (port 1433 mora biti otvoren)

### Problem: "A connection was successfully established..."

**Rješenje:**
Dodajte `TrustServerCertificate=true` u connection string:
```json
"Server=localhost,1433;Database=KartaDb;User Id=sa;Password=YourPass;TrustServerCertificate=true;"
```

### Problem: "Build failed" ili missing dependencies

**Rješenje:**
```bash
# Clean i rebuild
dotnet clean
dotnet restore
dotnet build
```

### Problem: "Migration already applied"

**Rješenje:**
```bash
# Resetovanje baze (⚠️ briše sve podatke!)
dotnet ef database drop
dotnet ef database update
```

### Problem: Port već u upotrebi

**Rješenje:**
```bash
# Provjerite šta koristi port 5000/5001
# Linux/Mac
lsof -i :5000

# Windows
netstat -ano | findstr :5000

# Promijenite port u launchSettings.json ili appsettings.json
```

### Problem: SSL Certificate error u browseru

**Rješenje:**
```bash
# Instalirajte development certificate
dotnet dev-certs https --trust
```

---

## 📞 Podrška

Za dodatna pitanja ili probleme:
- 📧 Email: support@karta.ba
- 📖 Dokumentacija: Pogledajte ostale `.md` fajlove u projektu
- 🐛 Bugs: Kreirajte issue na Git repozitorijumu

---

## 🔐 Sigurnost

**NIKADA ne commitujte sljedeće u Git:**
- ❌ `appsettings.Development.json`
- ❌ Stvarne API ključeve (Stripe, Gmail, itd.)
- ❌ Production connection strings
- ❌ JWT secret keys

Fajl `.gitignore` automatski isključuje ove fajlove.

---

## 📝 Changelog

| Verzija | Datum | Izmjene |
|---------|-------|---------|
| 1.0.0 | 2024-12-08 | Inicijalna verzija README-a |

---

**Happy Coding! 🎉**


