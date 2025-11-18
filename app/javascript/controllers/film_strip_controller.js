import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "current"]

  connect() {
    // Scroll to center the current video
    this.scrollToCurrent()
  }

  scrollToCurrent() {
    if (this.hasCurrentTarget) {
      const container = this.containerTarget
      const currentVideo = this.currentTarget
      
      if (container && currentVideo) {
        // Calculate scroll position to center the current video
        const containerRect = container.getBoundingClientRect()
        const videoRect = currentVideo.getBoundingClientRect()
        const scrollLeft = currentVideo.offsetLeft - (containerRect.width / 2) + (videoRect.width / 2)
        
        container.scrollTo({
          left: scrollLeft,
          behavior: 'smooth'
        })
      }
    }
  }
}



