import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    formId: String,
  }

  connect() {
    setTimeout(() => {
      const form = document.getElementById(this.formIdValue);
      if (form.dataset.submitted == 1) {
        return
      }
      form.dataset.submitted = 1
      form.requestSubmit()
    }, 5000)
  }
}
