# =============================================================================
# Dockerfile Web Next.js - Vision360
# =============================================================================
# Image de production multi-stage pour l'application Next.js
# Build : docker build -t vision360-web ./web_next
# Run   : docker run -p 3000:3000 vision360-web
# =============================================================================

# -----------------------------------------------------------------------------
# Stage 1 : Installation des dépendances
# -----------------------------------------------------------------------------
# Installe les dépendances npm dans une image séparée pour le cache
FROM node:20-alpine AS deps
WORKDIR /app

# Copier les fichiers de dépendances
COPY package.json package-lock.json ./

# Installer les dépendances (npm ci pour installation propre)
RUN npm ci

# -----------------------------------------------------------------------------
# Stage 2 : Build de l'application
# -----------------------------------------------------------------------------
# Compile l'application Next.js pour la production
FROM node:20-alpine AS builder
WORKDIR /app

# Copier les dépendances depuis le stage précédent
COPY --from=deps /app/node_modules ./node_modules

# Copier le code source
COPY . .

# Désactiver la télémétrie Next.js
ENV NEXT_TELEMETRY_DISABLED=1

# Build de production
RUN npm run build

# -----------------------------------------------------------------------------
# Stage 3 : Image de production
# -----------------------------------------------------------------------------
# Image minimale pour exécuter l'application
FROM node:20-alpine AS runner
WORKDIR /app

# Configuration pour la production
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

# Copier les fichiers nécessaires depuis le builder
# - public : Assets statiques
# - .next : Build compilé
# - node_modules : Dépendances de production
# - package.json : Scripts npm
COPY --from=builder /app/public ./public
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./package.json

# Port exposé
EXPOSE 3000

# Commande de démarrage
CMD ["npm", "run", "start"]
