import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="sticky-nav"
export default class extends Controller {
  connect() {
    this.initializeBackToTop()
    this.initializeNavLinks()
  }

  initializeBackToTop() {
    const backToTopLink = document.getElementById('backToTop')
    
    if (backToTopLink && !backToTopLink.dataset.initialized) {
      backToTopLink.dataset.initialized = 'true'
      
      backToTopLink.addEventListener('click', (e) => {
        e.preventDefault()
        window.scrollTo({ top: 0, behavior: 'smooth' })
        backToTopLink.blur()
      })

      // Show/hide back to top button on scroll
      this.boundHandleScroll = () => {
        const scrollPos = window.scrollY || window.pageYOffset || document.documentElement.scrollTop || 0
        
        if (scrollPos > 300) {
          backToTopLink.style.opacity = '1'
          backToTopLink.style.visibility = 'visible'
        } else {
          backToTopLink.style.opacity = '0'
          backToTopLink.style.visibility = 'hidden'
        }
      }

      window.addEventListener('scroll', this.boundHandleScroll, { passive: true })
      this.boundHandleScroll() // Initial check
    }
  }

  initializeNavLinks() {
    // Remove focus from navigation links after click
    const navLinks = this.element.querySelectorAll('a[href^="#"]')
    navLinks.forEach(link => {
      if (!link.dataset.navInitialized) {
        link.dataset.navInitialized = 'true'
        link.addEventListener('click', function() {
          setTimeout(() => {
            this.blur()
          }, 100)
        })
      }
    })
  }

  disconnect() {
    if (this.boundHandleScroll) {
      window.removeEventListener('scroll', this.boundHandleScroll)
    }
  }
}

