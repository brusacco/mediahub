import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal"]

  connect() {
    // Bind the keyboard handler to this instance
    this.handleKeydown = this.handleKeydown.bind(this);
    
    // Observe class and style changes to add/remove listener dynamically
    this.observer = new MutationObserver((mutations) => {
      mutations.forEach((mutation) => {
        if (mutation.attributeName === 'class' || mutation.attributeName === 'style') {
          const isVisible = !this.modalTarget.classList.contains('hidden') && 
                           this.modalTarget.style.display !== 'none'
          if (isVisible) {
            document.addEventListener('keydown', this.handleKeydown);
            setTimeout(() => this.modalTarget.focus(), 100);
          } else {
            document.removeEventListener('keydown', this.handleKeydown);
          }
        }
      });
    });
    
    this.observer.observe(this.modalTarget, { 
      attributes: true, 
      attributeFilter: ['class', 'style'] 
    });
  }

  disconnect() {
    // Clean up event listener and observer
    document.removeEventListener('keydown', this.handleKeydown);
    if (this.observer) {
      this.observer.disconnect();
    }
  }

  handleKeydown(event) {
    // Close modal on ESC key
    if (event.key === 'Escape' || event.key === 'Esc') {
      this.closeModal(event);
    }
  }

  closeModal(event) {
    if (event) {
      event.preventDefault();
    }
    this.modalTarget.classList.add("hidden");
    this.modalTarget.style.display = 'none';
    document.body.style.overflow = ''; // Restore scrolling
    // Remove the keyboard listener when closing
    document.removeEventListener('keydown', this.handleKeydown);
  }
}

