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
# Npgsql/SSPI may load GSSAPI at runtime. Install the shared library to
# prevent libgssapi_krb5.so.2 loader failures in Render's slim image.
RUN apt-get update \
    && apt-get install -y --no-install-recommends libgssapi-krb5-2 \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=build /app/publish .

ENV ASPNETCORE_ENVIRONMENT=Production
EXPOSE 10000

ENTRYPOINT ["dotnet", "DuoDesktop.Cloud.dll"]
