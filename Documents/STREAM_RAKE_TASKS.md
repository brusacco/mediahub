# Stream Rake Tasks - Reference Guide

Documentación de referencia para los rake tasks de gestión de streams en MediaHub.

## Tabla de Contenidos

1. [Tasks Individuales por Estación](#tasks-individuales-por-estación)
2. [Tasks de Desarrollo (macOS/Local)](#tasks-de-desarrollo-macoslocal)
3. [Tasks de Producción (systemd)](#tasks-de-producción-systemd)
4. [Orquestador](#orquestador)
5. [Ejemplos de Uso](#ejemplos-de-uso)
6. [Troubleshooting](#troubleshooting)

---

## Tasks Individuales por Estación

### `stream:listen_station[STATION_ID]`

Escucha el stream de una estación específica. Este es el worker principal que maneja la conexión FFmpeg.

**Uso:**

```bash
# En zsh (macOS) - usar comillas simples
rake 'stream:listen_station[1]'

# En bash (Linux)
rake stream:listen_station[1]
```

**Características:**

- Maneja una sola conexión de streaming
- Detección de desconexiones en tiempo real mediante monitoreo de stderr
- Heartbeat basado en archivos generados
- Retry con backoff exponencial (5s, 10s, 20s, máx 60s)
- Manejo de señales para cierre limpio
- Actualiza `stream_status` y `last_heartbeat_at` en la BD

**Parámetros:**

- `STATION_ID`: ID numérico de la estación

**Ejemplo:**

```bash
rake 'stream:listen_station[1]'  # Escucha la estación con ID 1
```

**Notas:**

- Este task corre continuamente hasta recibir señal de terminación
- Los logs se escriben en `log/stream-station-{ID}.log`
- Actualiza el heartbeat cada vez que se genera un nuevo segmento de video

---

## Tasks de Desarrollo (macOS/Local)

Estos tasks están diseñados para desarrollo local donde no hay systemd disponible.

### `stream:dev:setup`

Crea el directorio necesario para almacenar archivos PID.

**Uso:**

```bash
rake stream:dev:setup
```

**Nota:** Se ejecuta automáticamente cuando usas otros tasks de desarrollo.

---

### `stream:dev:start[STATION_ID]`

Inicia un listener para una estación específica en modo desarrollo (proceso en background).

**Uso:**

```bash
rake 'stream:dev:start[1]'
```

**Características:**

- Crea un proceso en background
- Guarda el PID en `tmp/pids/stream/stream-station-{ID}.pid`
- Los logs van a `log/stream-station-{ID}.log`
- Verifica si ya está corriendo antes de iniciar

**Ejemplo:**

```bash
rake 'stream:dev:start[1]'  # Inicia listener para estación 1
```

**Salida esperada:**

```
Created PID directory: /path/to/tmp/pids/stream
Started station Telefuturo (ID: 1) with PID: 54244
Logs: /path/to/log/stream-station-1.log
PID file: /path/to/tmp/pids/stream/stream-station-1.pid
```

---

### `stream:dev:stop[STATION_ID]`

Detiene el listener de una estación específica.

**Uso:**

```bash
rake 'stream:dev:stop[1]'
```

**Características:**

- Envía señal TERM al proceso
- Si no responde, envía señal KILL después de 1 segundo
- Elimina el archivo PID
- Maneja procesos zombies correctamente

**Ejemplo:**

```bash
rake 'stream:dev:stop[1]'  # Detiene listener para estación 1
```

---

### `stream:dev:restart[STATION_ID]`

Reinicia el listener de una estación específica.

**Uso:**

```bash
rake 'stream:dev:restart[1]'
```

**Ejemplo:**

```bash
rake 'stream:dev:restart[1]'  # Reinicia listener para estación 1
```

---

### `stream:dev:start_all`

Inicia listeners para todas las estaciones activas.

**Uso:**

```bash
rake stream:dev:start_all
```

**Características:**

- Itera sobre todas las estaciones con `active: true`
- Inicia cada una con un pequeño delay (1 segundo) entre ellas
- Útil para iniciar todo el sistema después de un reinicio

**Ejemplo:**

```bash
rake stream:dev:start_all
```

---

### `stream:dev:stop_all`

Detiene todos los listeners activos.

**Uso:**

```bash
rake stream:dev:stop_all
```

**Características:**

- Encuentra todos los archivos PID en `tmp/pids/stream/`
- Detiene cada proceso
- Limpia archivos PID

**Ejemplo:**

```bash
rake stream:dev:stop_all
```

---

### `stream:dev:status`

Muestra el estado de todos los listeners.

**Uso:**

```bash
rake stream:dev:status
```

**Características:**

- Muestra estado de todas las estaciones
- Indica si el proceso está corriendo o no
- Muestra PID, estado en BD, y último heartbeat
- Limpia automáticamente archivos PID obsoletos

**Ejemplo:**

```bash
rake stream:dev:status
```

**Salida esperada:**

```
Status of stream listeners (development mode):
================================================================================
✓ Telefuturo (ID: 1  ) - running (PID: 54244) - DB Status: connected - Heartbeat: 2025-11-15 10:31:24
✗ Canal 9 (ID: 2  ) - not running - DB Status: disconnected
================================================================================
```

---

### `stream:dev:orchestrator`

Inicia el orquestador en modo desarrollo.

**Uso:**

```bash
rake stream:dev:orchestrator
```

**Características:**

- Monitorea todas las estaciones activas
- Detecta estaciones desconectadas o con heartbeat obsoleto
- Inicia/reinicia procesos automáticamente
- Usa gestión de procesos en lugar de systemd

**Variables de entorno:**

- `ORCHESTRATOR_INTERVAL`: Intervalo de verificación en segundos (default: 60)

**Ejemplo:**

```bash
# Con intervalo personalizado
ORCHESTRATOR_INTERVAL=30 rake stream:dev:orchestrator

# Intervalo por defecto (60 segundos)
rake stream:dev:orchestrator
```

---

## Tasks de Producción (systemd)

Estos tasks están diseñados para producción en Linux con systemd.

### `stream:systemd:generate[STATION_ID]`

Genera el contenido del archivo de servicio systemd para una estación.

**Uso:**

```bash
sudo rake 'stream:systemd:generate[1]'
```

**Características:**

- Muestra el contenido del archivo de servicio
- No instala el servicio, solo muestra cómo sería
- Útil para revisar antes de instalar

**Ejemplo:**

```bash
sudo rake 'stream:systemd:generate[1]'
```

---

### `stream:systemd:install[STATION_ID]`

Instala el servicio systemd para una estación (requiere sudo).

**Uso:**

```bash
sudo rake 'stream:systemd:install[1]'
```

**Características:**

- Crea el archivo de servicio en `/etc/systemd/system/`
- Ejecuta `systemctl daemon-reload`
- Habilita el servicio para inicio automático
- No inicia el servicio (usa `start` después)

**Ejemplo:**

```bash
sudo rake 'stream:systemd:install[1]'
```

**Nota:** Requiere permisos de sudo.

---

### `stream:systemd:uninstall[STATION_ID]`

Desinstala el servicio systemd de una estación (requiere sudo).

**Uso:**

```bash
sudo rake 'stream:systemd:uninstall[1]'
```

**Características:**

- Detiene el servicio primero
- Deshabilita el servicio
- Elimina el archivo de servicio
- Recarga systemd

**Ejemplo:**

```bash
sudo rake 'stream:systemd:uninstall[1]'
```

---

### `stream:systemd:start[STATION_ID]`

Inicia el servicio systemd de una estación.

**Uso:**

```bash
rake 'stream:systemd:start[1]'
```

**Ejemplo:**

```bash
rake 'stream:systemd:start[1]'
```

---

### `stream:systemd:stop[STATION_ID]`

Detiene el servicio systemd de una estación.

**Uso:**

```bash
rake 'stream:systemd:stop[1]'
```

**Ejemplo:**

```bash
rake 'stream:systemd:stop[1]'
```

---

### `stream:systemd:restart[STATION_ID]`

Reinicia el servicio systemd de una estación.

**Uso:**

```bash
rake 'stream:systemd:restart[1]'
```

**Ejemplo:**

```bash
rake 'stream:systemd:restart[1]'
```

---

### `stream:systemd:install_all`

Instala servicios systemd para todas las estaciones activas.

**Uso:**

```bash
sudo rake stream:systemd:install_all
```

**Características:**

- Itera sobre todas las estaciones activas
- Instala el servicio para cada una
- Útil para setup inicial del sistema

**Ejemplo:**

```bash
sudo rake stream:systemd:install_all
```

---

### `stream:systemd:start_all`

Inicia todos los servicios systemd de estaciones activas.

**Uso:**

```bash
rake stream:systemd:start_all
```

**Ejemplo:**

```bash
rake stream:systemd:start_all
```

---

### `stream:systemd:stop_all`

Detiene todos los servicios systemd de estaciones activas.

**Uso:**

```bash
rake stream:systemd:stop_all
```

**Ejemplo:**

```bash
rake stream:systemd:stop_all
```

---

### `stream:systemd:status_all`

Muestra el estado de todos los servicios systemd.

**Uso:**

```bash
rake stream:systemd:status_all
```

**Características:**

- Muestra estado de todas las estaciones
- Indica si el servicio está instalado y activo
- Muestra estado en BD y último heartbeat

**Ejemplo:**

```bash
rake stream:systemd:status_all
```

**Salida esperada:**

```
Status of systemd services for all stations:
================================================================================
✓ Telefuturo (ID: 1  ) - Service: active     - DB Status: connected - Heartbeat: 2025-11-15 10:31:24
✗ Canal 9 (ID: 2  ) - Service: not installed
================================================================================
```

---

## Orquestador

### `stream:orchestrator`

Orquestador principal que monitorea y gestiona todos los listeners.

**Uso:**

```bash
rake stream:orchestrator
```

**Características:**

- Detecta automáticamente si está en desarrollo o producción
- En desarrollo: usa gestión de procesos
- En producción: usa systemd
- Monitorea todas las estaciones activas cada 60 segundos (configurable)
- Detecta desconexiones y reinicia automáticamente
- Verifica heartbeat y reinicia si está obsoleto

**Variables de entorno:**

- `ORCHESTRATOR_INTERVAL`: Intervalo de verificación en segundos (default: 60)
- `SERVICE_PREFIX`: Prefijo para nombres de servicios systemd (default: `mediahub-stream`)
- `SERVICE_USER`: Usuario para ejecutar servicios (default: `www-data` o usuario actual)

**Ejemplo:**

```bash
# Intervalo por defecto (60 segundos)
rake stream:orchestrator

# Con intervalo personalizado
ORCHESTRATOR_INTERVAL=30 rake stream:orchestrator

# En producción con variables personalizadas
SERVICE_USER=mediahub ORCHESTRATOR_INTERVAL=45 rake stream:orchestrator
```

**Nota:** Este task corre continuamente. Para detenerlo, usa Ctrl+C.

---

## Ejemplos de Uso

### Setup Inicial en Desarrollo

```bash
# 1. Ejecutar migración
rails db:migrate

# 2. Iniciar todos los listeners
rake stream:dev:start_all

# 3. Verificar estado
rake stream:dev:status

# 4. (Opcional) Iniciar orquestador para monitoreo automático
rake stream:dev:orchestrator
```

### Setup Inicial en Producción

```bash
# 1. Ejecutar migración
RAILS_ENV=production rails db:migrate

# 2. Instalar servicios systemd para todas las estaciones activas
sudo rake stream:systemd:install_all

# 3. Iniciar todos los servicios
rake stream:systemd:start_all

# 4. Verificar estado
rake stream:systemd:status_all

# 5. Configurar orquestador como servicio systemd (ver SYSTEM_DOCUMENTATION.md)
```

### Gestión Individual de Estación

```bash
# Desarrollo
rake 'stream:dev:start[1]'      # Iniciar una estación
rake 'stream:dev:stop[1]'       # Detener una estación
rake 'stream:dev:restart[1]'    # Reiniciar una estación
rake stream:dev:status          # Ver estado de todas las estaciones

# Detener TODOS los listeners
rake stream:dev:stop_all        # Detiene todos los listeners activos

# Producción
sudo rake 'stream:systemd:install[1]'  # Instalar servicio
rake 'stream:systemd:start[1]'         # Iniciar
rake 'stream:systemd:stop[1]'          # Detener
rake 'stream:systemd:restart[1]'       # Reiniciar
rake stream:systemd:status_all         # Ver estado
```

### Monitoreo y Logs

```bash
# Ver logs de una estación específica (desarrollo)
tail -f log/stream-station-1.log

# Ver logs de servicio systemd (producción)
sudo journalctl -u mediahub-stream-1 -f

# Ver logs del orquestador (producción)
sudo journalctl -u mediahub-orchestrator -f

# Verificar archivos generados
ls -lt public/videos/{station_directory}/temp/ | head -10
```

---

## Troubleshooting

### Problema: "zsh: no matches found" en macOS

**Solución:** Usar comillas simples alrededor del task:

```bash
# ❌ Incorrecto
rake stream:dev:start[1]

# ✅ Correcto
rake 'stream:dev:start[1]'
```

### Problema: Proceso no inicia

**Verificar:**

1. Estación existe y está activa:

   ```bash
   rails console
   Station.find(1).active?
   ```

2. Stream URL está configurada:

   ```bash
   rails console
   Station.find(1).stream_url
   ```

3. Ver logs:
   ```bash
   tail -f log/stream-station-1.log
   ```

### Problema: Heartbeat obsoleto

**Solución:**

1. Verificar que se están generando archivos:

   ```bash
   ls -lt public/videos/{station_directory}/temp/ | head -5
   ```

2. Reiniciar el listener:

   ```bash
   rake 'stream:dev:restart[1]'
   ```

3. Si persiste, verificar logs para errores de FFmpeg

### Problema: Proceso zombie

**Solución:**

```bash
# Detener proceso
rake 'stream:dev:stop[1]'

# Verificar que el PID file fue eliminado
ls tmp/pids/stream/

# Si existe, eliminarlo manualmente
rm tmp/pids/stream/stream-station-1.pid

# Reiniciar
rake 'stream:dev:start[1]'
```

### Problema: Orquestador no detecta cambios

**Verificar:**

1. Intervalo de verificación:

   ```bash
   # Verificar variable de entorno
   echo $ORCHESTRATOR_INTERVAL
   ```

2. Logs del orquestador:

   ```bash
   tail -f log/development.log | grep -i orchestrator
   ```

3. Reiniciar orquestador con intervalo más corto:
   ```bash
   ORCHESTRATOR_INTERVAL=30 rake stream:orchestrator
   ```

### Problema: systemd service no inicia

**Verificar:**

1. Servicio está instalado:

   ```bash
   systemctl status mediahub-stream-1
   ```

2. Ver logs del servicio:

   ```bash
   sudo journalctl -u mediahub-stream-1 -n 50
   ```

3. Verificar permisos y usuario:

   ```bash
   sudo systemctl show mediahub-stream-1 | grep User
   ```

4. Reinstalar si es necesario:
   ```bash
   sudo rake 'stream:systemd:uninstall[1]'
   sudo rake 'stream:systemd:install[1]'
   rake 'stream:systemd:start[1]'
   ```

---

## Comandos Útiles Adicionales

### Limpieza de datos de desarrollo

```bash
# Limpiar todos los videos (archivos y registros BD) + temp directories
rake dev:cleanup:videos

# Solo limpiar archivos de video (mantiene BD)
rake dev:cleanup:video_files

# Solo limpiar registros de BD (mantiene archivos)
rake dev:cleanup:video_records

# Solo limpiar directorios temp de todas las estaciones
rake dev:cleanup:temp_directories
```

**Nota importante:** Todos los tasks de limpieza solo funcionan en desarrollo. Si intentas ejecutarlos en producción, se detendrán con un error.

### Ver todos los rake tasks disponibles

```bash
rake -T stream
```

### Verificar estado en consola Rails

```bash
rails console

# Verificar estación
station = Station.find(1)
station.active?
station.stream_status
station.last_heartbeat_at
station.healthy?
station.needs_attention?

# Ver todas las estaciones que necesitan atención
Station.needs_attention

# Ver estaciones saludables
Station.healthy
```

### Limpiar archivos PID obsoletos

```bash
# Desarrollo
find tmp/pids/stream -name "*.pid" -exec sh -c 'kill -0 "$(cat {})" 2>/dev/null || rm {}' \;
```

---

## Notas Importantes

1. **En macOS (zsh)**: Siempre usar comillas simples alrededor de tasks con argumentos: `rake 'task[arg]'`

2. **En Linux (bash)**: Puedes usar sin comillas: `rake task[arg]`

3. **Permisos**: Los tasks de systemd requieren sudo para install/uninstall, pero no para start/stop/restart

4. **Logs**: Los logs de desarrollo van a `log/stream-station-{ID}.log`, los de producción a journald

5. **Heartbeat**: Se actualiza cada vez que se genera un nuevo segmento de video (cada ~60 segundos)

6. **Detección de desconexión**: El sistema usa múltiples métodos:
   - Monitoreo de stderr de FFmpeg en tiempo real
   - Verificación de heartbeat (si no hay nuevo archivo en 3 minutos)
   - Verificación de estado del proceso/service

---

## Referencias

- Documentación completa del sistema: `SYSTEM_DOCUMENTATION.md`
- Guía de deployment: Ver sección "Stream Architecture Deployment" en `SYSTEM_DOCUMENTATION.md`
- Cursor Rules: `.cursorrules`
