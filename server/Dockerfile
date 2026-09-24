# syntax=docker/dockerfile:1
#
# Multi-stage build for the IWantFigure server.
#
# The build context must be the REPOSITORY ROOT (not server/), because the server links
# shared/analysis.schema.json, shared/prompt/system_prompt.md and shared/samples/*.json
# into the assembly as embedded resources:
#
#   docker build -f server/Dockerfile -t iwantfigure-server .
#   docker run --rm -p 8080:8080 \
#     -e Analysis__Provider=claude -e Claude__ApiKey=sk-ant-... -e Server__AppKey=change-me \
#     iwantfigure-server
#
# The files excluded from the context are listed in server/Dockerfile.dockerignore.

# ---------- build ----------------------------------------------------------------
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

# Restore first so the NuGet layer is cached between code changes.
COPY shared/ shared/
COPY server/Directory.Build.props server/
COPY server/IWantFigure.Server/IWantFigure.Server.csproj server/IWantFigure.Server/
RUN dotnet restore server/IWantFigure.Server/IWantFigure.Server.csproj

COPY server/IWantFigure.Server/ server/IWantFigure.Server/
RUN dotnet publish server/IWantFigure.Server/IWantFigure.Server.csproj \
      -c Release -o /app /p:UseAppHost=false

# ---------- runtime --------------------------------------------------------------
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
WORKDIR /app
COPY --from=build /app .

# Listen on all interfaces inside the container. Override with -e ASPNETCORE_URLS=...
ENV ASPNETCORE_URLS=http://+:8080 \
    ASPNETCORE_ENVIRONMENT=Production \
    DOTNET_EnableDiagnostics=0

EXPOSE 8080

# The aspnet image ships a non-root "app" user (uid 1654). Use it.
USER app

# Orchestrators: probe GET /healthz (200 {"status":"ok","provider":"..."}).
ENTRYPOINT ["dotnet", "IWantFigure.Server.dll"]
