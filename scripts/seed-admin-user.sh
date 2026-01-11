#!/bin/bash

# Script to seed admin user manually
# Usage: ./scripts/seed-admin-user.sh

echo "🌱 Seeding admin user..."

# Set connection string
export CONNECTION_STRING="${CONNECTION_STRING:-Server=localhost,1433;Database=KartaDb;User Id=sa;Password=KartaPassword2024!;TrustServerCertificate=true;MultipleActiveResultSets=true;}"

# Check if SQL Server is running (if using Docker)
if command -v docker &> /dev/null && docker ps | grep -q karta-sqlserver; then
    echo "✅ SQL Server container is running"
elif command -v docker &> /dev/null; then
    echo "⚠️  SQL Server container is not running. Starting it..."
    docker-compose up -d sqlserver
    echo "⏳ Waiting for SQL Server to be ready..."
    sleep 15
fi

# Run the seed program
echo "🔄 Running seed program..."
dotnet run --project scripts/SeedAdminUser/SeedAdminUser.csproj

echo "✅ Seed completed!"

