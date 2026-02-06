# Karta.ba

Platforma za prodaju ulaznica za događaje sa desktop aplikacijom za organizatore i mobilnom aplikacijom za korisnike.

---

## O projektu

**Karta.ba** je full-stack sistem za prodaju karata koji se sastoji od tri glavna dijela:

| Komponenta | Opis |
|------------|------|
| **Backend API** | .NET 8 Web API sa SQL Server bazom, Stripe integracija za plaćanja i email notifikacije |
| **Desktop aplikacija** | Flutter aplikacija namijenjena organizatorima za upravljanje događajima i kartama |
| **Mobilna aplikacija** | Flutter aplikacija za krajnje korisnike za pregledanje događaja i kupovinu karata |

---

## Preduslovi

Prije pokretanja projekta, potrebno je instalirati:

- [Docker](https://www.docker.com/) i Docker Compose
- [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0)
- [Flutter SDK](https://flutter.dev/docs/get-started/install)
- IDE po izboru (VS Code ili Visual Studio)

---

## Pokretanje projekta

### Backend (API + Baza + RabbitMQ)

```bash
# Pokretanje svih servisa
docker-compose up --build
```

Nakon uspješnog pokretanja, API je dostupan na:
- **Swagger dokumentacija:** http://localhost:8080/swagger/index.html
- **API endpoint:** http://localhost:8080
- **RabbitMQ Management:** http://localhost:15672 (korisnik: `guest`, lozinka: `guest`)

---

## Tipovi korisničkih naloga

Sistem podržava tri tipa korisnika sa različitim pravima pristupa.

> **Lozinka za sve test naloge:** `Password123!`

### 1. Admin (Super korisnik)

- Potpuni pristup svim funkcionalnostima sistema
- Jedini može kreirati druge admin naloge
- Koristi se za administraciju platforme

| Email | Lozinka |
|-------|---------|
| `amar.omerovic0607@gmail.com` | `Password123!` |
| `adil+2@edu.fit.ba` | `Password123!` |

---

### 2. Organizator

- Registracija putem **desktop aplikacije**
- Kreira i upravlja vlastitim događajima
- Pristup prodajnim izvještajima i analitici

| Email | Lozinka |
|-------|---------|
| `adil+1@edu.fit.ba` | `Password123!` |

---

### 3. Korisnik (User)

- Registracija putem **mobilne aplikacije**
- Pregledanje događaja i kupovina karata
- Dodavanje događaja u favorite (omiljeni)
- Pristup kupljenim kartama
- Ulazak na događaje putem QR koda

| Email | Lozinka |
|-------|---------|
| `adil@edu.fit.ba` | `Password123!` |

---

## Tok kreiranja naloga

| Tip naloga | Način kreiranja |
|------------|-----------------|
| **Admin** | Samo postojeći admin može kreirati novog admina. Nema samostalne registracije. |
| **Organizator** | Registracija putem desktop aplikacije. Prava se automatski dodjeljuju. |
| **Korisnik** | Registracija putem mobilne aplikacije. |

---

## Baza podataka

### Povezivanje na bazu

| Parametar | Vrijednost |
|-----------|------------|
| Host | `localhost` |
| Port | `1433` |
| User | `sa` |
| Password | `KartaPassword2024!` |
| Database | `IB210242` |

### Resetovanje baze

```bash
# Zaustavi kontejnere
docker-compose down

# Obriši volume baze (UPOZORENJE: briše sve podatke!)
docker volume rm karta_sqlserver_data

# Ponovo pokreni sve
docker-compose up --build
```

> **Napomena:** Migracije se automatski izvršavaju prilikom pokretanja API-ja.

---

## Testiranje plaćanja

Koristi Stripe test kartice za simulaciju plaćanja:

| Scenarij | Broj kartice |
|----------|--------------|
| Uspješno plaćanje | `4242 4242 4242 4242` |
| Odbijena kartica | `4000 0000 0000 0002` |

> Za datum isteka koristi bilo koji budući datum, a za CVC bilo koje 3 cifre.

---

## Česti problemi

### Docker se ne pokreće

1. Provjeri da portovi `1433`, `5672`, `8080` i `15672` nisu zauzeti
2. Pokušaj ponovo pokrenuti:

```bash
docker-compose down
docker-compose up --build
```

### Neuspješna prijava

1. Koristi test podatke navedene u sekciji [Tipovi korisničkih naloga](#tipovi-korisničkih-naloga)
2. Provjeri Docker logove da li se baza pravilno inicijalizovala
3. Pokušaj registrovati novog korisnika
