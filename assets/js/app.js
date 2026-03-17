// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/noti_osw4l"
import topbar from "../vendor/topbar"

const CursorTracker = {
  mounted() {
    this.throttleTimer = null
    document.addEventListener("mousemove", (e) => {
      if (this.throttleTimer) return
      this.throttleTimer = setTimeout(() => {
        this.throttleTimer = null
      }, 50)
      this.pushEvent("cursor_move", {x: e.clientX, y: e.clientY})
    })
    document.addEventListener("mouseleave", () => {
      this.pushEvent("cursor_leave", {})
    })
  }
}

const ChatScroll = {
  mounted() {
    this.el.scrollTop = this.el.scrollHeight
  },
  updated() {
    this.el.scrollTop = this.el.scrollHeight
  }
}

const TaskDescriptionInput = {
  mounted() {
    this.el.focus()
    this.el.setSelectionRange(this.el.value.length, this.el.value.length)
  }
}

// Notification sounds using Web Audio API
function playNotificationSound(type) {
  try {
    const ctx = new (window.AudioContext || window.webkitAudioContext)()
    const oscillator = ctx.createOscillator()
    const gainNode = ctx.createGain()
    oscillator.connect(gainNode)
    gainNode.connect(ctx.destination)
    gainNode.gain.value = 0.3

    if (type === "call") {
      oscillator.frequency.value = 440
      oscillator.type = "sine"
      gainNode.gain.setValueAtTime(0.3, ctx.currentTime)
      gainNode.gain.exponentialRampToValueAtTime(0.01, ctx.currentTime + 0.8)
      oscillator.start(ctx.currentTime)
      oscillator.stop(ctx.currentTime + 0.8)
      // Second tone
      setTimeout(() => {
        const ctx2 = new (window.AudioContext || window.webkitAudioContext)()
        const osc2 = ctx2.createOscillator()
        const gain2 = ctx2.createGain()
        osc2.connect(gain2)
        gain2.connect(ctx2.destination)
        osc2.frequency.value = 554
        osc2.type = "sine"
        gain2.gain.setValueAtTime(0.3, ctx2.currentTime)
        gain2.gain.exponentialRampToValueAtTime(0.01, ctx2.currentTime + 0.6)
        osc2.start(ctx2.currentTime)
        osc2.stop(ctx2.currentTime + 0.6)
      }, 300)
    } else {
      // Chat notification - short pop
      oscillator.frequency.value = 800
      oscillator.type = "sine"
      gainNode.gain.setValueAtTime(0.2, ctx.currentTime)
      gainNode.gain.exponentialRampToValueAtTime(0.01, ctx.currentTime + 0.15)
      oscillator.start(ctx.currentTime)
      oscillator.stop(ctx.currentTime + 0.15)
    }
  } catch (e) {
    // Audio not available
  }
}

// Browser notification helper
function showBrowserNotification(title, body) {
  if (Notification.permission === "granted") {
    new Notification(title, { body, icon: "/favicon.ico" })
  } else if (Notification.permission !== "denied") {
    Notification.requestPermission().then(p => {
      if (p === "granted") new Notification(title, { body, icon: "/favicon.ico" })
    })
  }
}

// Listen for server-pushed notification events
window.addEventListener("phx:notify_call", (e) => {
  playNotificationSound("call")
  showBrowserNotification("Llamada en curso", e.detail.message || "Alguien se unió al canal de voz")
})

window.addEventListener("phx:notify_chat", (e) => {
  playNotificationSound("chat")
  showBrowserNotification("Nuevo mensaje", e.detail.message || "Tienes un nuevo mensaje")
})

// Request notification permission on page load
if ("Notification" in window && Notification.permission === "default") {
  Notification.requestPermission()
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, CursorTracker, TaskDescriptionInput, ChatScroll},
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}
