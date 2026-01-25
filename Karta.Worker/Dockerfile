FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY ["Karta.Worker/Karta.Worker.csproj", "Karta.Worker/"]
COPY ["Karta.Service/Karta.Service.csproj", "Karta.Service/"]
COPY ["Karta.Model/Karta.Model.csproj", "Karta.Model/"]
RUN dotnet restore "Karta.Worker/Karta.Worker.csproj"
COPY . .
RUN dotnet publish "Karta.Worker/Karta.Worker.csproj" -c Release -o /app/publish

FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS final
WORKDIR /app
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "Karta.Worker.dll"]
