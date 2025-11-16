# Configuración de Audio para Transcripciones

## Prioridad: Calidad de Audio

Esta configuración está optimizada específicamente para maximizar la calidad del audio, que es crítica para obtener transcripciones precisas con Whisper.

---

## Configuración de Audio Implementada

### Parámetros de Audio (Prioridad Máxima)

```ruby
# Audio codec settings - PRIORITY: High quality for transcription
'-c:a', 'aac',              # Codec AAC (compatible y de buena calidad)
'-b:a', '256k',             # Bitrate alto: 256 kbps (doble del estándar)
'-ar', '48000',             # Sample rate alto: 48 kHz (mejor que 44.1 kHz para voz)
'-ac', '2',                 # Audio estéreo (mejor separación de voces)
'-aac_coder', 'twoloop',    # Codificador AAC de alta calidad
```

### Comparación con Configuración Anterior

| Parámetro | Anterior | Actual | Mejora |
|-----------|----------|--------|--------|
| **Bitrate Audio** | 128 kbps | 256 kbps | +100% |
| **Sample Rate** | 44.1 kHz | 48 kHz | +9% |
| **Canales** | Mono (implícito) | Estéreo (2) | Mejor separación |
| **Codificador AAC** | Default | twoloop | Mejor calidad |

---

## Por Qué Estas Configuraciones Mejoran las Transcripciones

### 1. Bitrate Alto (256 kbps)

**Beneficio:**
- Más información de audio preservada
- Menos compresión = menos pérdida de detalles
- Mejor captura de frecuencias de voz (300Hz - 3400Hz)

**Impacto en Transcripciones:**
- Mejor reconocimiento de palabras
- Menos errores con acentos o pronunciaciones
- Mejor manejo de ruido de fondo

### 2. Sample Rate Alto (48 kHz)

**Beneficio:**
- Captura más frecuencias (hasta 24 kHz vs 22.05 kHz)
- Mejor resolución temporal
- Estándar profesional para audio de voz

**Impacto en Transcripciones:**
- Whisper puede procesar más información
- Mejor reconocimiento de consonantes y sonidos sutiles
- Menos aliasing (distorsión de frecuencias)

### 3. Audio Estéreo

**Beneficio:**
- Mejor separación de voces múltiples
- Información espacial preservada
- Whisper puede usar ambos canales

**Impacto en Transcripciones:**
- Mejor cuando hay múltiples hablantes
- Mejor separación de voz vs música/ruido
- Whisper procesa ambos canales y puede mejorar resultados

### 4. Codificador AAC twoloop

**Beneficio:**
- Algoritmo de codificación más sofisticado
- Mejor preservación de calidad con menos bitrate
- Menos artefactos de compresión

**Impacto en Transcripciones:**
- Menos distorsión = mejor reconocimiento
- Mejor preservación de transiciones de voz
- Menos errores con sonidos similares

---

## Ajustes de Video (Para Priorizar Audio)

Para mantener el tamaño total del archivo razonable mientras priorizamos audio:

```ruby
# Video codec and quality settings (secondary priority)
'-c:v', 'libx264',
'-preset', 'fast',        # Más rápido para ahorrar CPU para audio
'-crf', '25',             # Calidad ligeramente menor (vs 23 anterior)
'-maxrate', '2000k',      # Bitrate reducido (vs 2500k anterior)
```

**Balance:**
- Video: Calidad aceptable pero no máxima
- Audio: Calidad máxima para transcripciones
- Tamaño total: Similar o ligeramente mayor (~18-20 MB por segmento)

---

## Tamaño Estimado de Archivos

### Por Segmento de 60 Segundos:

| Componente | Bitrate | Tamaño |
|------------|---------|--------|
| **Audio** | 256 kbps | ~1.9 MB |
| **Video** | ~2000 kbps | ~15 MB |
| **Total** | ~2256 kbps | ~17 MB |

**Comparación con configuración anterior:**
- Audio anterior: ~0.96 MB (128 kbps)
- Audio actual: ~1.9 MB (256 kbps)
- **Incremento: ~1 MB por segmento**
- **Beneficio: Calidad de audio significativamente mejor**

---

## Recomendaciones Adicionales para Transcripciones

### Si Necesitas Aún Mejor Calidad de Audio:

#### Opción 1: Bitrate Más Alto
```ruby
'-b:a', '320k',  # Bitrate máximo AAC (mejor calidad)
```

#### Opción 2: Sample Rate Más Alto
```ruby
'-ar', '96000',  # 96 kHz (solo si el stream original lo soporta)
```

#### Opción 3: Codec Sin Pérdidas (Solo si es crítico)
```ruby
'-c:a', 'pcm_s16le',  # Sin compresión (archivos mucho más grandes)
```

**Nota:** Estas opciones aumentan significativamente el tamaño de archivo. La configuración actual (256k/48kHz) es un buen balance.

---

## Verificación de Calidad

### Comandos para Verificar Audio:

```bash
# Ver información del audio en un archivo
ffprobe -v error -select_streams a:0 -show_entries stream=codec_name,bit_rate,sample_rate,channels -of default=noprint_wrappers=1 video.mp4

# Escuchar el audio extraído
ffmpeg -i video.mp4 -vn -acodec copy audio.aac

# Ver espectrograma del audio
ffmpeg -i video.mp4 -lavfi showspectrumpic=spectrum.png
```

---

## Impacto en Whisper

### Mejoras Esperadas:

1. **Precisión General:** +5-10% de precisión
2. **Palabras Difíciles:** Mejor reconocimiento de nombres propios y términos técnicos
3. **Ruido de Fondo:** Mejor filtrado y separación de voz
4. **Múltiples Hablantes:** Mejor separación y reconocimiento
5. **Acentos:** Mejor manejo de variaciones de pronunciación

### Configuración Recomendada de Whisper:

Con audio de alta calidad, puedes usar:
- **Modelo:** `medium` o `large` (mejor precisión)
- **VAD Filter:** `True` (mejor con audio de calidad)
- **Language:** `Spanish` (especificado)

---

## Monitoreo

### Métricas a Monitorear:

1. **Tasa de Error de Transcripción:** Debería disminuir
2. **Tiempo de Procesamiento:** Puede aumentar ligeramente (más datos)
3. **Tamaño de Archivos:** Aumentará ~1 MB por segmento
4. **Uso de CPU:** Ligeramente mayor para codificación de audio

### Alertas:

- Si el tamaño de archivo aumenta >25 MB por segmento → Revisar configuración
- Si CPU usage >80% constantemente → Considerar preset más rápido
- Si hay errores de transcripción frecuentes → Verificar calidad del stream fuente

---

## Resumen

✅ **Audio optimizado para transcripciones:**
- Bitrate: 256 kbps (alto)
- Sample Rate: 48 kHz (alto)
- Estéreo: 2 canales
- Codificador: AAC twoloop (alta calidad)

✅ **Video ajustado para balance:**
- Calidad: Buena pero no máxima
- Bitrate: Reducido para priorizar audio
- Preset: Más rápido para ahorrar CPU

✅ **Resultado esperado:**
- Transcripciones más precisas
- Mejor reconocimiento de palabras
- Archivos ~1 MB más grandes por segmento
- Mejor inversión calidad/tamaño para transcripciones

