# 🎨 Prompt para ChatGPT/Copilot - Generar HTML + TailwindCSS

## 🧠 Rol: Diseñador UI/UX Senior y Diseñador Gráfico Senior

## 🎯 Objetivo
Crear un diseño web moderno, limpio, funcional y profesional, siguiendo las mejores prácticas de TailwindCSS y teoría del diseño gráfico.

---

## 📋 Instrucción Principal

Generá el **HTML completo con TailwindCSS** para una interfaz web siguiendo las guías de diseño que se detallan abajo.

El resultado debe ser **listo para producción**, totalmente **responsivo**, con una **estética internacional** (Apple / Linear / Vercel style).

Cada sección debe funcionar como una **"diapositiva" clara**, visualmente independiente y comunicativa.

---

## 🧱 1. Estructura Visual y Composición

- Mantener una **jerarquía visual clara**: títulos, subtítulos, párrafos y CTAs bien definidos.
- Usar **grillas (`grid`, `flex`, `gap-`, `p-`, `m-`)** y **espacio negativo** para balance visual.
- Diseñar **secciones tipo "slides"** con proporciones armónicas, visualmente limpias.
- Garantizar **layout responsivo** (`sm:`, `md:`, `lg:`, `xl:`, `2xl:`) sin perder elegancia.
- Usar **contenedores con max-width** (`max-w-7xl mx-auto`) para contenido centrado.

---

## 🧠 2. Teoría del Color y Armonía Visual

- Aplicar armonías **complementarias o monocromáticas**.
- Transmitir **confianza, claridad y profesionalismo**.
- Usar fondos neutros (`bg-slate-50`, `bg-gray-50`, `bg-white`) con acentos suaves (`text-indigo-600`, `accent-indigo-500`, `border-gray-200`).
- Transiciones suaves en hover (`transition-all duration-300 ease-in-out`).
- **Paleta sugerida**:
  - Primario: `indigo-600` / `indigo-700` (confianza, profesionalismo)
  - Secundario: `slate-600` / `slate-700` (neutralidad, elegancia)
  - Acentos: `blue-500` / `emerald-500` (acción, éxito)
  - Fondos: `white`, `slate-50`, `gray-50` (limpieza)
  - Texto: `gray-900`, `slate-800` (legibilidad)

---

## 🔠 3. Tipografía y Legibilidad

- Usar fuentes modernas: **Inter** (ya cargada en el proyecto).
- Escala tipográfica coherente:
  - `text-xs` (12px) - Labels, badges
  - `text-sm` (14px) - Texto secundario
  - `text-base` (16px) - Texto cuerpo
  - `text-lg` (18px) - Subtítulos
  - `text-xl` (20px) - Títulos sección
  - `text-2xl` (24px) - Títulos principales
  - `text-3xl` (30px) - Hero titles
  - `text-4xl` (36px) - Display titles
- Espaciado óptico (`leading-relaxed`, `leading-tight`, `tracking-tight`).
- Contraste suficiente (`text-gray-900` sobre `bg-white`).
- Pesos tipográficos para jerarquía: `font-light`, `font-normal`, `font-medium`, `font-semibold`, `font-bold`.

---

## 🧩 4. Componentes UI y Experiencia de Usuario

- Componentes consistentes: **botones, tarjetas, formularios, menús, hero sections**.
- Navegación clara e intuitiva, sin ruido visual.
- Estados visibles (`hover:`, `focus:`, `active:`) y semántica correcta.
- Look & feel **premium y corporativo**, tipo SaaS moderno.
- **Botones modernos**:
  - Primario: `bg-indigo-600 hover:bg-indigo-700 text-white px-6 py-3 rounded-lg font-medium transition-all duration-200 shadow-sm hover:shadow-md`
  - Secundario: `bg-white hover:bg-gray-50 text-gray-700 border border-gray-300 px-6 py-3 rounded-lg font-medium transition-all duration-200`
  - Ghost: `text-indigo-600 hover:text-indigo-700 hover:bg-indigo-50 px-4 py-2 rounded-md font-medium transition-all duration-200`
- **Cards modernas**:
  - `bg-white rounded-xl shadow-sm hover:shadow-md transition-all duration-300 border border-gray-100 p-6`
- **Inputs modernos**:
  - `w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 transition-all duration-200`

---

## ⚙️ 5. Código Limpio con TailwindCSS

- Clases organizadas y sin redundancia.
- Enfocar en **minimalismo funcional ("less but better")**.
- Componentización sugerida (usar partials de Rails cuando aplique).
- Cumplir con **accesibilidad (WCAG)**:
  - Contraste mínimo 4.5:1 para texto normal
  - Contraste mínimo 3:1 para texto grande
  - Focus visible en elementos interactivos
  - Labels asociados a inputs
  - ARIA labels cuando sea necesario

---

## 🌎 6. Estándar Visual Global

Inspirarse en:

- **Apple Design Language**: Espaciado generoso, tipografía clara, minimalismo
- **Google Material 3**: Elevación sutil, transiciones suaves
- **TailwindUI**: Componentes bien diseñados, consistencia
- **Linear.app**: Elegancia, funcionalidad, detalles cuidados
- **Notion / Vercel aesthetics**: Limpieza, profesionalismo, modernidad

---

## 🎯 Objetivo Final

- Diseño **moderno, corporativo y elegante**, combinando **claridad + funcionalidad**.
- Cada sección debe sentirse como una **slide ejecutiva** con identidad visual propia.
- El resultado debe ser **HTML + TailwindCSS listo para producción**, con código limpio y comentarios breves explicando cada bloque.

---

## 🧾 Entrega Esperada

1. **HTML estructurado** por secciones con clases Tailwind.
2. **Paleta de colores** documentada en comentarios.
3. **Layout responsivo** y validado visualmente.
4. **Diseño accesible**, con tipografía y contraste correctos.
5. **Código limpio** con comentarios explicativos breves.

---

## 📐 Especificaciones Técnicas para MediaHub

### Contexto del Proyecto
- **Framework**: Rails 7.1 con ERB templates
- **CSS**: TailwindCSS v3.4.1
- **Fuente**: Inter (ya cargada)
- **JavaScript**: Turbo/Stimulus (mantener compatibilidad)

### Componentes Existentes a Considerar

1. **Gráficos Chartkick**: Mantener compatibilidad con:
   - `column_chart`, `pie_chart`, `bar_chart`, `line_chart`
   - Wrapper: `<div class="overflow-hidden bg-white shadow-sm rounded-xl p-6">`

2. **Nube de palabras**: CSS custom `.cloud` - mantener funcionalidad

3. **Font Awesome**: Iconos usados (`fa-regular`, `fa-solid`) - mantener

4. **Rails Helpers**: 
   - `number_with_delimiter` - formateo de números
   - `highlight` - resaltado de texto
   - `link_to` - enlaces con Turbo

### Estructura de Secciones Tipo "Slide"

Cada sección debe tener:

```html
<!-- Sección: [Nombre descriptivo] -->
<section class="py-16 lg:py-24 bg-white">
  <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
    <!-- Header de sección -->
    <div class="text-center mb-12">
      <h2 class="text-3xl font-bold tracking-tight text-gray-900 sm:text-4xl">
        Título Principal
      </h2>
      <p class="mt-4 text-lg text-gray-600 max-w-2xl mx-auto">
        Descripción opcional de la sección
      </p>
    </div>
    
    <!-- Contenido de la sección -->
    <div class="...">
      <!-- Contenido aquí -->
    </div>
  </div>
</section>
```

### Espaciado Consistente

- **Entre secciones**: `py-16 lg:py-24` (64px / 96px)
- **Padding interno**: `px-4 sm:px-6 lg:px-8` (16px / 24px / 32px)
- **Gap en grids**: `gap-6 lg:gap-8` (24px / 32px)
- **Margin entre elementos**: `mb-6`, `mb-8`, `mb-12` según jerarquía

### Sombras y Elevación

- **Cards básicas**: `shadow-sm`
- **Cards hover**: `shadow-sm hover:shadow-md transition-shadow duration-300`
- **Cards destacadas**: `shadow-md`
- **Modales/Overlays**: `shadow-xl` o `shadow-2xl`

### Bordes y Radios

- **Botones**: `rounded-lg` (8px) o `rounded-xl` (12px)
- **Cards**: `rounded-xl` (12px)
- **Inputs**: `rounded-lg` (8px)
- **Badges/Pills**: `rounded-full` o `rounded-md`

---

## 🎨 Ejemplos de Componentes Modernos

### Hero Section
```html
<section class="relative bg-gradient-to-br from-indigo-50 via-white to-slate-50 py-24 lg:py-32">
  <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
    <div class="text-center">
      <h1 class="text-4xl font-bold tracking-tight text-gray-900 sm:text-5xl lg:text-6xl">
        Título Principal
      </h1>
      <p class="mt-6 text-xl text-gray-600 max-w-3xl mx-auto">
        Descripción del hero con texto más grande y espaciado generoso
      </p>
    </div>
  </div>
</section>
```

### Card Moderna
```html
<div class="bg-white rounded-xl shadow-sm hover:shadow-md transition-all duration-300 border border-gray-100 p-6 lg:p-8">
  <h3 class="text-xl font-semibold text-gray-900 mb-4">
    Título de Card
  </h3>
  <p class="text-gray-600 leading-relaxed">
    Contenido de la card con espaciado adecuado y tipografía legible.
  </p>
</div>
```

### Botón Moderno
```html
<button class="inline-flex items-center px-6 py-3 border border-transparent text-base font-medium rounded-lg text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 transition-all duration-200 shadow-sm hover:shadow-md">
  Texto del Botón
</button>
```

---

## ✅ Checklist de Calidad

Antes de entregar, verificar:

- [ ] Responsive en todos los breakpoints (sm, md, lg, xl, 2xl)
- [ ] Jerarquía visual clara (títulos, subtítulos, cuerpo)
- [ ] Espaciado consistente y generoso
- [ ] Paleta de colores coherente
- [ ] Estados hover/focus implementados
- [ ] Transiciones suaves en interacciones
- [ ] Contraste de texto adecuado (WCAG)
- [ ] Código limpio y comentado
- [ ] Compatibilidad con Chartkick mantenida
- [ ] Compatibilidad con Font Awesome mantenida

---

## 🚀 Uso del Prompt

1. **Copiar este prompt completo** en ChatGPT/Copilot
2. **Especificar la vista/sección** que querés rediseñar (ej: "Dashboard principal", "Vista de detalle de video", etc.)
3. **Incluir contexto adicional** si es necesario (datos que se muestran, funcionalidades específicas)
4. **Revisar el resultado** y ajustar según necesidades
5. **Integrar en el proyecto** Rails reemplazando las vistas actuales

---

**¿Listo para generar diseños modernos y profesionales? 🎨✨**

