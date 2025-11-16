import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="chart-modal"
export default class extends Controller {
  static values = {
    id: String,
    url: String,
    tagId: Number,
    topicId: Number
  }

  connect() {
    // Wait for chart to be ready before setting up click events
    this.waitForChart()
  }

  waitForChart(attempts = 0, maxAttempts = 50) {
    const chart = Highcharts.charts.find(chart => chart && chart.renderTo && chart.renderTo.id === this.idValue)
    
    if (chart) {
      // Chart is ready, set up click events
      this.setupChartClickEvent()
      console.log(`Chart ${this.idValue} initialized with click handler`)
    } else if (attempts < maxAttempts) {
      // Chart not ready yet, try again in 100ms
      setTimeout(() => {
        this.waitForChart(attempts + 1, maxAttempts)
      }, 100)
    } else {
      console.warn(`Chart ${this.idValue} failed to initialize after ${maxAttempts} attempts`)
    }
  }

  setupChartClickEvent() {
    let chart = Highcharts.charts.find(chart => chart && chart.renderTo && chart.renderTo.id === this.idValue)
  
    if (chart) {
      let _this = this
  
      chart.update({
        plotOptions: {
          series: {
            point: {
              events: {
                click: function (event) {
                  let formattedDate = _this.parseDateFromCategory(event.point.category)
                  // Support both tags and topics
                  if (_this.tagIdValue) {
                    _this.loadVideos(_this.tagIdValue, formattedDate, 'tag')
                  } else if (_this.topicIdValue) {
                    _this.loadVideos(_this.topicIdValue, formattedDate, 'topic')
                  }
                }
              }
            }
          }
        }
      })
      
      console.log(`Click events attached to chart: ${this.idValue}`)
    }
  }

  parseDateFromCategory(category) {
    // Handle different date formats
    if (typeof category === 'string' && category.match(/^\d{1,2}\/\d{1,2}$/)) {
      // Format: "DD/MM" - need to add current year
      const [day, month] = category.split('/')
      const year = new Date().getFullYear()
      const date = new Date(year, parseInt(month) - 1, parseInt(day))
      return date.toISOString().split('T')[0]
    } else {
      // Try to parse as regular date
      const clickedDate = new Date(category)
      if (!isNaN(clickedDate.getTime())) {
        return clickedDate.toISOString().split('T')[0]
      }
      // Fallback to today if parsing fails
      return new Date().toISOString().split('T')[0]
    }
  }
  
  loadVideos(id, date, type = 'tag') {
    // Construir la URL según el tipo
    const params = new URLSearchParams({
      date: date
    })
    
    if (type === 'tag') {
      params.append('tag_id', id)
    } else if (type === 'topic') {
      params.append('topic_id', id)
    }
    
    fetch(this.urlValue + "?" + params)
      .then(response => response.text())
      .then(html => {
        const modalEntries = document.getElementById(`${this.idValue}Entries`)
        if (modalEntries) {
          modalEntries.innerHTML = html
          this.openModal()
        }
      })
      .catch(error => {
        console.error('Error loading videos:', error)
        const modalEntries = document.getElementById(`${this.idValue}Entries`)
        if (modalEntries) {
          modalEntries.innerHTML = `
            <div class="p-4 text-center text-red-600">
              <p class="font-bold">Error al cargar los clips</p>
              <p class="text-sm mt-2">${error.message}</p>
            </div>
          `
        }
      })
  }

  openModal() {
    const modal = document.getElementById(`${this.idValue}Modal`)
    if (modal) {
      modal.classList.remove('hidden')
      modal.style.display = 'block'
      modal.style.setProperty('display', 'block', 'important')
      document.body.style.overflow = 'hidden'
      
      // Ensure modal is properly centered
      setTimeout(() => {
        const modalPanel = modal.querySelector('.inline-block')
        if (modalPanel) {
          modalPanel.style.marginLeft = 'auto'
          modalPanel.style.marginRight = 'auto'
        }
      }, 10)
    }
  }
}
