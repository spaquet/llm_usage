import { Controller } from "@hotwired/stimulus";
import Chart from "chart.js/auto";

// Connects to data-controller="usage-chart"
export default class extends Controller {
  static targets = ["canvas"];

  connect() {
    const ctx = this.canvasTarget.getContext("2d");
    new Chart(ctx, {
      type: "line",
      data: {
        labels: JSON.parse(this.element.dataset.labels || "[]"),
        datasets: [{
          label: "API Requests",
          data: JSON.parse(this.element.dataset.data || "[]"),
          borderColor: "#2563eb",
          backgroundColor: "rgba(37, 99, 235, 0.1)",
          fill: true
        }]
      },
      options: {
        responsive: true,
        scales: {
          y: { beginAtZero: true }
        }
      }
    });
  }
}