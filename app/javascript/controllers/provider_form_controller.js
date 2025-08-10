import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="provider-form"
export default class extends Controller {
  static targets = ["keyField", "secretField", "keyLabel", "keyInput"];

  connect() {
    // Initialize the form state
    this.toggleKeyField();
  }

  toggleKeyField(event) {
    const providerType = event ? event.target.value : this.element.querySelector('select[name="provider[provider_type]"]').value;
    const keyField = this.keyFieldTarget;
    const secretField = this.secretFieldTarget;

    // All predefined providers use api_key
    if (providerType && ["xAI", "OpenAI", "Anthropic"].includes(providerType)) {
      keyField.classList.remove("hidden");
      if (this.hasKeyLabelTarget) this.keyLabelTarget.classList.remove("hidden");
      if (this.hasKeyInputTarget) this.keyInputTarget.classList.remove("hidden");
      secretField.classList.add("hidden");
    } else {
      keyField.classList.add("hidden");
      if (this.hasKeyLabelTarget) this.keyLabelTarget.classList.add("hidden");
      if (this.hasKeyInputTarget) this.keyInputTarget.classList.add("hidden");
      secretField.classList.remove("hidden");
    }
  }
}