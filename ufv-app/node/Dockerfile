# ──────────────────────────────────────────────────────────────
# Dockerfile – Módulo de Prácticas (Backend Node.js / Express)
# Alumno E – Equipo E
# ──────────────────────────────────────────────────────────────

# ── Etapa 1: Imagen base ligera ──────────────────────────────
FROM node:18-alpine AS production

# Metadatos
LABEL maintainer="EquipoE <equipoe@ufv.es>"
LABEL description="Backend Node.js del Módulo de Prácticas – Express + PostgreSQL + AWS S3"

# ── Etapa 2: Directorio de trabajo ───────────────────────────
WORKDIR /app

# ── Etapa 3: Instalar dependencias ──────────────────────────
# Copiar solo package.json primero para aprovechar la caché de capas
COPY package.json ./

# Instalar solo dependencias de producción y limpiar caché de npm
RUN npm install --omit=dev && \
    npm cache clean --force

# ── Etapa 4: Copiar código fuente ────────────────────────────
COPY . .

# ── Etapa 5: Crear usuario no-root (seguridad) ──────────────
RUN addgroup -S appgroup && \
    adduser -S appuser -G appgroup && \
    chown -R appuser:appgroup /app

USER appuser

# ── Etapa 6: Exponer puerto ─────────────────────────────────
EXPOSE 3003

# ── Etapa 7: Health check ───────────────────────────────────
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:3003/practicas || exit 1

# ── Etapa 8: Comando de inicio ──────────────────────────────
CMD ["node", "practicas.js"]
