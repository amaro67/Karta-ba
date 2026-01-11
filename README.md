Karta.ba

Platforma za prodaju ulaznica za događaje sa desktop aplikacijom za organizatore i mobilnom aplikacijom za korisnike.

Šta je uključeno

Ovo je full-stack sistem za prodaju karata koji se sastoji od tri glavna dijela:

Backend API – .NET 8 API sa SQL Server bazom, Stripe plaćanjima i email notifikacijama

Desktop aplikacija – Flutter aplikacija za organizatore (upravljanje događajima i kartama)

Mobilna aplikacija – Flutter aplikacija za korisnike (kupovina karata)

Pokretanje projekta
Preduslovi

Potrebno je da imate instalirano:

Docker i Docker Compose

.NET 8 SDK

Flutter SDK

IDE (VS Code, Rider ili Visual Studio)

Brzi start – Backend
# Pokretanje svih servisa (baza, API, RabbitMQ)
docker-compose up --build


API će biti dostupan na:
http://localhost:8080/swagger/index.html

Tipovi korisničkih naloga

Postoje tri tipa naloga, svaki sa različitim pravima pristupa:

1. Admin (Super korisnik)

Ima potpuni pristup sistemu

Samo admin može kreirati druge admin naloge

Koristi se za administraciju platforme

Test Admin nalog:

Email: amar.omerovic0607@gmail.com

Lozinka: Password123!

2. Organizator

Kreira se registracijom putem desktop aplikacije

Može kreirati i upravljati vlastitim događajima

Ima uvid u prodaju i osnovnu analitiku

Test Organizator nalog:

Email: adil+1@edu.fit.ba

Lozinka: Password123!

3. User (Obični korisnik)

Kreira se registracijom putem mobilne aplikacije

Može pregledati događaje i kupovati karte

Može pregledati kupljene karte

Ulazak na događaje putem QR koda

Test User nalog:

Email: adil@edu.fit.ba

Tok kreiranja naloga

Admin nalozi:

Samo postojeći admin može kreirati novog admina

Ne postoji opcija samostalne registracije

Organizator nalozi:

Registracija putem desktop aplikacije

Nakon registracije automatski se dodjeljuju prava organizatora

User nalozi:

Registracija putem mobilne aplikacije

Nakon prijave moguće je pregledati i kupovati karte

Migracije baze podataka

Ako želite resetovati bazu ili ručno pokrenuti migracije:

# Zaustavi kontejnere
docker-compose down

# Obriši volume baze (UPOZORENJE: briše sve podatke)
docker volume rm karta_sqlserver_data

# Ponovo pokreni sve
docker-compose up --build


Migracije se automatski izvršavaju prilikom pokretanja API-ja.

Važni API URL-ovi

API: http://localhost:8080

RabbitMQ Management: http://localhost:15672 (guest / guest)

Swagger dokumentacija: http://localhost:8080/swagger

Česti problemi

Docker se ne pokreće:

Provjeriti da portovi 1433, 5672, 8080 ili 15672 nisu zauzeti

Probati:

docker-compose down
docker-compose up --build


Neuspješna prijava:

Koristiti admin podatke navedene iznad

Provjeriti da li se baza pravilno inicijalizovala (Docker logovi)

Probati registrovati novog korisnika

Povezivanje na bazu:

Host: localhost

Port: 1433

User: sa

Password: provjeriti .env fajl (KartaPassword2024!)

Database: KartaDb

Testiranje plaćanja

Koristiti Stripe test kartice:

Uspješno plaćanje: 4242 4242 4242 4242

Odbijena kartica: 4000 0000 0000 0002

Bilo koji budući datum isteka i CVC
