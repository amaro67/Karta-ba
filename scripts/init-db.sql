
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'KartaDb')
BEGIN
    CREATE DATABASE KartaDb;
END

USE KartaDb;

PRINT 'Karta.ba database initialized successfully';
