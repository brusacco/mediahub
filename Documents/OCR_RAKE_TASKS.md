# OCR Rake Tasks - Reference Guide

Documentación de referencia para los rake tasks de extracción de texto OCR (Optical Character Recognition) de los thumbnails de videos en MediaHub.

## Tabla de Contenidos

1. [Tasks Disponibles](#tasks-disponibles)
2. [Requisitos del Sistema](#requisitos-del-sistema)
3. [Ejemplos de Uso](#ejemplos-de-uso)
4. [Troubleshooting](#troubleshooting)

---

## Tasks Disponibles

### `ocr:extract_all`

Extrae texto OCR de todos los videos que **no tienen texto OCR** aún.

**Uso:**

```bash
rake ocr:extract_all
```

**Características:**

- Solo procesa videos sin texto OCR (`Video.no_ocr_text`)
- Verifica automáticamente que ImageMagick y Tesseract estén instalados
- Muestra progreso detallado con estadísticas
- Usa el thumbnail grande (`-big.png`) cuando está disponible para mejor calidad
- Enfocado en extraer texto de zócalos (lower thirds) - parte inferior de la imagen

**Ejemplo de salida:**

```
Starting OCR extraction for videos without OCR text...

✅ ImageMagick: OK
✅ Tesseract: OK

Found 775 videos to process

[775/775] Video 312062: 📷 File OK (310593 bytes) | Big: ✅ | ✅ OCR: 45 chars

============================================================
OCR extraction completed!
============================================================
Total processed: 775
✅ Successfully extracted: 650
⚠️  No text found: 100
❌ Files not found: 0
❌ Errors: 25
```

**Cuándo usar:**

- Primera vez que ejecutas OCR en el sistema
- Después de agregar nuevos videos
- Para procesar videos que fallaron anteriormente

---

### `ocr:re_extract_all`

Re-extrae texto OCR de **todos los videos** con thumbnails, incluso si ya tienen texto OCR.

**Uso:**

```bash
rake ocr:re_extract_all
```

**Características:**

- Procesa TODOS los videos con thumbnails (`Video.where.not(thumbnail_path: nil)`)
- Sobrescribe el texto OCR existente
- Útil para re-procesar con mejoras en el algoritmo de OCR
- Útil para corregir errores en extracciones anteriores

**Ejemplo de salida:**

```
Re-extracting OCR text from all videos with thumbnails...

Processing 1200/1200 videos... (1150 success, 50 errors)

OCR re-extraction completed!
Total processed: 1200
Successfully extracted: 1150
Errors: 50
```

**Cuándo usar:**

- Después de mejorar el algoritmo de procesamiento de imágenes
- Después de actualizar Tesseract o ImageMagick
- Para corregir errores en extracciones anteriores
- Cuando cambias la configuración de OCR (idioma, región, etc.)

---

### `ocr:extract_range[start_date,end_date]`

Extrae texto OCR de videos en un rango de fechas específico.

**Uso:**

```bash
# Formato: rake ocr:extract_range[start_date,end_date]
rake ocr:extract_range[2024-01-01,2024-01-31]
```

**Parámetros:**

- `start_date`: Fecha de inicio (formato: YYYY-MM-DD)
- `end_date`: Fecha de fin (formato: YYYY-MM-DD)

**Características:**

- Procesa videos entre las fechas especificadas (inclusive)
- Útil para procesar videos de un período específico
- No verifica si ya tienen OCR (procesa todos en el rango)

**Ejemplos:**

```bash
# Procesar videos de enero 2024
rake ocr:extract_range[2024-01-01,2024-01-31]

# Procesar videos de una semana específica
rake ocr:extract_range[2024-12-01,2024-12-07]

# Procesar videos de un día específico
rake ocr:extract_range[2024-12-25,2024-12-25]
```

**Cuándo usar:**

- Para procesar videos de un período específico
- Para re-procesar videos después de un evento importante
- Para procesar videos de forma incremental por fechas

---

## Requisitos del Sistema

### ImageMagick

**Instalación:**

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install imagemagick

# CentOS/RHEL
sudo yum install ImageMagick

# macOS
brew install imagemagick
```

**Verificación:**

```bash
which convert
convert --version
```

### Tesseract OCR

**Instalación:**

```bash
# Ubuntu/Debian
sudo apt-get install tesseract-ocr tesseract-ocr-spa

# CentOS/RHEL
sudo yum install tesseract tesseract-langpack-spa

# macOS
brew install tesseract tesseract-lang
```

**Verificación:**

```bash
which tesseract
tesseract --version
tesseract --list-langs  # Debe incluir 'spa' y 'eng'
```

### Gemas Ruby

Las siguientes gemas deben estar instaladas (ya están en el Gemfile):

- `rtesseract` (~> 3.1)
- `mini_magick` (~> 4.12)

**Instalación:**

```bash
bundle install
```

---

## Ejemplos de Uso

### Setup Inicial

```bash
# 1. Verificar requisitos
which convert
which tesseract
tesseract --list-langs

# 2. Instalar gemas si es necesario
bundle install

# 3. Ejecutar migración (si no se ha hecho)
rails db:migrate

# 4. Extraer OCR de videos sin texto
rake ocr:extract_all
```

### Procesamiento Incremental

```bash
# Procesar solo videos nuevos (sin OCR)
rake ocr:extract_all

# Re-procesar todos los videos con mejoras
rake ocr:re_extract_all
```

### Procesamiento por Períodos

```bash
# Procesar videos de un mes específico
rake ocr:extract_range[2024-01-01,2024-01-31]

# Procesar videos de la última semana
rake ocr:extract_range[2024-12-01,2024-12-07]
```

### Verificar Resultados

```bash
# En rails console
rails console

# Contar videos con OCR
Video.has_ocr_text.count

# Ver una muestra del texto extraído
Video.has_ocr_text.first.ocr_text

# Buscar videos con texto específico
Video.where("ocr_text LIKE ?", "%noticia%")

# Ver videos sin OCR
Video.no_ocr_text.count
```

---

## Troubleshooting

### Error: "ImageMagick is not installed"

**Síntoma:**

```
❌ ERROR: ImageMagick is not installed!
```

**Solución:**

```bash
sudo apt-get install imagemagick
# o
sudo yum install ImageMagick
```

### Error: "Tesseract OCR is not installed"

**Síntoma:**

```
❌ ERROR: Tesseract OCR is not installed!
```

**Solución:**

```bash
sudo apt-get install tesseract-ocr tesseract-ocr-spa
# o
sudo yum install tesseract tesseract-langpack-spa
```

### No se extrae texto (0 success)

**Posibles causas:**

1. **ImageMagick no instalado** - Verificar con `which convert`
2. **Tesseract no instalado** - Verificar con `which tesseract`
3. **Idioma español no instalado** - Verificar con `tesseract --list-langs`
4. **Thumbnails no tienen texto visible** - Normal si los videos no tienen zócalos
5. **Thumbnails muy pequeños o de baja calidad** - El sistema intenta mejorar la calidad automáticamente

**Diagnóstico:**

```bash
# Revisar logs
tail -100 log/production.log | grep -i ocr

# Probar manualmente con un video
rails console
video = Video.where.not(thumbnail_path: nil).first
video.extract_ocr_text
video.reload.ocr_text
```

### Calidad de texto extraído es pobre

**Mejoras implementadas:**

El sistema ahora incluye:
- Upscaling automático de imágenes pequeñas
- Normalización de contraste
- Thresholding adaptativo (conversión a blanco/negro)
- Sharpening avanzado (unsharp mask)
- Configuración optimizada de Tesseract (PSM mode 6/7)

**Si la calidad sigue siendo pobre:**

1. Verificar que se está usando el thumbnail grande (`-big.png`)
2. Revisar logs para ver qué técnicas se están aplicando
3. Considerar ajustar parámetros en `OcrExtractionService`

### Proceso muy lento

**Normal:**

- El OCR puede tomar 1-3 segundos por video
- Con 1000 videos, puede tomar 15-50 minutos

**Optimizaciones:**

- El sistema procesa en lotes usando `find_each`
- Usa thumbnails grandes cuando están disponibles
- Aplica técnicas de mejora de imagen optimizadas

### Ver todos los rake tasks de OCR

```bash
rake -T ocr
```

---

## Detalles Técnicos

### Región de Extracción

Por defecto, el sistema extrae texto de la **parte inferior** de la imagen (lower third), que es donde típicamente aparecen los zócalos en noticias:

- **Región**: Últimos 30% de la imagen (desde el 70% hacia abajo)
- **Configurable**: Ver `LOWER_THIRD_REGION` en `OcrExtractionService`

### Idioma

- **Idioma por defecto**: Español (`spa`)
- **Configurable**: Ver `DEFAULT_LANG` en `OcrExtractionService`

### Procesamiento de Imágenes

El sistema aplica las siguientes mejoras automáticamente:

1. Conversión a escala de grises
2. Upscaling (2x o 3x según tamaño original)
3. Normalización de contraste
4. Thresholding adaptativo (50%)
5. Unsharp mask para nitidez
6. Aumento de contraste adicional

### Configuración de Tesseract

- **PSM Mode 6**: Bloque uniforme de texto (default)
- **PSM Mode 7**: Línea única (fallback si Mode 6 no encuentra texto)
- **Whitelist**: Caracteres permitidos (incluye acentos españoles)

---

## Referencias

- Documentación completa de OCR: `Documents/OCR_TEXT_EXTRACTION.md`
- Documentación del sistema: `Documents/SYSTEM_DOCUMENTATION.md`
- Servicio OCR: `app/services/ocr_extraction_service.rb`
- Rake tasks: `lib/tasks/extract_ocr_text.rake`




