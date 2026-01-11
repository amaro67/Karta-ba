# Multi-stage build za optimizaciju veličine image-a
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Kopiramo csproj fajlove i restore-ujemo dependencies
COPY ["Karta.WebAPI/Karta.WebAPI.csproj", "Karta.WebAPI/"]
COPY ["Karta.Service/Karta.Service.csproj", "Karta.Service/"]
COPY ["Karta.Model/Karta.Model.csproj", "Karta.Model/"]

# Restore dependencies
RUN dotnet restore "Karta.WebAPI/Karta.WebAPI.csproj"

# Kopiramo samo .NET source code (eksplicitno, bez Flutter UI)
COPY Karta.WebAPI/ Karta.WebAPI/
COPY Karta.Service/ Karta.Service/
COPY Karta.Model/ Karta.Model/

# Build aplikacije
WORKDIR "/src/Karta.WebAPI"
RUN dotnet build "Karta.WebAPI.csproj" -c Release -o /app/build

# Publish aplikacije
FROM build AS publish
RUN dotnet publish "Karta.WebAPI.csproj" -c Release -o /app/publish /p:UseAppHost=false

# Finalni stage - runtime image
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS final
WORKDIR /app

# Kopiramo published aplikaciju
COPY --from=publish /app/publish .

# Kopiramo wwwroot folder sa slikama (ako postoji u build stage)
COPY --from=build /src/Karta.WebAPI/wwwroot ./wwwroot

# Kreiramo direktorijum za logove
RUN mkdir -p /app/logs

# Instaliramo curl za health check
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Ekspozujemo port 8080
EXPOSE 8080

# Dodajemo health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8080/ || exit 1

# Pokretanje aplikacije
ENTRYPOINT ["dotnet", "Karta.WebAPI.dll"]
