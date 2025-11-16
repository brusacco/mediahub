# Análisis de Opciones FFmpeg para Segmentación

## ⚠️ IMPORTANTE: Configuración Optimizada para Calidad de Audio

**Esta configuración prioriza la calidad del audio para transcripciones precisas con Whisper.**

La calidad del audio es crítica porque:
- Las transcripciones dependen completamente de la claridad del audio
- Whisper es muy sensible a la calidad del audio de entrada
- Mejor audio = transcripciones más precisas y menos errores

## Configuración Actual (Optimizada para Audio)

```ruby
command = [
  'ffmpeg',
  '-i', station.stream_url,
  '-vf', 'scale=1024:-1',
  '-f', 'segment',
  '-segment_time', '60',
  '-reset_timestamps', '1',
  '-strftime', '1',
  '-preset', 'veryfast',
  '-timeout', '5000000', # 5 seconds timeout in microseconds
  '-reconnect', '1',
  '-reconnect_at_eof', '1',
  '-reconnect_streamed', '1',
  '-reconnect_delay_max', '2',
  output_pattern
]
```

---

## Análisis por Opción

### ✅ Opciones Correctas

1. **`-f segment`** ✅
   - Formato correcto para segmentación
   - Genera archivos individuales por segmento

2. **`-segment_time 60`** ✅
   - 60 segundos es apropiado para el caso de uso
   - Balance entre tamaño de archivo y granularidad

3. **`-reset_timestamps 1`** ✅
   - Necesario para que cada segmento sea independiente
   - Evita problemas de sincronización

4. **`-strftime 1`** ✅
   - Permite usar formato de fecha en nombres de archivo
   - Compatible con el formato esperado: `%Y-%m-%dT%H_%M_%S.mp4`

5. **`-reconnect 1`** ✅
   - Reconexión automática es esencial para streams continuos

6. **`-reconnect_at_eof 1`** ✅
   - Reconecta al final del stream (útil para streams que terminan)

7. **`-reconnect_streamed 1`** ✅
   - Reconecta streams en tiempo real

8. **`-reconnect_delay_max 2`** ✅
   - Delay máximo razonable (2 segundos)

---

### ⚠️ Opciones que Necesitan Mejora

#### 1. **`-preset veryfast`** ⚠️

**Problema:**
- Reduce calidad de video significativamente
- Genera archivos más grandes con menor calidad
- No es ideal para archivos que se almacenan permanentemente

**Recomendación:**
```ruby
'-preset', 'medium'  # Balance entre velocidad y calidad
# o
'-preset', 'fast'    # Más rápido que medium, mejor que veryfast
```

**Alternativa (más control):**
```ruby
'-crf', '23',        # Constant Rate Factor (calidad constante)
'-preset', 'medium'  # Velocidad de codificación
```

#### 2. **Falta especificar codecs** ⚠️

**Problema:**
- No especifica codec de video (`-c:v`)
- No especifica codec de audio (`-c:a`)
- FFmpeg puede usar codecs no optimizados o incompatibles

**Recomendación:**
```ruby
'-c:v', 'libx264',   # Codec de video H.264 (compatible universalmente)
'-c:a', 'aac',       # Codec de audio AAC (estándar para MP4)
'-profile:v', 'high', # Perfil H.264 para mejor compatibilidad
'-level', '4.0',     # Nivel H.264
```

#### 3. **Falta control de bitrate** ⚠️

**Problema:**
- Sin control de bitrate, puede generar archivos muy grandes
- No hay límite máximo de tamaño por segmento

**Recomendación:**
```ruby
'-b:v', '2000k',     # Bitrate de video (2 Mbps - ajustar según necesidad)
'-maxrate', '2500k', # Bitrate máximo
'-bufsize', '4000k', # Buffer size (2x maxrate)
'-b:a', '128k',      # Bitrate de audio (128 kbps es suficiente)
```

#### 4. **`-timeout 5000000` (5 segundos)** ⚠️

**Problema:**
- 5 segundos puede ser muy corto para streams lentos
- Puede causar desconexiones prematuras

**Recomendación:**
```ruby
'-timeout', '10000000', # 10 segundos (más tolerante)
# o
'-timeout', '15000000', # 15 segundos (para conexiones lentas)
```

#### 5. **Falta `-segment_format`** ⚠️

**Problema:**
- No especifica explícitamente el formato de segmento
- Puede causar problemas de compatibilidad

**Recomendación:**
```ruby
'-segment_format', 'mp4', # Formato explícito de segmento
```

#### 6. **Falta control de GOP (Group of Pictures)** ⚠️

**Problema:**
- Sin control de GOP, los segmentos pueden no ser independientes
- Importante para segmentación precisa

**Recomendación:**
```ruby
'-g', '60',          # GOP size = segment_time (1 segundo = 1 frame clave)
'-keyint_min', '60', # Mínimo intervalo entre keyframes
```

#### 7. **Escalado `scale=1024:-1`** ⚠️

**Problema:**
- Solo especifica ancho, altura se calcula automáticamente
- No preserva aspect ratio explícitamente
- No especifica algoritmo de escalado

**Recomendación:**
```ruby
'-vf', 'scale=1024:-2:flags=lanczos', # Lanczos para mejor calidad
# o mantener aspect ratio explícitamente:
'-vf', 'scale=1024:-1:force_original_aspect_ratio=decrease',
```

---

## Configuración Recomendada

### Opción 1: Balance Calidad/Performance (Recomendada)

```ruby
command = [
  'ffmpeg',
  '-i', station.stream_url,
  
  # Video codec y calidad
  '-c:v', 'libx264',
  '-preset', 'medium',
  '-crf', '23',
  '-profile:v', 'high',
  '-level', '4.0',
  '-maxrate', '2500k',
  '-bufsize', '4000k',
  
  # Audio codec
  '-c:a', 'aac',
  '-b:a', '128k',
  '-ar', '44100',
  
  # Escalado
  '-vf', 'scale=1024:-2:flags=lanczos',
  
  # Segmentación
  '-f', 'segment',
  '-segment_time', '60',
  '-segment_format', 'mp4',
  '-reset_timestamps', '1',
  '-strftime', '1',
  '-g', '60',
  '-keyint_min', '60',
  
  # Timeout y reconexión
  '-timeout', '10000000', # 10 segundos
  '-reconnect', '1',
  '-reconnect_at_eof', '1',
  '-reconnect_streamed', '1',
  '-reconnect_delay_max', '2',
  
  output_pattern
]
```

### Opción 2: Optimizada para Calidad (Archivos más grandes)

```ruby
command = [
  'ffmpeg',
  '-i', station.stream_url,
  
  # Video codec y calidad (mayor calidad)
  '-c:v', 'libx264',
  '-preset', 'slow',
  '-crf', '20',
  '-profile:v', 'high',
  '-level', '4.1',
  '-maxrate', '3000k',
  '-bufsize', '6000k',
  
  # Audio codec
  '-c:a', 'aac',
  '-b:a', '192k',
  '-ar', '48000',
  
  # Escalado
  '-vf', 'scale=1024:-2:flags=lanczos',
  
  # Segmentación
  '-f', 'segment',
  '-segment_time', '60',
  '-segment_format', 'mp4',
  '-reset_timestamps', '1',
  '-strftime', '1',
  '-g', '60',
  '-keyint_min', '60',
  
  # Timeout y reconexión
  '-timeout', '10000000',
  '-reconnect', '1',
  '-reconnect_at_eof', '1',
  '-reconnect_streamed', '1',
  '-reconnect_delay_max', '2',
  
  output_pattern
]
```

### Opción 3: Optimizada para Performance (Archivos más pequeños, menor calidad)

```ruby
command = [
  'ffmpeg',
  '-i', station.stream_url,
  
  # Video codec y calidad (más rápido, menor calidad)
  '-c:v', 'libx264',
  '-preset', 'fast',
  '-crf', '26',
  '-profile:v', 'baseline', # Baseline para mejor compatibilidad
  '-maxrate', '1500k',
  '-bufsize', '3000k',
  
  # Audio codec
  '-c:a', 'aac',
  '-b:a', '96k',
  '-ar', '44100',
  
  # Escalado
  '-vf', 'scale=1024:-2',
  
  # Segmentación
  '-f', 'segment',
  '-segment_time', '60',
  '-segment_format', 'mp4',
  '-reset_timestamps', '1',
  '-strftime', '1',
  '-g', '60',
  '-keyint_min', '60',
  
  # Timeout y reconexión
  '-timeout', '10000000',
  '-reconnect', '1',
  '-reconnect_at_eof', '1',
  '-reconnect_streamed', '1',
  '-reconnect_delay_max', '2',
  
  output_pattern
]
```

---

## Comparación de Opciones

| Aspecto | Actual | Recomendada (Opción 1) | Alta Calidad | Performance |
|---------|--------|------------------------|--------------|-------------|
| **Preset** | veryfast | medium | slow | fast |
| **CRF** | N/A | 23 | 20 | 26 |
| **Bitrate Video** | Variable | ~2 Mbps | ~3 Mbps | ~1.5 Mbps |
| **Bitrate Audio** | Variable | 128 kbps | 192 kbps | 96 kbps |
| **Tamaño Archivo** | Variable | ~15 MB/seg | ~22 MB/seg | ~11 MB/seg |
| **Calidad** | Baja | Buena | Excelente | Aceptable |
| **CPU Usage** | Bajo | Medio | Alto | Bajo |
| **Codecs** | Auto | H.264/AAC | H.264/AAC | H.264/AAC |

---

## Recomendaciones Específicas

### Para tu Caso de Uso (Streaming de TV, 60 segundos, almacenamiento permanente):

1. **Usar Opción 1 (Balance)** - Mejor relación calidad/tamaño
2. **CRF 23** - Calidad buena sin archivos excesivamente grandes
3. **Preset medium** - Balance entre velocidad y calidad
4. **Bitrate 2 Mbps** - Suficiente para video escalado a 1024px
5. **Codecs explícitos** - H.264/AAC para máxima compatibilidad
6. **GOP 60** - Un keyframe por segundo (importante para segmentación)
7. **Timeout 10 segundos** - Más tolerante a conexiones lentas

### Consideraciones Adicionales

1. **Aspect Ratio**: Si los streams tienen diferentes aspect ratios, considerar:
   ```ruby
   '-vf', 'scale=1024:-2:force_original_aspect_ratio=decrease,pad=1024:576:0:(oh-ih)/2'
   ```
   Esto fuerza 16:9 y añade padding si es necesario.

2. **Hardware Acceleration**: Si tienes GPU disponible:
   ```ruby
   '-c:v', 'h264_nvenc',  # NVIDIA
   # o
   '-c:v', 'h264_videotoolbox',  # macOS
   ```

3. **Threads**: Para mejor performance en multi-core:
   ```ruby
   '-threads', '0',  # Auto-detecta número de threads
   ```

4. **Movflags**: Para mejor compatibilidad MP4:
   ```ruby
   '-movflags', '+faststart',  # Mueve metadata al inicio del archivo
   ```

---

## Resumen

**Problemas Principales de la Configuración Actual:**
1. ❌ Preset `veryfast` reduce calidad significativamente
2. ❌ No especifica codecs (puede usar codecs no optimizados)
3. ❌ No controla bitrate (archivos pueden ser muy grandes o pequeños)
4. ❌ Timeout muy corto (5 segundos)
5. ❌ No especifica formato de segmento explícitamente
6. ❌ No controla GOP size (importante para segmentación)

**Mejoras Recomendadas:**
1. ✅ Cambiar a `preset medium` o `fast`
2. ✅ Especificar codecs: `libx264` y `aac`
3. ✅ Agregar control de bitrate con CRF o bitrate fijo
4. ✅ Aumentar timeout a 10 segundos
5. ✅ Especificar `segment_format mp4`
6. ✅ Agregar control de GOP (`-g 60`)

La **Opción 1** es la recomendada para tu caso de uso.

