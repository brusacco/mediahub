import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="datatable"
export default class extends Controller {
  static values = {
    language: { type: String, default: "/datatables_locales/es-ES.json" },
    pageLength: { type: Number, default: 25 },
    orderColumn: { type: Number, default: 0 },
    orderDirection: { type: String, default: "desc" },
    lengthChange: { type: Boolean, default: true },
    lengthMenu: { type: String, default: "[[10, 25, 50, 100, -1], [10, 25, 50, 100, 'Todos']]" }
  }

  connect() {
    // Wait a bit for DataTable library to be available (it's loaded via content_for)
    this.initializeDataTable()
  }

  initializeDataTable() {
    // Check if DataTable is available
    if (typeof DataTable === 'undefined') {
      // Retry after a short delay if library hasn't loaded yet
      setTimeout(() => this.initializeDataTable(), 100)
      return
    }

    // Find the table element
    const table = this.element.querySelector('table')
    if (!table) {
      return
    }

    // Only initialize if not already initialized
    if (table.dataset.datatableInitialized === 'true') {
      return
    }

    table.dataset.datatableInitialized = 'true'

    // Parse lengthMenu if provided as string
    let lengthMenu = [[10, 25, 50, 100, -1], [10, 25, 50, 100, "Todos"]]
    if (this.lengthMenuValue && this.lengthMenuValue !== "[[10, 25, 50, 100, -1], [10, 25, 50, 100, 'Todos']]") {
      try {
        lengthMenu = JSON.parse(this.lengthMenuValue)
      } catch (e) {
        console.warn('Invalid lengthMenu format, using default')
      }
    }

    // Initialize DataTable with Morfeo-style configuration
    try {
      this.dataTable = new DataTable(table, {
        order: [[this.orderColumnValue, this.orderDirectionValue]],
        pageLength: this.pageLengthValue,
        lengthChange: this.lengthChangeValue,
        lengthMenu: lengthMenu,
        responsive: true,
        processing: true,
        dom: '<"flex flex-col sm:flex-row sm:items-center sm:justify-between mb-4"lf>rt<"flex flex-col sm:flex-row sm:items-center sm:justify-between mt-4"ip>',
        language: {
          url: this.languageValue,
          search: 'Buscar:',
          lengthMenu: 'Mostrar _MENU_ entradas',
          info: 'Mostrando _START_ a _END_ de _TOTAL_ entradas',
          infoEmpty: 'Mostrando 0 a 0 de 0 entradas',
          infoFiltered: '(filtrado de _MAX_ entradas totales)',
          paginate: {
            first: 'Primero',
            last: 'Último',
            next: 'Siguiente',
            previous: 'Anterior'
          },
          emptyTable: 'No hay datos disponibles en la tabla',
          loadingRecords: 'Cargando...',
          processing: 'Procesando...',
          zeroRecords: 'No se encontraron registros coincidentes'
        },
        initComplete: () => {
          this.styleControls()
          this.stylePagination()
        },
        drawCallback: () => {
          // Style pagination buttons after each draw
          this.stylePagination()
        }
      })
    } catch (error) {
      console.error('Error initializing DataTable:', error)
    }
  }

  styleControls() {
    // Style form controls (search input and length select)
    const searchInput = this.element.querySelector('.dataTables_filter input')
    const lengthSelect = this.element.querySelector('.dataTables_length select')
    
    const inputStyles = {
      display: 'block',
      borderRadius: '0.375rem',
      border: '1px solid #d1d5db',
      boxShadow: '0 1px 2px 0 rgba(0, 0, 0, 0.05)',
      padding: '0.5rem 0.75rem',
      fontSize: '0.875rem',
      lineHeight: '1.25rem',
      width: '100%',
      maxWidth: '300px'
    }

    if (searchInput) {
      Object.assign(searchInput.style, inputStyles)
      searchInput.setAttribute('placeholder', 'Buscar en todas las columnas...')
      
      // Focus styles
      searchInput.addEventListener('focus', () => {
        searchInput.style.borderColor = '#4f46e5'
        searchInput.style.boxShadow = '0 0 0 3px rgba(79, 70, 229, 0.1)'
      })
      
      searchInput.addEventListener('blur', () => {
        searchInput.style.borderColor = '#d1d5db'
        searchInput.style.boxShadow = '0 1px 2px 0 rgba(0, 0, 0, 0.05)'
      })
    }

    if (lengthSelect) {
      Object.assign(lengthSelect.style, inputStyles)
      lengthSelect.style.maxWidth = '150px'
    }

    // Style containers
    const lengthContainer = this.element.querySelector('.dataTables_length')
    const filterContainer = this.element.querySelector('.dataTables_filter')

    if (lengthContainer) {
      lengthContainer.style.display = 'flex'
      lengthContainer.style.alignItems = 'center'
      lengthContainer.style.gap = '0.5rem'
      lengthContainer.style.marginBottom = '1rem'
    }

    if (filterContainer) {
      filterContainer.style.display = 'flex'
      filterContainer.style.alignItems = 'center'
      filterContainer.style.gap = '0.5rem'
      filterContainer.style.marginBottom = '1rem'
      filterContainer.style.justifyContent = 'flex-end'
    }

    // Style labels
    const labels = this.element.querySelectorAll('.dataTables_length label, .dataTables_filter label')
    labels.forEach(label => {
      label.style.display = 'flex'
      label.style.alignItems = 'center'
      label.style.gap = '0.5rem'
      label.style.fontSize = '0.875rem'
      label.style.fontWeight = '500'
      label.style.color = '#374151'
      label.style.margin = '0'
    })
  }

  stylePagination() {
    // Wait for pagination to be rendered
    setTimeout(() => {
      const paginateContainer = this.element.querySelector('.dataTables_paginate')
      if (!paginateContainer) return

      // Style pagination container
      paginateContainer.style.display = 'flex'
      paginateContainer.style.justifyContent = 'flex-end'
      paginateContainer.style.marginTop = '1rem'

      // Create pagination wrapper if it doesn't exist
      if (!paginateContainer.querySelector('.pagination')) {
        const pagination = document.createElement('div')
        pagination.className = 'pagination inline-flex shadow-sm'
        while (paginateContainer.firstChild) {
          pagination.appendChild(paginateContainer.firstChild)
        }
        paginateContainer.appendChild(pagination)
      }

      // Style pagination buttons
      const buttons = paginateContainer.querySelectorAll('.paginate_button')
      buttons.forEach((button, index) => {
        const isFirst = index === 0
        const isLast = index === buttons.length - 1
        const isCurrent = button.classList.contains('current')
        const isDisabled = button.classList.contains('disabled')

        // Base styles for all buttons
        button.style.position = 'relative'
        button.style.display = 'inline-flex'
        button.style.alignItems = 'center'
        button.style.padding = '0.5rem 0.75rem'
        button.style.fontSize = '0.875rem'
        button.style.fontWeight = '500'
        button.style.border = '1px solid'
        button.style.textDecoration = 'none'
        button.style.transition = 'all 0.15s ease-in-out'
        button.style.marginLeft = isFirst ? '0' : '-1px'

        // State-specific styles
        if (isCurrent) {
          button.style.zIndex = '10'
          button.style.backgroundColor = '#4f46e5'
          button.style.borderColor = '#4f46e5'
          button.style.color = '#ffffff'
        } else if (isDisabled) {
          button.style.color = '#d1d5db'
          button.style.backgroundColor = '#f9fafb'
          button.style.borderColor = '#d1d5db'
          button.style.cursor = 'not-allowed'
        } else {
          button.style.color = '#6b7280'
          button.style.backgroundColor = '#ffffff'
          button.style.borderColor = '#d1d5db'
          button.style.cursor = 'pointer'

          // Hover effects
          button.addEventListener('mouseenter', () => {
            button.style.backgroundColor = '#f9fafb'
            button.style.color = '#374151'
            button.style.borderColor = '#9ca3af'
          })

          button.addEventListener('mouseleave', () => {
            button.style.backgroundColor = '#ffffff'
            button.style.color = '#6b7280'
            button.style.borderColor = '#d1d5db'
          })
        }

        // Border radius for first and last buttons
        if (isFirst) {
          button.style.borderTopLeftRadius = '0.375rem'
          button.style.borderBottomLeftRadius = '0.375rem'
        }
        if (isLast) {
          button.style.borderTopRightRadius = '0.375rem'
          button.style.borderBottomRightRadius = '0.375rem'
        }
      })

      // Style info text
      const infoElement = this.element.querySelector('.dataTables_info')
      if (infoElement) {
        infoElement.style.color = '#374151'
        infoElement.style.fontSize = '0.875rem'
        infoElement.style.marginTop = '0.5rem'
      }
    }, 100)
  }

  disconnect() {
    // Destroy DataTable instance when element is removed
    if (this.dataTable) {
      try {
        this.dataTable.destroy()
      } catch (error) {
        // Ignore errors during destruction
      }
      this.dataTable = null
    }
  }
}

