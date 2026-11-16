# The PlayPals relay. Render (or any Docker host) builds this file.
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
COPY src/PlayPals.Relay/PlayPals.Relay.csproj src/PlayPals.Relay/
RUN dotnet restore src/PlayPals.Relay/PlayPals.Relay.csproj
COPY src/ src/
RUN dotnet publish src/PlayPals.Relay/PlayPals.Relay.csproj -c Release -o /app --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:10.0
WORKDIR /app
COPY --from=build /app .
# Runs as the image's own non-root user. Listens on $PORT when the host
# sets it (Render does), otherwise on 8080.
USER $APP_UID
ENV ASPNETCORE_HTTP_PORTS=8080
EXPOSE 8080
ENTRYPOINT ["dotnet", "PlayPals.Relay.dll"]
