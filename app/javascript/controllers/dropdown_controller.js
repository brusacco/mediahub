import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="dropdown"
export default class extends Controller {
  static targets = ["menu"]
  static values = { 
    open: { type: Boolean, default: false }
  }

  connect() {
    // Close dropdown when clicking outside
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
    if (this.openValue) {
      this.menuTarget.classList.remove("hidden")
      this.element.setAttribute("aria-expanded", "true")
    } else {
      this.menuTarget.classList.add("hidden")
      this.element.setAttribute("aria-expanded", "false")
    }
  }

  closeOnOutsideClick(event) {
    // Don't close if clicking inside the dropdown or its button
    if (this.element.contains(event.target) || this.menuTarget.contains(event.target)) {
      return
    }
    
    // Close if clicking outside
    if (this.openValue) {
      this.close()
    }
  }
}

