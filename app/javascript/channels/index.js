// Action Cable consumer for realtime (notifications, etc.)
import { createConsumer } from "@rails/actioncable"

const meta = document.querySelector("meta[name='action-cable-url']")
const url = (meta && meta.getAttribute("content")) || "/cable"
export default createConsumer(url)
