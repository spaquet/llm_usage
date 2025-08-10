// app/javascript/controllers/mobile_menu_controller.js
import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="mobile-menu"
export default class extends Controller {
  static targets = ["menu"]

  toggle() {
    this.menuTarget.classList.toggle("hidden")
  }

  hide() {
    this.menuTarget.classList.add("hidden")
  }

  show() {
    this.menuTarget.classList.remove("hidden")
  }
}