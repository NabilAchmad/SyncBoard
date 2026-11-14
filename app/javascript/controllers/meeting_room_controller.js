import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

const DEFAULT_ICE_SERVERS = [
  { urls: "stun:stun.l.google.com:19302" },
  { urls: "stun:stun1.l.google.com:19302" },
  { urls: "stun:stun.cloudflare.com:3478" }
]

const DOCK_ICON_PATHS = {
  mic: "M12 14c1.66 0 3-1.34 3-3V5c0-1.66-1.34-3-3-3S9 3.34 9 5v6c0 1.66 1.34 3 3 3Zm-1-9a1 1 0 0 1 2 0v6a1 1 0 0 1-2 0V5Zm6 6c0 2.76-2.24 5-5 5s-5-2.24-5-5H5c0 3.53 2.61 6.43 6 6.92V21h2v-3.08c3.39-.49 6-3.39 6-6.92h-2Z",
  mic_off: "M19 11h-1.7c0 .74-.16 1.43-.43 2.05l1.23 1.23c.56-.98.9-2.09.9-3.28Zm-4.02.17c0-.06.02-.11.02-.17V5c0-1.66-1.34-3-3-3S9 3.34 9 5v.18l5.98 5.99ZM4.27 3 3 4.27l6.01 6.01V11c0 1.66 1.33 3 2.99 3 .22 0 .44-.03.65-.08l1.66 1.66c-.71.33-1.5.52-2.31.52-2.76 0-5.3-2.1-5.3-5.1H5c0 3.41 2.72 6.23 6 6.72V21h2v-3.28c.91-.13 1.77-.45 2.54-.9L19.73 21 21 19.73 4.27 3Z",
  videocam: "M17 10.5V7c0-.55-.45-1-1-1H4c-.55 0-1 .45-1 1v10c0 .55.45 1 1 1h12c.55 0 1-.45 1-1v-3.5l4 4v-11l-4 4Z",
  videocam_off: "M21 6.5l-4 4V7c0-.55-.45-1-1-1H9.82L21 17.18V6.5ZM3.27 2 2 3.27 4.73 6H4c-.55 0-1 .45-1 1v10c0 .55.45 1 1 1h12c.21 0 .39-.08.54-.18L19.73 21 21 19.73 3.27 2Z",
  present_to_all: "M21 3H3c-1.11 0-2 .89-2 2v14c0 1.11.89 2 2 2h18c1.11 0 2-.89 2-2V5c0-1.11-.89-2-2-2Zm0 16.02H3V4.98h18v14.04ZM10 12H8l4-4 4 4h-2v4h-4v-4Z",
  stop_screen_share: "M21 3H3c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h18c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2Zm0 16H3V5h18v14ZM9.41 15.95 12 13.36l2.59 2.59L16 14.54l-2.59-2.59L16 9.36l-1.41-1.41L12 10.54 9.41 7.95 8 9.36l2.59 2.59L8 14.54l1.41 1.41Z",
  flip: "M15 21h2v-2h-2v2Zm4-12h2V7h-2v2ZM3 5v14c0 1.1.9 2 2 2h4v-2H5V5h4V3H5c-1.1 0-2 .9-2 2Zm16-2v2h2c0-1.1-.9-2-2-2Zm-8 20h2V1h-2v22Zm8-6h2v-2h-2v2ZM15 5h2V3h-2v2Zm4 8h2v-2h-2v2Zm0 8c1.1 0 2-.9 2-2h-2v2Z",
  closed_caption: "M19 4H5a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h14c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2Zm0 14H5V6h14v12Zm-8-7H9.5v-.5h-2v3h2V13H11v1c0 .55-.45 1-1 1H7c-.55 0-1-.45-1-1v-4c0-.55.45-1 1-1h3c.55 0 1 .45 1 1v1Zm7 0h-1.5v-.5h-2v3h2V13H18v1c0 .55-.45 1-1 1h-3c-.55 0-1-.45-1-1v-4c0-.55.45-1 1-1h3c.55 0 1 .45 1 1v1Z",
  graphic_eq: "M7 18h2V6H7v12Zm4 4h2V2h-2v20Zm-8-8h2v-4H3v4Zm12 4h2V6h-2v12Zm4-8v4h2v-4h-2Z",
  call_end: "M12 9c-1.6 0-3.15.25-4.6.72v3.1c0 .39-.23.74-.56.9-.98.49-1.87 1.12-2.66 1.85-.18.18-.43.28-.7.28-.28 0-.53-.11-.71-.29L.29 13.08a.956.956 0 0 1-.29-.7c0-.28.11-.53.29-.71C3.34 8.78 7.46 7 12 7s8.66 1.78 11.71 4.67c.18.18.29.43.29.71 0 .28-.11.53-.29.71l-2.48 2.48c-.18.18-.43.29-.71.29-.27 0-.52-.11-.7-.28a11.27 11.27 0 0 0-2.67-1.85.996.996 0 0 1-.56-.9v-3.1C15.15 9.25 13.6 9 12 9Z",
  call: "M20.01 15.38c-1.23 0-2.42-.2-3.53-.56a.977.977 0 0 0-1.01.24l-1.57 1.97c-2.83-1.35-5.48-3.9-6.89-6.83l1.95-1.66c.27-.28.35-.67.24-1.02-.37-1.11-.56-2.3-.56-3.53 0-.54-.45-.99-.99-.99H4.19C3.65 3 3 3.24 3 3.99 3 13.28 10.73 21 20.01 21c.71 0 .99-.63.99-1.18v-3.45c0-.54-.45-.99-.99-.99Z"
}

export default class extends Controller {
  static targets = [
    "localVideo",
    "localPlaceholder",
    "localStatus",
    "peersGrid",
    "emptyState",
    "participantCount",
    "micButton",
    "camButton",
    "mirrorButton",
    "screenButton",
    "callButton",
    "endCallModal",
    "speechButton",
    "transcriptInput",
    "saveStatus",
    "liveCaptions",
    "quickCaptionInput",
    "captionTagButton",
    "summaryTranscriptField",
    "endCallTranscriptField",
    "messageForm",
    "messageBody",
    "rightTab",
    "rightPanel"
  ]

  static values = {
    meetingId: Number,
    userId: Number,
    userName: String,
    userInitials: String,
    userRole: String,
    saveTranscriptUrl: String,
    isHost: { type: Boolean, default: false },
    autoJoinCall: { type: Boolean, default: true },
    iceServers: { type: Array, default: [] }
  }

  connect() {
    this.clientId = this.generateClientId()
    this.peers = new Map()
    this.peerMediaStates = new Map()
    this.pendingCandidates = new Map()
    this.acquiringDevices = new Set()
    this.localStream = null
    this.screenStream = null
    this.audioEnabled = true
    this.videoEnabled = true
    this.screenSharing = false
    this.callActive = false
    this.leaveSent = false
    this.pendingAudioUnlock = false
    this.lastAudioError = null
    this.lastVideoError = null
    const savedMirror = window.localStorage?.getItem("syncboard_mirror_cam")
    this.mirrorEnabled = savedMirror === null ? true : savedMirror === "true"
    this.recognizing = false
    this.recognition = null
    this.saveTimer = null

    this.handlePageLeave = () => this.sendLeaveSignal()
    this.handleUserGesture = () => this.retryRemoteAudioPlayback()
    window.addEventListener("pagehide", this.handlePageLeave)
    window.addEventListener("beforeunload", this.handlePageLeave)
    document.addEventListener("pointerdown", this.handleUserGesture)

    this.consumer = createConsumer()
    this.setupMediaAndJoin()
  }

  disconnect() {
    if (this.saveTimer) clearTimeout(this.saveTimer)
    window.removeEventListener("pagehide", this.handlePageLeave)
    window.removeEventListener("beforeunload", this.handlePageLeave)
    document.removeEventListener("pointerdown", this.handleUserGesture)
    this.stopSpeechRecognition({ preserveCaption: true })
    this.sendLeaveSignal()
    this.closeAllPeers()
    this.peerMediaStates.clear()
    this.stopAllMediaStreams()
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
    if (this.consumer) {
      this.consumer.disconnect()
    }
  }

  sendLeaveSignal() {
    if (!this.callActive || this.leaveSent || !this.subscription) return
    this.leaveSent = true
    this.subscription.perform("leave", { client_id: this.clientId })
  }

  retryRemoteAudioPlayback() {
    if (!this.pendingAudioUnlock || !this.hasPeersGridTarget) return
    this.pendingAudioUnlock = false
    this.peersGridTarget.querySelectorAll("audio").forEach((audioEl) => {
      if (audioEl.srcObject && audioEl.paused) {
        audioEl.play().catch(() => { this.pendingAudioUnlock = true })
      }
    })
  }

  stopAllMediaStreams() {
    if (this.screenStream) {
      this.screenStream.getTracks().forEach((track) => track.stop())
      this.screenStream = null
    }
    if (this.localStream) {
      this.localStream.getTracks().forEach((track) => track.stop())
      this.localStream = null
    }
    if (this.hasLocalVideoTarget) {
      this.localVideoTarget.srcObject = null
    }
    this.screenSharing = false
    this.audioEnabled = false
    this.videoEnabled = false
  }

  generateClientId() {
    if (window.crypto?.randomUUID) return window.crypto.randomUUID()
    return `tab-${Date.now()}-${Math.random().toString(16).slice(2, 8)}`
  }

  async setupMediaAndJoin() {
    if (this.autoJoinCallValue) {
      this.callActive = true
      await this.acquireLocalMedia()
    } else {
      this.callActive = false
      this.audioEnabled = false
      this.videoEnabled = false
      this.setLocalStatus("Sesi panggilan sudah selesai (klik Gabung Panggilan untuk buka lagi)", "slate")
      this.showLocalPlaceholder(true)
    }

    this.subscribeToRoom()
    this.updateMediaButtons()
    this.updateParticipantCount()
  }

  liveTracks(kind) {
    if (!this.localStream) return []
    const getter = kind === "video" ? "getVideoTracks" : "getAudioTracks"
    return this.localStream[getter]().filter((track) => track.readyState === "live")
  }

  watchStreamTracks(stream) {
    stream.getAudioTracks().forEach((track) => {
      track.onended = () => this.handleLocalTrackEnded("audio")
    })
    stream.getVideoTracks().forEach((track) => {
      track.onended = () => this.handleLocalTrackEnded("video")
    })
  }

  handleLocalTrackEnded(kind) {
    if (!this.callActive) return
    if (kind === "video") {
      this.videoEnabled = this.liveTracks("video").length > 0
      if (!this.screenSharing) {
        this.showLocalPlaceholder(!this.videoEnabled)
      }
    } else {
      this.audioEnabled = this.liveTracks("audio").length > 0
    }
    this.refreshLocalStatusSummary()
    this.broadcastMediaState()
    this.updateMediaButtons()
  }

  async tryAcquireStream(constraints) {
    try {
      const stream = await navigator.mediaDevices.getUserMedia(constraints)
      return { stream, error: null }
    } catch (error) {
      return { stream: null, error }
    }
  }

  shortErrorHint(error) {
    switch (error?.name) {
      case "NotAllowedError":
      case "PermissionDeniedError":
        return "izin ditolak browser"
      case "NotFoundError":
      case "DevicesNotFoundError":
        return "perangkat tidak ditemukan"
      case "NotReadableError":
      case "TrackStartError":
        return "sedang dipakai app lain"
      default:
        return "klik ikon untuk coba lagi"
    }
  }

  describeDeviceFailure(deviceLabel, error) {
    if (!window.isSecureContext) {
      return `${deviceLabel} membutuhkan HTTPS atau http://localhost.`
    }
    if (!navigator.mediaDevices?.getUserMedia) {
      return `Browser ini tidak mendukung akses ${deviceLabel.toLowerCase()}.`
    }

    switch (error?.name) {
      case "NotAllowedError":
      case "PermissionDeniedError":
        return `Izin ${deviceLabel.toLowerCase()} ditolak browser. Klik ikon gembok/kamera di address bar lalu izinkan akses.`
      case "NotFoundError":
      case "DevicesNotFoundError":
        return `${deviceLabel} tidak terdeteksi di perangkat ini.`
      case "NotReadableError":
      case "TrackStartError":
        return `${deviceLabel} sedang dipakai aplikasi atau tab lain.`
      case "OverconstrainedError":
        return `Resolusi ${deviceLabel.toLowerCase()} tidak didukung perangkat ini.`
      default:
        return `Gagal mengakses ${deviceLabel.toLowerCase()} (${error?.name || "error"}).`
    }
  }

  refreshLocalStatusSummary() {
    if (!this.callActive) return

    const hasMic = this.liveTracks("audio").length > 0
    const hasCam = this.liveTracks("video").length > 0

    if (hasMic && hasCam) {
      if (this.audioEnabled && this.videoEnabled) {
        this.setLocalStatus("Kamera & Mikrofon aktif", "emerald")
      } else if (this.videoEnabled) {
        this.setLocalStatus("Kamera aktif · Mic mute", "emerald")
      } else if (this.audioEnabled) {
        this.setLocalStatus("Mikrofon aktif · Cam off", "emerald")
      } else {
        this.setLocalStatus("Mic mute & Cam off", "slate")
      }
      return
    }

    if (hasCam && !hasMic) {
      const hint = this.lastAudioError ? ` (${this.shortErrorHint(this.lastAudioError)})` : ""
      this.setLocalStatus(`Kamera aktif · Mic tidak aktif${hint}`, "amber")
      return
    }

    if (hasMic && !hasCam) {
      const hint = this.lastVideoError ? ` (${this.shortErrorHint(this.lastVideoError)})` : ""
      this.setLocalStatus(`Hanya Audio · Klik Cam untuk aktifkan${hint}`, "amber")
      return
    }

    const primaryErr = this.lastVideoError || this.lastAudioError
    if (primaryErr) {
      this.setLocalStatus(`Mode Observer (${this.shortErrorHint(primaryErr)}) — klik Mic/Cam untuk coba lagi`, "amber")
    } else {
      this.setLocalStatus("Mode Observer (klik Mic/Cam atau pakai Share Screen)", "slate")
    }
  }

  async acquireLocalMedia() {
    this.lastAudioError = null
    this.lastVideoError = null

    if (!window.isSecureContext) {
      this.localStream = null
      this.audioEnabled = false
      this.videoEnabled = false
      this.setLocalStatus("Kamera & mic butuh HTTPS (atau http://localhost). Anda tetap bisa chat & ikut rapat.", "amber")
      this.showLocalPlaceholder(true)
      return
    }

    if (!navigator.mediaDevices?.getUserMedia) {
      this.localStream = null
      this.audioEnabled = false
      this.videoEnabled = false
      this.setLocalStatus("Browser tidak mendukung WebRTC media; mode observer aktif.", "amber")
      this.showLocalPlaceholder(true)
      return
    }

    const combined = await this.tryAcquireStream({ video: true, audio: true })
    if (combined.stream) {
      this.localStream = combined.stream
    } else {
      const tracks = []
      const audioRes = await this.tryAcquireStream({ audio: true })
      if (audioRes.stream) {
        tracks.push(...audioRes.stream.getAudioTracks())
      } else {
        this.lastAudioError = audioRes.error || combined.error
      }

      const videoRes = await this.tryAcquireStream({ video: true })
      if (videoRes.stream) {
        tracks.push(...videoRes.stream.getVideoTracks())
      } else {
        this.lastVideoError = videoRes.error || combined.error
      }

      this.localStream = tracks.length > 0 ? new MediaStream(tracks) : null
    }

    if (this.localStream) {
      this.watchStreamTracks(this.localStream)
    }

    this.audioEnabled = this.liveTracks("audio").length > 0
    this.videoEnabled = this.liveTracks("video").length > 0

    if (this.videoEnabled) {
      this.attachLocalVideo(this.localStream)
      this.showLocalPlaceholder(false)
    } else {
      this.showLocalPlaceholder(true)
    }

    this.refreshLocalStatusSummary()
  }

  attachLocalVideo(stream) {
    if (!this.hasLocalVideoTarget) return
    this.localVideoTarget.srcObject = stream
    this.localVideoTarget.muted = true
    this.applyLocalMirrorTransform()
    this.localVideoTarget.play().catch(() => {})
  }

  applyLocalMirrorTransform() {
    if (!this.hasLocalVideoTarget) return
    const shouldMirror = this.mirrorEnabled && !this.screenSharing
    this.localVideoTarget.style.transform = shouldMirror ? "scaleX(-1)" : ""
  }

  showLocalPlaceholder(show) {
    if (this.hasLocalPlaceholderTarget) {
      this.localPlaceholderTarget.classList.toggle("hidden", !show)
    }
    if (this.hasLocalVideoTarget) {
      this.localVideoTarget.classList.toggle("hidden", show)
    }
  }

  setLocalStatus(text, tone) {
    if (!this.hasLocalStatusTarget) return
    this.localStatusTarget.textContent = text
    const tones = {
      emerald: "border-primary-border bg-primary-soft text-on-primary-soft",
      amber: "border-warning-border bg-warning-soft text-on-warning-soft",
      slate: "border-outline-variant bg-inset text-on-surface-variant"
    }
    this.localStatusTarget.className = `inline-flex max-w-full items-center rounded-[6px] border px-2 py-0.5 text-[11px] font-medium ${tones[tone] || tones.slate}`
  }

  subscribeToRoom() {
    this.subscription = this.consumer.subscriptions.create(
      { channel: "MeetingChannel", meeting_id: this.meetingIdValue, client_id: this.clientId },
      {
        connected: () => {
          if (!this.callActive) return
          this.leaveSent = false
          this.subscription.perform("join", {
            client_id: this.clientId,
            audio_enabled: this.audioEnabled,
            video_enabled: this.videoEnabled,
            screen_sharing: this.screenSharing
          })
        },
        received: (data) => this.handleCableMessage(data)
      }
    )
  }

  handleCableMessage(data) {
    if (!data || data.sender_id === this.clientId) return

    switch (data.type) {
      case "peer_joined":
        if (this.callActive) this.onPeerJoined(data)
        break
      case "signal":
        if (this.callActive) this.onSignalReceived(data)
        break
      case "media_state":
        this.onMediaStateUpdated(data)
        break
      case "transcript_chunk":
        this.onRemoteTranscriptChunk(data)
        break
      case "peer_left":
        this.removePeer(data.sender_id)
        break
      case "call_ended":
        this.leaveCall({
          reason: `Panggilan rapat telah diakhiri oleh ${data.ended_by || "Host"}.`
        })
        this.activateRightTab("summary")
        break
    }
  }

  updatePeerMediaState(peerId, data) {
    if (!data) return this.peerMediaStates.get(peerId) || {}
    const prev = this.peerMediaStates.get(peerId) || {
      audio_enabled: true,
      video_enabled: false,
      screen_sharing: false
    }
    const next = { ...prev }
    if (typeof data.audio_enabled === "boolean") next.audio_enabled = data.audio_enabled
    if (typeof data.video_enabled === "boolean") next.video_enabled = data.video_enabled
    if (typeof data.screen_sharing === "boolean") next.screen_sharing = data.screen_sharing
    this.peerMediaStates.set(peerId, next)
    return next
  }

  onPeerJoined(data) {
    const peerId = data.sender_id
    if (data.target_id && data.target_id !== this.clientId) return

    // If a peer freshly rejoined (!data.target_id), reset any stale connection so fresh tracks negotiate
    if (!data.target_id && this.peers.has(peerId)) {
      const stale = this.peers.get(peerId)
      stale.pc.close()
      this.peers.delete(peerId)
      this.pendingCandidates.delete(peerId)
      const staleTile = this.peersGridTarget?.querySelector(`[data-peer-id="${peerId}"]`)
      if (staleTile) {
        const videoEl = staleTile.querySelector("video")
        const audioEl = staleTile.querySelector("audio")
        if (videoEl) videoEl.srcObject = null
        if (audioEl) audioEl.srcObject = null
      }
    }

    const mediaState = this.updatePeerMediaState(peerId, data)
    this.ensurePeerTile(peerId, data.user, mediaState)

    // Reply once when someone new joins so both sides discover each other
    if (!data.target_id) {
      this.subscription.perform("join", {
        client_id: this.clientId,
        target_id: peerId,
        audio_enabled: this.audioEnabled,
        video_enabled: this.videoEnabled,
        screen_sharing: this.screenSharing
      })
    }

    // Deterministic tie-breaker to prevent offer glare even across 2 tabs
    if (this.clientId < peerId) {
      this.createOfferForPeer(peerId, data.user)
    }
  }

  getIceServers() {
    return Array.isArray(this.iceServersValue) && this.iceServersValue.length > 0
      ? this.iceServersValue
      : DEFAULT_ICE_SERVERS
  }

  ensurePeerEntry(peerId, userMeta) {
    const existing = this.peers.get(peerId)
    if (existing) {
      if (userMeta) existing.user = userMeta
      return existing
    }

    const pc = new RTCPeerConnection({ iceServers: this.getIceServers() })
    const peerState = {
      pc,
      user: userMeta,
      remoteStream: new MediaStream(),
      signalChain: Promise.resolve(),
      iceRestarted: false
    }
    this.peers.set(peerId, peerState)

    const activeStream = this.screenStream || this.localStream
    if (activeStream) {
      activeStream.getTracks().forEach((track) => pc.addTrack(track, activeStream))
    }

    pc.onicecandidate = (event) => {
      if (event.candidate) {
        this.subscription?.perform("signal", {
          client_id: this.clientId,
          target_id: peerId,
          signal_type: "ice_candidate",
          payload: event.candidate.toJSON()
        })
      }
    }

    pc.ontrack = (event) => {
      const mediaState = this.peerMediaStates.get(peerId) || {}
      const tile = this.ensurePeerTile(peerId, peerState.user, mediaState)
      const videoEl = tile.querySelector("video")
      const audioEl = tile.querySelector("audio")
      const stream = event.streams[0]

      if (stream) {
        peerState.remoteStream = stream
      } else {
        peerState.remoteStream
          .getTracks()
          .filter((t) => t.kind === event.track.kind && t.readyState === "ended")
          .forEach((t) => peerState.remoteStream.removeTrack(t))
        peerState.remoteStream.addTrack(event.track)
      }

      if (event.track.kind === "video" && videoEl) {
        videoEl.muted = true
        if (videoEl.srcObject !== peerState.remoteStream) {
          videoEl.srcObject = peerState.remoteStream
        }
        this.bindRemoteVideoEvents(tile, peerId, videoEl, event.track)
        videoEl.play().catch(() => {})
        this.syncPeerVideoVisibility(tile, peerId)
      }

      if (event.track.kind === "audio" && audioEl) {
        audioEl.srcObject = new MediaStream([ event.track ])
        audioEl.play().catch(() => { this.pendingAudioUnlock = true })
      }
    }

    const handleConnectionUpdate = () => {
      const tile = this.peersGridTarget?.querySelector(`[data-peer-id="${peerId}"]`)
      if (tile) this.syncPeerVideoVisibility(tile, peerId)

      const iceState = pc.iceConnectionState
      const connState = pc.connectionState
      if (iceState === "connected" || iceState === "completed" || connState === "connected") {
        peerState.iceRestarted = false
      } else if ((iceState === "failed" || connState === "failed") && !peerState.iceRestarted) {
        peerState.iceRestarted = true
        if (this.clientId < peerId) {
          this.createOfferForPeer(peerId, peerState.user, { iceRestart: true })
        }
      }
    }

    pc.oniceconnectionstatechange = handleConnectionUpdate
    pc.onconnectionstatechange = handleConnectionUpdate

    return peerState
  }

  ensurePeerConnection(peerId, userMeta) {
    return this.ensurePeerEntry(peerId, userMeta).pc
  }

  bindRemoteVideoEvents(tile, peerId, videoEl, track) {
    if (!videoEl.dataset.boundSync) {
      videoEl.dataset.boundSync = "true"
      const sync = () => this.syncPeerVideoVisibility(tile, peerId)
      videoEl.addEventListener("loadedmetadata", sync)
      videoEl.addEventListener("loadeddata", sync)
      videoEl.addEventListener("playing", sync)
      videoEl.addEventListener("resize", sync)
    }

    if (!track.datasetBoundSync) {
      track.datasetBoundSync = true
      const sync = () => this.syncPeerVideoVisibility(tile, peerId)
      track.addEventListener("unmute", sync)
      track.addEventListener("mute", sync)
      track.addEventListener("ended", sync)
    }
  }

  async createOfferForPeer(peerId, userMeta, options = {}) {
    const peerState = this.ensurePeerEntry(peerId, userMeta)
    peerState.signalChain = peerState.signalChain
      .catch(() => {})
      .then(async () => {
        const { pc } = peerState
        if (pc.signalingState === "closed") return
        try {
          const offer = await pc.createOffer({
            offerToReceiveAudio: true,
            offerToReceiveVideo: true,
            iceRestart: Boolean(options.iceRestart)
          })
          await pc.setLocalDescription(offer)
          this.subscription?.perform("signal", {
            client_id: this.clientId,
            target_id: peerId,
            signal_type: "offer",
            payload: pc.localDescription.toJSON(),
            audio_enabled: this.audioEnabled,
            video_enabled: this.videoEnabled,
            screen_sharing: this.screenSharing
          })
        } catch (error) {
          console.error("WebRTC offer error:", error)
        }
      })
    return peerState.signalChain
  }

  onSignalReceived(data) {
    if (data.target_id !== this.clientId) return

    const peerId = data.sender_id
    const peerState = this.ensurePeerEntry(peerId, data.user)
    if (data.signal_type === "offer" || data.signal_type === "answer") {
      const mediaState = this.updatePeerMediaState(peerId, data)
      this.ensurePeerTile(peerId, data.user, mediaState)
    } else {
      this.ensurePeerTile(peerId, data.user, this.peerMediaStates.get(peerId) || {})
    }

    peerState.signalChain = peerState.signalChain
      .catch(() => {})
      .then(() => this.processSignal(data, peerId, peerState))
  }

  async processSignal(data, peerId, peerState) {
    const { pc } = peerState
    if (pc.signalingState === "closed") return

    try {
      if (data.signal_type === "offer") {
        if (pc.signalingState !== "stable") {
          const polite = this.clientId > peerId
          if (!polite) return
          await pc.setLocalDescription({ type: "rollback" })
        }
        await pc.setRemoteDescription(new RTCSessionDescription(data.payload))
        await this.flushCandidates(peerId, pc)
        const answer = await pc.createAnswer()
        await pc.setLocalDescription(answer)
        this.subscription?.perform("signal", {
          client_id: this.clientId,
          target_id: peerId,
          signal_type: "answer",
          payload: pc.localDescription.toJSON(),
          audio_enabled: this.audioEnabled,
          video_enabled: this.videoEnabled,
          screen_sharing: this.screenSharing
        })
      } else if (data.signal_type === "answer") {
        if (pc.signalingState !== "have-local-offer") return
        await pc.setRemoteDescription(new RTCSessionDescription(data.payload))
        await this.flushCandidates(peerId, pc)
      } else if (data.signal_type === "ice_candidate" && data.payload) {
        if (pc.remoteDescription) {
          await pc.addIceCandidate(new RTCIceCandidate(data.payload)).catch(() => {})
        } else {
          const queue = this.pendingCandidates.get(peerId) || []
          queue.push(data.payload)
          this.pendingCandidates.set(peerId, queue)
        }
      }
    } catch (error) {
      console.error("WebRTC signal error:", error)
    }
  }

  async flushCandidates(peerId, pc) {
    const queue = this.pendingCandidates.get(peerId) || []
    this.pendingCandidates.delete(peerId)
    for (const candidate of queue) {
      try {
        await pc.addIceCandidate(new RTCIceCandidate(candidate))
      } catch (_candidateErr) {
        // Ignore stale candidates from superseded ICE generations
      }
    }
  }

  onMediaStateUpdated(data) {
    const mediaState = this.updatePeerMediaState(data.sender_id, data)
    const tile = this.peersGridTarget?.querySelector(`[data-peer-id="${data.sender_id}"]`)
    if (!tile) return
    this.applyTileMediaBadges(tile, mediaState)
  }

  ensurePeerTile(peerId, userMeta, state = {}) {
    let tile = this.peersGridTarget.querySelector(`[data-peer-id="${peerId}"]`)
    if (tile) {
      this.applyTileMediaBadges(tile, state)
      return tile
    }

    const name = userMeta?.full_name || "Peserta Tim"
    const initials = userMeta?.initials || "TM"
    const roleLabel = userMeta?.role_label || "Anggota"

    tile = document.createElement("div")
    tile.dataset.peerId = peerId
    tile.className = "relative aspect-video lg:aspect-auto lg:min-h-[220px] overflow-hidden rounded-[12px] border border-outline-variant bg-column shadow-2xs"
    tile.innerHTML = `
      <video muted autoplay playsinline class="hidden h-full w-full object-cover"></video>
      <audio autoplay playsinline class="hidden"></audio>
      <div data-peer-placeholder class="flex h-full w-full flex-col items-center justify-center bg-inset p-4 pb-10 text-center">
        <div class="flex h-12 w-12 items-center justify-center rounded-xl border border-outline bg-card font-display text-base font-semibold text-on-surface">${this.escapeHtml(initials)}</div>
        <p class="mt-2 text-xs font-semibold text-on-surface">${this.escapeHtml(name)}</p>
        <p class="text-[11px] text-on-surface-muted">${this.escapeHtml(roleLabel)}</p>
        <p data-peer-connection-status class="mt-1.5 text-[10px] font-medium text-on-surface-muted empty:hidden"></p>
      </div>
      <div class="absolute left-2.5 bottom-2.5 inline-flex max-w-[calc(100%-1.25rem)] items-center gap-1.5 rounded-full bg-inverse-surface/85 px-2.5 py-1 text-[11px] font-medium text-inverse-on-surface backdrop-blur-xs">
        <span class="truncate">${this.escapeHtml(name)}</span>
        <span data-peer-badges class="shrink-0 font-mono text-[10px] opacity-85"></span>
      </div>
    `

    this.peersGridTarget.appendChild(tile)
    this.applyTileMediaBadges(tile, state)
    this.updateParticipantCount()
    return tile
  }

  applyTileMediaBadges(tile, state = {}) {
    const peerId = tile.dataset.peerId
    const effective = { ...(this.peerMediaStates.get(peerId) || {}), ...state }
    const badgeEl = tile.querySelector("[data-peer-badges]")
    if (badgeEl) {
      const badges = []
      badges.push(effective.audio_enabled === false ? "Mute" : "Mic On")
      if (effective.screen_sharing) {
        badges.push("Share Screen")
      } else {
        badges.push(effective.video_enabled ? "Cam On" : "Cam Off")
      }
      badgeEl.textContent = badges.join(" · ")
    }

    this.syncPeerVideoVisibility(tile, peerId)
  }

  syncPeerVideoVisibility(tile, peerId) {
    const videoEl = tile.querySelector("video")
    const placeholderEl = tile.querySelector("[data-peer-placeholder]")
    const statusEl = tile.querySelector("[data-peer-connection-status]")
    const state = this.peerMediaStates.get(peerId) || {}
    const peerState = this.peers.get(peerId)
    const pc = peerState?.pc

    const wantsVideo = Boolean(state.video_enabled || state.screen_sharing)
    const videoTrack = videoEl?.srcObject?.getVideoTracks()?.find((t) => t.readyState === "live")
    const hasRenderableFrames = Boolean(
      videoTrack && !videoTrack.muted && (videoEl.videoWidth > 0 || videoEl.readyState >= 2)
    )

    if (wantsVideo && hasRenderableFrames) {
      videoEl?.classList.remove("hidden")
      placeholderEl?.classList.add("hidden")
      if (statusEl) statusEl.textContent = ""
      if (videoEl?.paused) videoEl.play().catch(() => {})
      return
    }

    videoEl?.classList.add("hidden")
    placeholderEl?.classList.remove("hidden")

    if (!statusEl) return
    if (wantsVideo) {
      const iceState = pc?.iceConnectionState
      const connState = pc?.connectionState
      if (iceState === "failed" || connState === "failed") {
        statusEl.textContent = "Video P2P gagal (jaringan butuh TURN server)"
      } else if (iceState === "disconnected" || connState === "disconnected") {
        statusEl.textContent = "Menyambung ulang video..."
      } else {
        statusEl.textContent = "Menghubungkan video..."
      }
    } else {
      statusEl.textContent = ""
    }
  }

  removePeer(peerId) {
    const peerState = this.peers.get(peerId)
    if (peerState) {
      peerState.pc.close()
      this.peers.delete(peerId)
    }
    this.peerMediaStates.delete(peerId)
    this.pendingCandidates.delete(peerId)
    this.peersGridTarget?.querySelector(`[data-peer-id="${peerId}"]`)?.remove()
    this.updateParticipantCount()
  }

  closeAllPeers() {
    this.peers.forEach((peerState) => peerState.pc.close())
    this.peers.clear()
  }

  updateParticipantCount() {
    const remoteCount = this.peersGridTarget ? this.peersGridTarget.querySelectorAll("[data-peer-id]").length : 0
    const total = this.callActive ? remoteCount + 1 : remoteCount
    if (this.hasParticipantCountTarget) {
      this.participantCountTarget.textContent = this.callActive ? `${total} Online` : "Di luar call"
    }
    if (this.hasEmptyStateTarget) {
      this.emptyStateTarget.classList.toggle("hidden", remoteCount > 0)
    }
  }

  async toggleMic() {
    await this.toggleDeviceTrack("audio")
  }

  async toggleCam() {
    await this.toggleDeviceTrack("video")
  }

  async toggleDeviceTrack(kind) {
    if (!this.callActive) return

    const tracks = this.liveTracks(kind)
    if (tracks.length === 0) {
      await this.enableDeviceTrack(kind)
      return
    }

    const enabled = kind === "video" ? !this.videoEnabled : !this.audioEnabled
    if (kind === "video") {
      this.videoEnabled = enabled
      if (!this.screenSharing) {
        this.showLocalPlaceholder(!this.videoEnabled)
      }
    } else {
      this.audioEnabled = enabled
    }

    tracks.forEach((track) => { track.enabled = enabled })
    this.refreshLocalStatusSummary()
    this.broadcastMediaState()
    this.updateMediaButtons()
  }

  async enableDeviceTrack(kind) {
    if (this.acquiringDevices.has(kind)) return
    this.acquiringDevices.add(kind)

    const isVideo = kind === "video"
    const label = isVideo ? "Kamera" : "Mikrofon"

    try {
      if (!window.isSecureContext) {
        const msg = `${label} membutuhkan koneksi HTTPS atau http://localhost.`
        this.setLocalStatus(msg, "amber")
        this.setLiveCaption(msg, "amber")
        return
      }
      if (!navigator.mediaDevices?.getUserMedia) {
        const msg = `Browser ini tidak mendukung akses ${label.toLowerCase()}.`
        this.setLocalStatus(msg, "amber")
        this.setLiveCaption(msg, "amber")
        return
      }

      const stream = await navigator.mediaDevices.getUserMedia(isVideo ? { video: true } : { audio: true })
      const track = isVideo ? stream.getVideoTracks()[0] : stream.getAudioTracks()[0]
      if (!track) {
        throw new DOMException(`${label} tidak tersedia`, "NotFoundError")
      }

      this.localStream = this.localStream || new MediaStream()
      const staleTracks = isVideo ? this.localStream.getVideoTracks() : this.localStream.getAudioTracks()
      staleTracks.forEach((oldTrack) => {
        oldTrack.onended = null
        if (oldTrack !== track) {
          this.localStream.removeTrack(oldTrack)
          try { oldTrack.stop() } catch (_e) {}
        }
      })

      this.localStream.addTrack(track)
      track.onended = () => this.handleLocalTrackEnded(kind)

      if (isVideo) {
        this.lastVideoError = null
        this.videoEnabled = true
        if (!this.screenSharing) {
          this.attachLocalVideo(this.localStream)
          this.showLocalPlaceholder(false)
          await this.attachOrReplaceOutgoingTrack("video", track, this.localStream)
        }
      } else {
        this.lastAudioError = null
        this.audioEnabled = true
        await this.attachOrReplaceOutgoingTrack("audio", track, this.localStream)
      }

      this.refreshLocalStatusSummary()
      this.broadcastMediaState()
    } catch (error) {
      if (isVideo) {
        this.lastVideoError = error
        this.videoEnabled = false
      } else {
        this.lastAudioError = error
        this.audioEnabled = false
      }
      const msg = this.describeDeviceFailure(label, error)
      this.setLocalStatus(msg, "amber")
      this.setLiveCaption(msg, "amber")
    } finally {
      this.acquiringDevices.delete(kind)
      this.updateMediaButtons()
    }
  }

  toggleMirror() {
    this.mirrorEnabled = !this.mirrorEnabled
    try {
      window.localStorage?.setItem("syncboard_mirror_cam", String(this.mirrorEnabled))
    } catch (_e) {}
    this.applyLocalMirrorTransform()
    this.updateMediaButtons()
  }

  async toggleCall() {
    if (!this.callActive) {
      await this.rejoinCall()
      return
    }

    if (this.isHostValue && this.hasEndCallModalTarget) {
      this.openEndCallModal()
    } else {
      this.leaveCall()
    }
  }

  openEndCallModal() {
    if (this.hasEndCallModalTarget) {
      this.endCallModalTarget.classList.remove("hidden")
    }
  }

  closeEndCallModal() {
    if (this.hasEndCallModalTarget) {
      this.endCallModalTarget.classList.add("hidden")
    }
  }

  handleKeydown(event) {
    if (event.key === "Escape") {
      this.closeEndCallModal()
    }
  }

  leaveCallAndCloseModal() {
    this.closeEndCallModal()
    this.leaveCall()
  }

  leaveCall(options = {}) {
    this.sendLeaveSignal()
    this.callActive = false
    this.stopSpeechRecognition({ preserveCaption: true })
    this.stopAllMediaStreams()
    this.closeAllPeers()
    this.peerMediaStates.clear()
    this.pendingCandidates.clear()
    if (this.peersGridTarget) {
      this.peersGridTarget.innerHTML = ""
    }
    this.showLocalPlaceholder(true)
    this.setLocalStatus(
      options.reason || "Anda telah keluar dari panggilan (kamera & mikrofon mati)",
      "slate"
    )
    if (options.reason) {
      this.setLiveCaption(options.reason, "amber")
    }
    this.updateMediaButtons()
    this.updateParticipantCount()
  }

  async rejoinCall() {
    this.callActive = true
    this.leaveSent = false
    await this.acquireLocalMedia()
    this.subscription?.perform("join", {
      client_id: this.clientId,
      audio_enabled: this.audioEnabled,
      video_enabled: this.videoEnabled,
      screen_sharing: this.screenSharing
    })
    this.updateMediaButtons()
    this.updateParticipantCount()
  }

  endMeetingSession(event) {
    if (this.saveTimer) {
      clearTimeout(this.saveTimer)
      this.saveTimer = null
    }
    if (this.hasTranscriptInputTarget) {
      const hiddenField = event?.currentTarget?.querySelector("[data-meeting-room-target='endCallTranscriptField']") ||
        (this.hasEndCallTranscriptFieldTarget ? this.endCallTranscriptFieldTarget : null)
      if (hiddenField) hiddenField.value = this.transcriptInputTarget.value
    }
    this.closeEndCallModal()
    this.leaveCall({ reason: "Mengakhiri panggilan untuk semua peserta..." })
  }

  syncTranscriptBeforeGenerate(event) {
    if (this.saveTimer) {
      clearTimeout(this.saveTimer)
      this.saveTimer = null
    }
    if (!this.hasTranscriptInputTarget) return

    const latest = this.transcriptInputTarget.value
    const field = event?.currentTarget?.querySelector("[data-meeting-room-target='summaryTranscriptField']")
    if (field) {
      field.value = latest
    } else if (this.hasSummaryTranscriptFieldTarget) {
      this.summaryTranscriptFieldTargets.forEach((el) => { el.value = latest })
    }
  }

  onSummaryGenerated(event) {
    if (event?.detail?.success) {
      this.activateRightTab("summary")
    }
  }

  async toggleScreenShare() {
    if (this.screenSharing) {
      this.stopScreenShare()
      return
    }
    if (!navigator.mediaDevices?.getDisplayMedia) return

    try {
      this.screenStream = await navigator.mediaDevices.getDisplayMedia({ video: true, audio: false })
      this.screenSharing = true
      const screenTrack = this.screenStream.getVideoTracks()[0]

      this.replaceOutgoingVideoTrack(screenTrack)
      this.attachLocalVideo(this.screenStream)
      this.showLocalPlaceholder(false)

      screenTrack.onended = () => this.stopScreenShare()

      this.broadcastMediaState()
      this.updateMediaButtons()
    } catch (_err) {
      // User cancelled screen share prompt
    }
  }

  stopScreenShare() {
    if (!this.screenSharing) return
    if (this.screenStream) {
      this.screenStream.getTracks().forEach((track) => track.stop())
      this.screenStream = null
    }
    this.screenSharing = false

    const camTrack = this.liveTracks("video")[0] || null
    this.replaceOutgoingVideoTrack(camTrack)

    if (camTrack && this.videoEnabled) {
      this.attachLocalVideo(this.localStream)
      this.showLocalPlaceholder(false)
    } else {
      this.videoEnabled = false
      if (this.hasLocalVideoTarget) {
        this.localVideoTarget.srcObject = this.localStream || null
      }
      this.applyLocalMirrorTransform()
      this.showLocalPlaceholder(true)
    }

    this.broadcastMediaState()
    this.updateMediaButtons()
  }

  replaceOutgoingVideoTrack(newTrack) {
    const stream = this.screenStream || this.localStream
    return this.attachOrReplaceOutgoingTrack("video", newTrack, stream)
  }

  async attachOrReplaceOutgoingTrack(kind, newTrack, stream) {
    const updates = []
    this.peers.forEach((peerState, peerId) => {
      updates.push(this.syncOutgoingTrackForPeer(peerId, peerState, kind, newTrack, stream))
    })
    await Promise.all(updates)
  }

  async syncOutgoingTrackForPeer(peerId, peerState, kind, newTrack, stream) {
    const { pc } = peerState
    if (pc.signalingState === "closed") return

    const transceiver = pc.getTransceivers().find(
      (t) => t.sender?.track?.kind === kind || t.receiver?.track?.kind === kind
    )

    let needsRenegotiate = false
    if (transceiver) {
      if (newTrack && (transceiver.direction === "recvonly" || transceiver.direction === "inactive")) {
        transceiver.direction = "sendrecv"
        needsRenegotiate = true
      }
      await transceiver.sender.replaceTrack(newTrack).catch(() => {})
    } else if (newTrack && stream) {
      pc.addTrack(newTrack, stream)
      needsRenegotiate = true
    }

    if (needsRenegotiate) {
      await this.createOfferForPeer(peerId, peerState.user)
    }
  }

  broadcastMediaState() {
    this.subscription?.perform("media_state", {
      client_id: this.clientId,
      audio_enabled: this.audioEnabled,
      video_enabled: this.videoEnabled,
      screen_sharing: this.screenSharing
    })
  }

  setDockButtonContent(button, iconName, labelText) {
    const iconEl = button.querySelector('[data-role="icon"]')
    const labelEl = button.querySelector('[data-role="label"]')
    if (iconEl) {
      const pathData = DOCK_ICON_PATHS[iconName]
      if (pathData) {
        const size = iconEl.dataset.iconSize || "18"
        const svgNs = "http://www.w3.org/2000/svg"
        const svg = document.createElementNS(svgNs, "svg")
        svg.setAttribute("viewBox", "0 0 24 24")
        svg.setAttribute("width", size)
        svg.setAttribute("height", size)
        svg.setAttribute("fill", "currentColor")
        svg.setAttribute("class", "shrink-0 inline-block")
        svg.setAttribute("aria-hidden", "true")

        const path = document.createElementNS(svgNs, "path")
        path.setAttribute("d", pathData)
        svg.appendChild(path)
        iconEl.replaceChildren(svg)
      } else {
        iconEl.textContent = iconName
      }
    }
    if (labelEl) {
      labelEl.textContent = labelText
    } else {
      button.textContent = labelText
    }
    button.setAttribute("title", labelText)
    button.setAttribute("aria-label", labelText)
  }

  updateMediaButtons() {
    const circleBase = "inline-flex h-11 w-11 sm:h-9 sm:w-9 items-center justify-center rounded-full transition focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"

    if (this.hasMicButtonTarget) {
      const hasMic = this.liveTracks("audio").length > 0
      const micOn = hasMic && this.audioEnabled
      this.micButtonTarget.disabled = !this.callActive
      this.setDockButtonContent(
        this.micButtonTarget,
        micOn ? "mic" : "mic_off",
        micOn ? "Mic Aktif" : (hasMic ? "Mic Mute" : "Nyalakan Mic")
      )
      this.micButtonTarget.className = `${circleBase} ${
        !this.callActive
          ? "bg-white/10 text-white/40 cursor-not-allowed"
          : micOn
            ? "bg-white/15 text-inverse-on-surface hover:bg-white/25 cursor-pointer"
            : "bg-danger text-on-danger hover:bg-danger-hover cursor-pointer"
      }`
    }

    if (this.hasCamButtonTarget) {
      const hasCam = this.liveTracks("video").length > 0
      const camOn = hasCam && this.videoEnabled
      this.camButtonTarget.disabled = !this.callActive
      this.setDockButtonContent(
        this.camButtonTarget,
        camOn ? "videocam" : "videocam_off",
        camOn ? "Cam Aktif" : (hasCam ? "Cam Off" : "Nyalakan Kamera")
      )
      this.camButtonTarget.className = `${circleBase} ${
        !this.callActive
          ? "bg-white/10 text-white/40 cursor-not-allowed"
          : camOn
            ? "bg-white/15 text-inverse-on-surface hover:bg-white/25 cursor-pointer"
            : "bg-danger text-on-danger hover:bg-danger-hover cursor-pointer"
      }`
    }

    if (this.hasScreenButtonTarget) {
      this.screenButtonTarget.disabled = !this.callActive
      this.setDockButtonContent(
        this.screenButtonTarget,
        this.screenSharing ? "stop_screen_share" : "present_to_all",
        this.screenSharing ? "Stop Share" : "Share Screen"
      )
      this.screenButtonTarget.className = `${circleBase} ${
        !this.callActive
          ? "bg-white/10 text-white/40 cursor-not-allowed"
          : this.screenSharing
            ? "bg-primary text-on-primary hover:bg-primary-hover cursor-pointer"
            : "bg-white/15 text-inverse-on-surface hover:bg-white/25 cursor-pointer"
      }`
    }

    if (this.hasMirrorButtonTarget) {
      const mirrorDisabled = !this.callActive || this.screenSharing
      this.mirrorButtonTarget.disabled = mirrorDisabled
      this.setDockButtonContent(
        this.mirrorButtonTarget,
        "flip",
        this.mirrorEnabled ? "Flip Cam: ON" : "Flip Cam: OFF"
      )
      this.mirrorButtonTarget.className = `${circleBase} ${
        mirrorDisabled
          ? "bg-white/10 text-white/40 cursor-not-allowed"
          : this.mirrorEnabled
            ? "bg-white/15 text-inverse-on-surface hover:bg-white/25 cursor-pointer"
            : "bg-white/8 text-inverse-on-surface/75 hover:bg-white/20 cursor-pointer"
      }`
    }

    if (this.hasCallButtonTarget) {
      const callLabel = this.callActive
        ? (this.isHostValue ? "Akhiri Panggilan" : "Keluar dari Panggilan")
        : "Gabung Panggilan"
      this.setDockButtonContent(
        this.callButtonTarget,
        this.callActive ? "call_end" : "call",
        callLabel
      )
      this.callButtonTarget.className = `inline-flex h-11 sm:h-9 items-center justify-center gap-1.5 rounded-full px-3.5 text-xs font-semibold transition cursor-pointer focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary ${
        this.callActive
          ? "bg-danger text-on-danger hover:bg-danger-hover"
          : "bg-primary text-on-primary hover:bg-primary-hover"
      }`
    }
  }

  async toggleSpeechRecognition() {
    if (this.recognizing) {
      this.stopSpeechRecognition()
      return
    }

    if (!window.isSecureContext) {
      this.setLiveCaption(
        "Live Speech-to-Text membutuhkan HTTPS atau http://localhost (saat ini halaman tidak di Secure Context).",
        "rose"
      )
      return
    }

    const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition
    if (!SpeechRecognition) {
      this.setLiveCaption(
        "Browser Anda tidak mendukung Web Speech Recognition. Gunakan Google Chrome/Edge atau ketik pada Quick Caption / Transcript di bawah.",
        "amber"
      )
      return
    }

    const isBrave = await this.detectBraveBrowser()

    try {
      this.recognition = new SpeechRecognition()
      this.recognition.lang = "id-ID"
      this.recognition.continuous = true
      this.recognition.interimResults = true
      this.speechErrorMessage = null

      this.recognition.onstart = () => {
        this.setLiveCaption("Mendengarkan suara Anda (id-ID)... silakan bicara ke mikrofon.", "emerald")
      }

      this.recognition.onresult = (event) => {
        let interimText = ""
        for (let i = event.resultIndex; i < event.results.length; i++) {
          const result = event.results[i]
          const text = result[0].transcript.trim()
          if (result.isFinal && text) {
            this.appendTranscriptLine(`${this.userNameValue}: ${text}`)
            this.subscription?.perform("transcript_chunk", {
              client_id: this.clientId,
              text
            })
            this.setLiveCaption(`${this.userNameValue}: ${text}`, "slate")
          } else {
            interimText += `${text} `
          }
        }
        if (interimText.trim()) {
          this.setLiveCaption(`${this.userNameValue}: ${interimText.trim()}...`, "indigo")
        }
      }

      this.recognition.onerror = (event) => {
        if (event.error === "no-speech") {
          this.setLiveCaption("Tidak ada suara terdeteksi... terus mendengarkan.", "slate")
          return
        }

        if (event.error === "aborted" && !this.recognizing) return

        this.speechErrorMessage = this.describeSpeechError(event.error, isBrave)
        this.stopSpeechRecognition({ preserveCaption: true })
        this.setLiveCaption(this.speechErrorMessage, "amber")
      }

      this.recognition.onend = () => {
        if (this.recognizing && !this.speechErrorMessage) {
          try {
            this.recognition.start()
          } catch (_e) {
            this.stopSpeechRecognition()
          }
        }
      }

      this.recognizing = true
      this.updateSpeechButton()
      this.recognition.start()
    } catch (error) {
      this.stopSpeechRecognition({ preserveCaption: true })
      this.setLiveCaption(
        `Gagal memulai Speech-to-Text (${error.message}). Gunakan Quick Caption atau ketik manual di kolom Transcript.`,
        "amber"
      )
    }
  }

  async detectBraveBrowser() {
    try {
      if (navigator.brave && typeof navigator.brave.isBrave === "function") {
        return await navigator.brave.isBrave()
      }
    } catch (_e) {}
    return false
  }

  describeSpeechError(code, isBrave) {
    switch (code) {
      case "network":
        if (isBrave) {
          return "Browser Brave memblokir server Speech-to-Text Google (error: network). Buka di Google Chrome/Microsoft Edge untuk dikte suara live, atau gunakan Quick Caption di bawah."
        }
        return "Layanan Web Speech API butuh koneksi internet ke server speech browser (error: network). Anda tetap bisa menggunakan Quick Caption atau ketik manual."
      case "not-allowed":
      case "service-not-allowed":
        return isBrave
          ? "Brave menonaktifkan Web Speech API demi privasi. Gunakan Chrome/Edge atau Quick Caption di bawah."
          : "Izin mikrofon ditolak browser. Klik ikon gembok di address bar, lalu izinkan Mikrofon dan coba lagi."
      case "audio-capture":
        return "Mikrofon tidak terdeteksi atau sedang dipakai aplikasi lain."
      case "language-not-supported":
        return "Bahasa Indonesia (id-ID) belum didukung di sistem speech browser ini."
      default:
        return `Speech-to-Text terhenti (${code}). Silakan lanjutkan via Quick Caption atau kolom Transcript.`
    }
  }

  setLiveCaption(message, tone = "slate") {
    if (!this.hasLiveCaptionsTarget) return
    const tones = {
      slate: "border-outline-variant bg-inset text-on-surface-variant",
      emerald: "border-primary-border bg-primary-soft text-on-primary-soft",
      indigo: "border-outline bg-card text-on-surface",
      amber: "border-warning-border bg-warning-soft text-on-warning-soft",
      rose: "border-danger-border bg-danger-soft text-on-danger-soft"
    }
    this.liveCaptionsTarget.className = `sm:col-span-7 min-w-0 truncate rounded-[10px] border px-3 py-2 text-xs ${tones[tone] || tones.slate}`
    this.liveCaptionsTarget.textContent = message
  }

  stopSpeechRecognition(options = {}) {
    this.recognizing = false
    if (this.recognition) {
      this.recognition.onend = null
      try { this.recognition.stop() } catch (_e) {}
      this.recognition = null
    }
    this.updateSpeechButton()
    if (!options.preserveCaption) {
      this.setLiveCaption("Live Speech-to-Text dimatikan. Ketik poin rapat di Quick Caption atau kolom Transcript.", "slate")
    }
  }

  selectCaptionTag(event) {
    const tag = event.currentTarget.dataset.tag || "point"
    this.activeCaptionTag = tag

    if (this.hasCaptionTagButtonTarget) {
      this.captionTagButtonTargets.forEach((button) => {
        const active = button.dataset.tag === tag
        button.setAttribute("aria-pressed", active ? "true" : "false")
        button.className = active
          ? "rounded-[8px] bg-panel px-2 py-1 text-[11px] font-semibold text-on-surface shadow-xs transition cursor-pointer"
          : "rounded-[8px] px-2 py-1 text-[11px] font-semibold text-on-surface-muted hover:text-on-surface transition cursor-pointer"
      })
    }

    if (this.hasQuickCaptionInputTarget) {
      const placeholders = {
        point: "Catat poin atau tandai highlight...",
        decision: "Tulis keputusan rapat...",
        action: "Tulis aksi/task (misal: Fix login untuk Raka besok)...",
        blocker: "Tulis blocker atau risiko..."
      }
      this.quickCaptionInputTarget.placeholder = placeholders[tag] || placeholders.point
      this.quickCaptionInputTarget.focus()
    }
  }

  captionPrefixForTag(tag) {
    const prefixes = {
      decision: "[KEPUTUSAN] ",
      action: "[AKSI] ",
      blocker: "[BLOCKER] "
    }
    return prefixes[tag] || ""
  }

  formatTaggedCaptionLine(speaker, text, tag = "point") {
    return `${this.captionPrefixForTag(tag)}${speaker}: ${text}`
  }

  submitQuickCaption(event) {
    event.preventDefault()
    if (!this.hasQuickCaptionInputTarget) return

    const text = this.quickCaptionInputTarget.value.trim()
    if (!text) return

    const tag = this.activeCaptionTag || "point"
    const formattedLine = this.formatTaggedCaptionLine(this.userNameValue, text, tag)

    this.appendTranscriptLine(formattedLine)
    this.subscription?.perform("transcript_chunk", {
      client_id: this.clientId,
      text,
      tag
    })
    this.setLiveCaption(formattedLine, tag === "blocker" || tag === "decision" ? "amber" : "indigo")
    this.quickCaptionInputTarget.value = ""
    this.quickCaptionInputTarget.focus()
  }

  updateSpeechButton() {
    if (!this.hasSpeechButtonTarget) return
    this.setDockButtonContent(
      this.speechButtonTarget,
      this.recognizing ? "graphic_eq" : "closed_caption",
      this.recognizing ? "Stop Live Captions" : "Live Speech-to-Text"
    )
    this.speechButtonTarget.className = `inline-flex h-11 w-11 sm:h-9 sm:w-9 items-center justify-center rounded-full transition cursor-pointer focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary ${
      this.recognizing
        ? "bg-primary text-on-primary hover:bg-primary-hover"
        : "bg-white/15 text-inverse-on-surface hover:bg-white/25"
    }`
  }

  switchRightTab(event) {
    const activeKey = event.currentTarget.dataset.meetingTab
    if (!activeKey) return
    this.activateRightTab(activeKey)
  }

  activateRightTab(activeKey) {
    if (!activeKey) return

    this.rightTabTargets.forEach((tab) => {
      const selected = tab.dataset.meetingTab === activeKey
      tab.setAttribute("aria-selected", selected ? "true" : "false")
      tab.className = `inline-flex min-h-11 sm:min-h-9 items-center justify-center gap-1.5 border-b-2 px-2 py-1.5 text-xs font-semibold transition cursor-pointer focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary ${
        selected
          ? "border-primary text-primary-text bg-panel"
          : "border-transparent text-on-surface-muted hover:text-on-surface hover:bg-hover/60"
      }`
    })

    this.rightPanelTargets.forEach((panel) => {
      panel.classList.toggle("hidden", panel.dataset.meetingPanel !== activeKey)
    })
  }

  onRemoteTranscriptChunk(data) {
    const line = this.formatTaggedCaptionLine(data.speaker, data.text, data.tag || "point")
    this.appendTranscriptLine(line, false)
    this.setLiveCaption(line, data.tag === "blocker" || data.tag === "decision" ? "amber" : "indigo")
  }

  appendTranscriptLine(line, shouldPersist = true) {
    if (!this.hasTranscriptInputTarget) return
    const current = this.transcriptInputTarget.value.trim()
    this.transcriptInputTarget.value = current ? `${current}\n${line}` : line
    if (shouldPersist) this.scheduleSaveTranscript()
  }

  scheduleSaveTranscript() {
    if (this.hasSaveStatusTarget) {
      this.saveStatusTarget.textContent = "Menyimpan perubahan..."
    }
    if (this.saveTimer) clearTimeout(this.saveTimer)
    this.saveTimer = setTimeout(() => this.saveTranscriptNow(), 900)
  }

  async saveTranscriptNow() {
    if (!this.hasTranscriptInputTarget || !this.saveTranscriptUrlValue) return
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

    try {
      const response = await fetch(this.saveTranscriptUrlValue, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": csrfToken || ""
        },
        body: JSON.stringify({ transcript_text: this.transcriptInputTarget.value })
      })

      if (response.ok) {
        const result = await response.json()
        if (this.hasSaveStatusTarget) {
          this.saveStatusTarget.textContent = `Tersimpan pukul ${result.updated_at}`
        }
      }
    } catch (_err) {
      if (this.hasSaveStatusTarget) {
        this.saveStatusTarget.textContent = "Gagal auto-save"
      }
    }
  }

  resetMessageForm(event) {
    if (event.detail.success && this.hasMessageBodyTarget) {
      this.messageBodyTarget.value = ""
      this.messageBodyTarget.focus()
    }
  }

  escapeHtml(str) {
    return String(str)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#39;")
  }
}

