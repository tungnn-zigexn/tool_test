// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import "helpers/toast_helper"

// Turbo confirm handler - uses native browser confirm dialog (new API)
Turbo.config.forms.confirm = (message, element) => {
  return confirm(message)
}

// Global timeout for Turbo requests (20 seconds) to prevent hanging
document.addEventListener("turbo:before-fetch-request", (event) => {
  const timeoutMs = 20000;
  const timeoutId = setTimeout(() => {
    const confirmReload = confirm(
      "Yêu cầu đang phản hồi chậm. Trang web có thể đang gặp sự cố. Bạn có muốn tải lại trang ngay bây giờ không?"
    );
    if (confirmReload) {
      window.location.reload();
    }
  }, timeoutMs);

  document.addEventListener("turbo:before-fetch-response", () => clearTimeout(timeoutId), { once: true });
});
