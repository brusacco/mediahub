import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="mobile-menu"
export default class extends Controller {
  static values = { 
    open: { type: Boolean, default: false }
  }

  connect() {
    // Find the menu element by ID
    this.menuElement = document.getElementById("mobile-menu")
    
    // Close menu when clicking outside
    this.boundCloseOnOutsideClick = this.closeOnOutsideClick.bind(this)
    document.addEventListener("click", this.boundCloseOnOutsideClick)
  }

  disconnect() {
    // Cleanup: remove event listener
    document.removeEventListener("click", this.boundCloseOnOutsideClick)
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()
    this.openValue = !this.openValue
  }

  close(event) {
    if (event) {
      event.preventDefault()
      event.stopPropagation()
    }
    this.openValue = false
  }

  openValueChanged() {
    if (!this.menuElement) return
    
    if (this.openValue) {
      this.menuElement.classList.remove("hidden")
      this.element.setAttribute("aria-expanded", "true")
    } else {
      this.menuElement.classList.add("hidden")
      this.element.setAttribute("aria-expanded", "false")
    }
  }

  closeOnOutsideClick(event) {
    if (!this.menuElement) return
    
    // Don't close if clicking inside the menu or its button
    if (this.element.contains(event.target) || this.menuElement.contains(event.target)) {
      return
    }
    
    // Close if clicking outside
    if (this.openValue) {
      this.close()
    }
  }
}

