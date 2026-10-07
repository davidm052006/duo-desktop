FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

COPY cloud/DuoDesktop.Cloud.csproj cloud/
RUN dotnet restore cloud/DuoDesktop.Cloud.csproj

COPY cloud/ cloud/
RUN dotnet publish cloud/DuoDesktop.Cloud.csproj \
    -c Release \
    -o /app/publish \
    --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
WORKDIR /app
COPY --from=build /app/publish .

ENV ASPNETCORE_ENVIRONMENT=Production
EXPOSE 10000

ENTRYPOINT ["dotnet", "DuoDesktop.Cloud.dll"]
