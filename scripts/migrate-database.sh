#!/bin/bash

# Database Migration Script for Karta.ba
# This script helps migrate from SQLite to SQL Server

echo "🚀 Starting Karta.ba database migration to SQL Server..."

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker first."
    exit 1
fi

# Create scripts directory if it doesn't exist
mkdir -p scripts

echo "📦 Building the application..."
docker-compose build karta-api

echo "🗄️ Starting SQL Server database..."
docker-compose up -d sqlserver

echo "⏳ Waiting for SQL Server to be ready..."
sleep 15

echo "🔄 Running Entity Framework migrations..."
docker-compose run --rm karta-api dotnet ef database update

echo "✅ Database migration completed!"
echo ""
echo "📋 Next steps:"
echo "1. Start the full application: docker-compose up -d"
echo "2. Check logs: docker-compose logs -f karta-api"
echo "3. Access the API: http://localhost:8080"
echo "4. Access Swagger: http://localhost:8080/swagger"
echo ""
echo "🔧 To connect to SQL Server directly:"
echo "   Server: localhost,1433"
echo "   Database: KartaDb"
echo "   Username: sa"
echo "   Password: KartaPassword2024!"
echo "   Trust Server Certificate: true"
