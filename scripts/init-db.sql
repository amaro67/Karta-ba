
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'IB210242')
BEGIN
    CREATE DATABASE IB210242;
END

USE IB210242;

PRINT 'Karta.ba database initialized successfully';
