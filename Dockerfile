# Base image -> Maven + JDK 17
FROM maven:3.9.9-eclipse-temurin-17 AS build

# Set the working directory
WORKDIR /workspace

# Copy maven wrapper + pom first for better layer caching
COPY .mvn/ .mvn/
COPY mvnw pom.xml ./

# Build the application (this will download dependencies and compile the code)
RUN mvn -DskipTests dependency:go-offline

# Now copy the rest of the source code
COPY src ./src

# Package the application (this will create the JAR file)
RUN mvn -DskipTests package

# Use a smaller base image for the runtime
FROM eclipse-temurin:17-jre
WORKDIR /app

COPY --from=build /workspace/target/*.jar app.jar

EXPOSE 8081

ENTRYPOINT ["java", "-jar", "app.jar"]