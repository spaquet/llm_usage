import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="provider-form"
export default class extends Controller {
 static targets = ["keyField", "secretField"];

 toggleKeyField(event) {
 const providerType = event.target.value;
 const keyField = this.keyFieldTarget;
 const secretField = this.secretFieldTarget;

 // All predefined providers use api_key, but we include secretField for future extensibility
 if (providerType && ["xAI", "OpenAI", "Anthropic"].includes(providerType)) {
 keyField.classList.remove("hidden");
 keyField.querySelector("[data-provider-form-target='label']").classList.remove("hidden");
 keyField.querySelector("[data-provider-form-target='input']").classList.remove("hidden");
 secretField.classList.add("hidden");
 } else {
 keyField.classList.add("hidden");
 secretField.classList.remove("hidden");
 }
 }
}