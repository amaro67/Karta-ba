# Event Images

## Gdje staviti slike

Stavite slike `event1.jpg` i `event2.jpg` u ovaj folder:
```
Karta.WebAPI/wwwroot/images/
```

## Kako radi

- Backend će automatski rotirati između `event1.jpg` i `event2.jpg` za sve evente
- Flutter app će automatski konvertovati relativne URL-ove (`/images/event1.jpg`) u apsolutne URL-ove
- Slike se serviraju kao statički fajlovi kroz ASP.NET Core

## Format slika

- Preporučeni format: JPG ili PNG
- Preporučena rezolucija: 800x600 ili veća
- Preporučena veličina: < 500KB po slici

## Napomena

Ako već postoje eventi u bazi sa starim URL-ovima (`https://example.com/images/eventX.jpg`), trebate ih ažurirati ili resetovati bazu podataka.

