# Extracción de Texto OCR de Videos

## Descripción

Este sistema permite extraer texto de las imágenes generadas de los videos usando OCR (Optical Character Recognition). Está especialmente optimizado para extraer texto de los **zócalos de noticias** (lower thirds), donde se presenta información importante como títulos, nombres de personas, lugares, etc.

## Tecnología

- **Tesseract OCR**: Motor de OCR open source utilizado a través de la gema `rtesseract`
- **MiniMagick**: Para procesamiento y mejora de imágenes antes del OCR
- **Idiomas soportados**: Español y Inglés (`spa+eng`)

## Características

### Extracción Automática

- La extracción OCR se ejecuta automáticamente cuando se genera un thumbnail de video
- Se enfoca en la parte inferior de la imagen (últimos 30%) donde típicamente aparecen los zócalos
- Utiliza el thumbnail grande (`-big.png`) cuando está disponible para mejor calidad de OCR

### Procesamiento de Imágenes

El servicio aplica las siguientes mejoras a las imágenes antes del OCR:

1. **Conversión a escala de grises**: Mejora el contraste
2. **Aumento de brillo**: 120% para mejorar legibilidad
3. **Aumento de contraste**: Para destacar texto
4. **Enfoque ligero**: Para mejorar la definición del texto

### Limpieza de Texto

El texto extraído se limpia automáticamente:

- Eliminación de espacios excesivos
- Eliminación de artefactos comunes de OCR
- Filtrado de "palabras" muy cortas que probablemente son errores de OCR

## Instalación

### Requisitos del Sistema

1. **Tesseract OCR** debe estar instalado en el sistema:

```bash
# macOS
brew install tesseract tesseract-lang

# Ubuntu/Debian
sudo apt-get install tesseract-ocr tesseract-ocr-spa tesseract-ocr-eng

# CentOS/RHEL
sudo yum install tesseract tesseract-langpack-spa tesseract-langpack-eng
```

2. **Instalar gemas de Ruby**:

```bash
bundle install
```

Esto instalará:
- `rtesseract` (~> 3.1): Wrapper de Ruby para Tesseract OCR
- `mini_magick` (~> 4.12): Procesamiento de imágenes

### Migración de Base de Datos

Ejecutar la migración para agregar el campo `ocr_text`:

```bash
rails db:migrate
```

## Uso

### Extracción Automática

La extracción OCR se ejecuta automáticamente cuando:

1. Se importa un nuevo video (`VideoImportService`)
2. Se genera un thumbnail (`Video#generate_thumbnail`)

### Extracción Manual

#### Extraer OCR de un video específico:

```ruby
video = Video.find(123)
video.extract_ocr_text
```

#### Extraer OCR de todos los videos sin OCR:

```bash
rake ocr:extract_all
```

#### Extraer OCR de videos en un rango de fechas:

```bash
rake ocr:extract_range[2024-01-01,2024-01-31]
```

#### Re-extraer OCR de todos los videos:

```bash
rake ocr:re_extract_all
```

### Uso Programático

```ruby
# Extraer texto de una imagen específica
result = OcrExtractionService.call('/path/to/image.png', lower_third_only: true)

if result.success?
  puts "Texto extraído: #{result.data}"
else
  puts "Error: #{result.error}"
end

# Extraer texto de toda la imagen (no solo zócalos)
result = OcrExtractionService.call('/path/to/image.png', lower_third_only: false)

# Especificar idioma diferente
result = OcrExtractionService.call('/path/to/image.png', language: 'eng')
```

## Modelo de Datos

### Campo `ocr_text` en Videos

- **Tipo**: `text`
- **Descripción**: Almacena el texto extraído de la imagen del video
- **Contenido**: Texto limpio extraído principalmente de zócalos/lower thirds

### Scopes Disponibles

```ruby
# Videos sin texto OCR
Video.no_ocr_text

# Videos con texto OCR
Video.has_ocr_text
```

## Integración con el Sistema

### Flujo de Procesamiento

1. **Grabación de video** → Video guardado en `temp/`
2. **Importación** (`VideoImportService`) → Video movido a directorio organizado
3. **Generación de thumbnail** → Se crea imagen PNG del video
4. **Extracción OCR** → Se extrae texto automáticamente de la imagen
5. **Almacenamiento** → Texto guardado en campo `ocr_text`

### Uso con Tags y Topics

El texto OCR puede ser utilizado para:

- **Búsqueda mejorada**: Buscar videos por texto visible en pantalla
- **Tagging automático**: Extraer palabras clave de los zócalos
- **Análisis de contenido**: Identificar temas y personas mencionadas

## Optimización para Zócalos

El sistema está optimizado específicamente para extraer texto de zócalos de noticias:

1. **Región de extracción**: Solo procesa el 30% inferior de la imagen
2. **Mejora de calidad**: Aplica filtros específicos para texto sobre video
3. **Idiomas**: Configurado para español e inglés (idiomas comunes en noticias)

### Ajustar Región de Extracción

Para cambiar la región de extracción, editar `OcrExtractionService::LOWER_THIRD_REGION`:

```ruby
# Extraer del 25% inferior
LOWER_THIRD_REGION = { y_offset: 0.75, height: 0.25 }.freeze

# Extraer del 40% inferior
LOWER_THIRD_REGION = { y_offset: 0.60, height: 0.40 }.freeze
```

## Rendimiento

### Consideraciones

- **Procesamiento**: El OCR puede ser lento para grandes volúmenes de videos
- **Recursos**: Requiere memoria adicional para procesamiento de imágenes
- **Recomendación**: Procesar en lotes usando los rake tasks proporcionados

### Procesamiento en Lotes

Los rake tasks están optimizados para procesar videos en lotes usando `find_each`:

```ruby
Video.no_ocr_text.find_each do |video|
  video.extract_ocr_text
end
```

## Troubleshooting

### Tesseract no encontrado

**Error**: `Tesseract not found`

**Solución**: Instalar Tesseract OCR en el sistema (ver sección de instalación)

### Calidad de OCR baja

**Problema**: Texto extraído con muchos errores

**Soluciones**:
1. Verificar que el thumbnail grande (`-big.png`) existe y se está usando
2. Ajustar parámetros de mejora de imagen en `OcrExtractionService`
3. Verificar calidad del video fuente

### No se extrae texto

**Problema**: `ocr_text` queda vacío

**Posibles causas**:
1. El thumbnail no contiene texto visible
2. El texto está en una región diferente (no en zócalos)
3. Calidad de imagen muy baja

**Solución**: Intentar extraer de toda la imagen:

```ruby
result = OcrExtractionService.call(image_path, lower_third_only: false)
```

## Próximas Mejoras

Posibles mejoras futuras:

1. **Detección automática de región de texto**: Usar detección de objetos para encontrar zócalos
2. **Múltiples idiomas**: Soporte para más idiomas según configuración de estación
3. **Extracción de múltiples frames**: Analizar varios frames del video para mejor cobertura
4. **Integración con tagging**: Usar texto OCR para mejorar extracción de tags
5. **Búsqueda full-text**: Implementar búsqueda que incluya texto OCR

## Referencias

- [Tesseract OCR](https://github.com/tesseract-ocr/tesseract)
- [rtesseract Gem](https://github.com/dannnylo/rtesseract)
- [MiniMagick](https://github.com/minimagick/minimagick)

