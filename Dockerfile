# Build stage: Maven + JDK 17
FROM maven:3.9.9-eclipse-temurin-17 AS build
WORKDIR /workspace

# Copy only pom first to maximize Docker cache hits for dependencies
COPY pom.xml ./

# Cache Maven repo between builds (BuildKit) and prefetch dependencies
RUN --mount=type=cache,target=/root/.m2 mvn -DskipTests dependency:go-offline

# Copy sources and build a runnable Spring Boot jar
COPY src ./src
RUN --mount=type=cache,target=/root/.m2 mvn -DskipTests package \
  && JAR_PATH="$(ls -1 target/*.jar | grep -vE '\\.jar\\.original$' | head -n 1)" \
  && test -n "$JAR_PATH" \
  && cp "$JAR_PATH" /workspace/app.jar

# Runtime stage: smaller JRE image
FROM eclipse-temurin:17-jre
WORKDIR /app

RUN useradd --create-home --shell /usr/sbin/nologin appuser \
  && chown -R appuser:appuser /app

COPY --from=build --chown=appuser:appuser /workspace/app.jar /app/app.jar

USER appuser
EXPOSE 8081
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
