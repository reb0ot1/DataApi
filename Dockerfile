# See https://aka.ms/customizecontainer to learn how to customize your debug container and how Visual Studio uses this Dockerfile to build your images for faster debugging.

# This stage is used when running from VS in fast mode (Default for Debug configuration)
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS base
USER $APP_UID
WORKDIR /app
EXPOSE 8080
EXPOSE 8081


# This stage is used to build the service project.
# It always runs on the build host's native architecture (BUILDPLATFORM) so the
# SDK/JIT never runs under QEMU emulation, even when TARGETPLATFORM is arm64.
FROM --platform=$BUILDPLATFORM mcr.microsoft.com/dotnet/sdk:9.0 AS build
ARG BUILD_CONFIGURATION=Release
ARG TARGETARCH
WORKDIR /src
COPY ["DataApi.csproj", "."]
RUN case "$TARGETARCH" in \
      "amd64") ARCH=x64 ;; \
      "arm64") ARCH=arm64 ;; \
      "arm")   ARCH=arm ;; \
      "386")   ARCH=x86 ;; \
      *) echo "Unsupported TARGETARCH: $TARGETARCH" && exit 1 ;; \
    esac \
 && dotnet restore "./DataApi.csproj" -a $ARCH
COPY . .
WORKDIR "/src/."
RUN case "$TARGETARCH" in \
      "amd64") ARCH=x64 ;; \
      "arm64") ARCH=arm64 ;; \
      "arm")   ARCH=arm ;; \
      "386")   ARCH=x86 ;; \
    esac \
 && dotnet build "./DataApi.csproj" -c $BUILD_CONFIGURATION -a $ARCH -o /app/build

# This stage is used to publish the service project to be copied to the final stage
FROM build AS publish
ARG BUILD_CONFIGURATION=Release
ARG TARGETARCH
RUN case "$TARGETARCH" in \
      "amd64") ARCH=x64 ;; \
      "arm64") ARCH=arm64 ;; \
      "arm")   ARCH=arm ;; \
      "386")   ARCH=x86 ;; \
    esac \
 && dotnet publish "./DataApi.csproj" -c $BUILD_CONFIGURATION -a $ARCH -o /app/publish /p:UseAppHost=false

# This stage is used in production or when running from VS in regular mode (Default when not using the Debug configuration).
# Only this lightweight runtime image is assembled for TARGETPLATFORM (e.g. arm64) -
# it contains no SDK/compiler, so there is nothing expensive left for QEMU to emulate.
FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "DataApi.dll"]