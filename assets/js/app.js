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

// Notification bell sound
window.addEventListener("phx:play_notification_sound", (e) => {
  const type = e.detail.type || "chat"
  playNotificationSound(type === "call" ? "call" : "chat")
  showBrowserNotification("Nueva notificación", e.detail.title || "Tienes una nueva notificación")
})

// Request notification permission on page load
if ("Notification" in window && Notification.permission === "default") {
  Notification.requestPermission()
}

const WebRTCAudio = {
  mounted() {
    this.peers = {}       // { peerId: RTCPeerConnection }
    this.localStream = null
    this.myUserId = null
    this.audioContexts = {}  // { peerId: { analyser, ctx } }
    this.speakingInterval = null

    this.handleEvent("webrtc_start", ({user_id, peers}) => {
      console.log("[WebRTC] start, my id:", user_id, "peers:", peers)
      this.myUserId = user_id
      this.startMedia().then(() => {
        console.log("[WebRTC] media ready, creating offers to", peers.length, "peers")
        this.monitorLocalAudio()
        peers.forEach(p => this.createOffer(p.user_id))
      })
    })

    this.handleEvent("webrtc_stop", () => {
      console.log("[WebRTC] stop")
      this.cleanup()
    })

    this.handleEvent("webrtc_offer", ({from, offer}) => {
      console.log("[WebRTC] received offer from", from)
      this.ensureMedia().then(() => this.handleOffer(from, offer))
    })

    this.handleEvent("webrtc_answer", ({from, answer}) => {
      console.log("[WebRTC] received answer from", from)
      this.handleAnswer(from, answer)
    })

    this.handleEvent("webrtc_ice", ({from, candidate}) => {
      this.handleIce(from, candidate)
    })
  },

  destroyed() {
    this.cleanup()
  },

  async startMedia() {
    try {
      this.localStream = await navigator.mediaDevices.getUserMedia({ audio: true, video: false })
      console.log("[WebRTC] got local audio stream")
    } catch (e) {
      console.error("[WebRTC] Failed to get audio:", e)
    }
  },

  async ensureMedia() {
    if (!this.localStream) {
      await this.startMedia()
    }
  },

  createPeerConnection(peerId) {
    if (this.peers[peerId]) {
      this.peers[peerId].close()
    }

    const pc = new RTCPeerConnection({
      iceServers: [
        { urls: "stun:stun.l.google.com:19302" },
        { urls: "stun:stun1.l.google.com:19302" }
      ]
    })

    if (this.localStream) {
      this.localStream.getTracks().forEach(track => pc.addTrack(track, this.localStream))
    }

    pc.onicecandidate = (event) => {
      if (event.candidate) {
        this.pushEvent("webrtc_ice", {
          to: peerId,
          candidate: JSON.stringify(event.candidate)
        })
      }
    }

    pc.oniceconnectionstatechange = () => {
      console.log("[WebRTC] ICE state with", peerId, ":", pc.iceConnectionState)
    }

    pc.ontrack = (event) => {
      console.log("[WebRTC] got remote track from", peerId)
      const container = document.getElementById("webrtc-audio-container")
      let audio = document.getElementById(`audio-${peerId}`)
      if (!audio) {
        audio = document.createElement("audio")
        audio.id = `audio-${peerId}`
        audio.autoplay = true
        audio.playsInline = true
        container.appendChild(audio)
      }
      audio.srcObject = event.streams[0]
      this.monitorRemoteAudio(peerId, event.streams[0])
    }

    this.peers[peerId] = pc
    return pc
  },

  async createOffer(peerId) {
    const pc = this.createPeerConnection(peerId)
    const offer = await pc.createOffer()
    await pc.setLocalDescription(offer)
    console.log("[WebRTC] sending offer to", peerId)

    this.pushEvent("webrtc_offer", {
      to: peerId,
      offer: JSON.stringify(offer)
    })
  },

  async handleOffer(fromId, offerStr) {
    const pc = this.createPeerConnection(fromId)
    const offer = JSON.parse(offerStr)
    await pc.setRemoteDescription(new RTCSessionDescription(offer))

    const answer = await pc.createAnswer()
    await pc.setLocalDescription(answer)
    console.log("[WebRTC] sending answer to", fromId)

    this.pushEvent("webrtc_answer", {
      to: fromId,
      answer: JSON.stringify(answer)
    })
  },

  async handleAnswer(fromId, answerStr) {
    const pc = this.peers[fromId]
    if (pc) {
      const answer = JSON.parse(answerStr)
      await pc.setRemoteDescription(new RTCSessionDescription(answer))
    }
  },

  async handleIce(fromId, candidateStr) {
    const pc = this.peers[fromId]
    if (pc) {
      try {
        const candidate = JSON.parse(candidateStr)
        await pc.addIceCandidate(new RTCIceCandidate(candidate))
      } catch (e) {
        console.warn("[WebRTC] ICE candidate error:", e)
      }
    }
  },

  monitorLocalAudio() {
    if (!this.localStream) return
    try {
      const ctx = new AudioContext()
      const source = ctx.createMediaStreamSource(this.localStream)
      const analyser = ctx.createAnalyser()
      analyser.fftSize = 512
      analyser.smoothingTimeConstant = 0.4
      source.connect(analyser)
      this.audioContexts["local"] = { ctx, analyser }
      this.startSpeakingDetection()
    } catch (e) {
      console.warn("[WebRTC] local audio monitor failed:", e)
    }
  },

  monitorRemoteAudio(peerId, stream) {
    try {
      const ctx = new AudioContext()
      const source = ctx.createMediaStreamSource(stream)
      const analyser = ctx.createAnalyser()
      analyser.fftSize = 512
      analyser.smoothingTimeConstant = 0.4
      source.connect(analyser)
      this.audioContexts[peerId] = { ctx, analyser }
    } catch (e) {
      console.warn("[WebRTC] remote audio monitor failed:", e)
    }
  },

  startSpeakingDetection() {
    if (this.speakingInterval) return
    const threshold = 15

    this.speakingInterval = setInterval(() => {
      // Check local
      if (this.audioContexts["local"]) {
        const isSpeaking = this.getAudioLevel(this.audioContexts["local"].analyser) > threshold
        this.setSpeakingState(this.myUserId, isSpeaking)
      }
      // Check remotes
      for (const [peerId, ac] of Object.entries(this.audioContexts)) {
        if (peerId === "local") continue
        const isSpeaking = this.getAudioLevel(ac.analyser) > threshold
        this.setSpeakingState(peerId, isSpeaking)
      }
    }, 100)
  },

  getAudioLevel(analyser) {
    const data = new Uint8Array(analyser.frequencyBinCount)
    analyser.getByteFrequencyData(data)
    let sum = 0
    for (let i = 0; i < data.length; i++) sum += data[i]
    return sum / data.length
  },

  setSpeakingState(userId, isSpeaking) {
    const el = document.getElementById(`voice-avatar-${userId}`)
    if (!el) return
    const ring = el.querySelector(".voice-ring")
    if (!ring) return
    if (isSpeaking) {
      ring.style.borderColor = "#22c55e"
      ring.style.boxShadow = "0 0 12px 2px rgba(34,197,94,0.5)"
    } else {
      ring.style.borderColor = "transparent"
      ring.style.boxShadow = "none"
    }
  },

  cleanup() {
    if (this.speakingInterval) {
      clearInterval(this.speakingInterval)
      this.speakingInterval = null
    }

    for (const ac of Object.values(this.audioContexts)) {
      ac.ctx.close()
    }
    this.audioContexts = {}

    Object.values(this.peers).forEach(pc => pc.close())
    this.peers = {}

    if (this.localStream) {
      this.localStream.getTracks().forEach(t => t.stop())
      this.localStream = null
    }

    const container = document.getElementById("webrtc-audio-container")
    if (container) {
      while (container.firstChild) container.removeChild(container.firstChild)
    }
  }
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, CursorTracker, TaskDescriptionInput, ChatScroll, WebRTCAudio},
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
