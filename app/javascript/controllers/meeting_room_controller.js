import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

const DEFAULT_ICE_SERVERS = [
  { urls: "stun:stun.l.google.com:19302" },
  { urls: "stun:stun1.l.google.com:19302" },
  { urls: "stun:stun.cloudflare.com:3478" }
]

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
    this.pendingCandidates = new Map()
    this.localStream = null
    this.screenStream = null
    this.audioEnabled = true
    this.videoEnabled = true
    this.screenSharing = false
    this.callActive = false
    const savedMirror = window.localStorage?.getItem("syncboard_mirror_cam")
    this.mirrorEnabled = savedMirror === null ? true : savedMirror === "true"
    this.recognizing = false
    this.recognition = null
    this.saveTimer = null

    this.consumer = createConsumer()
    this.setupMediaAndJoin()
  }

  disconnect() {
    if (this.saveTimer) clearTimeout(this.saveTimer)
    this.stopSpeechRecognition({ preserveCaption: true })
    this.closeAllPeers()
    this.stopAllMediaStreams()
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
    if (this.consumer) {
      this.consumer.disconnect()
    }
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

  async acquireLocalMedia() {
    if (!navigator.mediaDevices?.getUserMedia) {
      this.audioEnabled = false
      this.videoEnabled = false
      this.setLocalStatus("Browser tidak mendukung WebRTC media; mode observer aktif.", "amber")
      this.showLocalPlaceholder(true)
      return
    }

    try {
      this.localStream = await navigator.mediaDevices.getUserMedia({ video: true, audio: true })
      this.audioEnabled = true
      this.videoEnabled = true
      this.attachLocalVideo(this.localStream)
      this.setLocalStatus("Kamera & Mikrofon aktif", "emerald")
      this.showLocalPlaceholder(false)
    } catch (_camAndMicErr) {
      try {
        this.localStream = await navigator.mediaDevices.getUserMedia({ audio: true })
        this.audioEnabled = true
        this.videoEnabled = false
        this.setLocalStatus("Hanya Audio (kamera sedang dipakai tab lain / tidak tersedia)", "amber")
        this.showLocalPlaceholder(true)
      } catch (_audioOnlyErr) {
        this.localStream = null
        this.audioEnabled = false
        this.videoEnabled = false
        this.setLocalStatus("Mode Observer (izinkan mic/kamera atau pakai Share Screen)", "slate")
        this.showLocalPlaceholder(true)
      }
    }
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
    this.localStatusTarget.className = `inline-flex items-center rounded-md border px-2.5 py-0.5 text-[11px] font-medium ${tones[tone] || tones.slate}`
  }

  subscribeToRoom() {
    this.subscription = this.consumer.subscriptions.create(
      { channel: "MeetingChannel", meeting_id: this.meetingIdValue, client_id: this.clientId },
      {
        connected: () => {
          if (!this.callActive) return
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
        break
    }
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
    }

    this.ensurePeerTile(peerId, data.user, data)

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

  ensurePeerConnection(peerId, userMeta) {
    const existing = this.peers.get(peerId)
    if (existing) {
      if (userMeta) existing.user = userMeta
      return existing.pc
    }

    const pc = new RTCPeerConnection({ iceServers: this.getIceServers() })
    const peerState = { pc, user: userMeta, tile: null, remoteStream: new MediaStream() }
    this.peers.set(peerId, peerState)

    const activeStream = this.screenStream || this.localStream
    if (activeStream) {
      activeStream.getTracks().forEach((track) => pc.addTrack(track, activeStream))
    }

    pc.onicecandidate = (event) => {
      if (event.candidate) {
        this.subscription.perform("signal", {
          client_id: this.clientId,
          target_id: peerId,
          signal_type: "ice_candidate",
          payload: event.candidate.toJSON()
        })
      }
    }

    pc.ontrack = (event) => {
      const tile = this.ensurePeerTile(peerId, peerState.user)
      const videoEl = tile.querySelector("video")
      const audioEl = tile.querySelector("audio")
      const stream = event.streams[0]

      if (stream) {
        peerState.remoteStream = stream
      } else {
        peerState.remoteStream.addTrack(event.track)
      }

      if (event.track.kind === "video" && videoEl) {
        videoEl.srcObject = peerState.remoteStream
        videoEl.classList.remove("hidden")
        tile.querySelector("[data-peer-placeholder]")?.classList.add("hidden")
        videoEl.play().catch(() => {})
      }

      if (event.track.kind === "audio" && audioEl) {
        audioEl.srcObject = peerState.remoteStream
        audioEl.play().catch(() => {})
      }
    }

    pc.onconnectionstatechange = () => {
      if (pc.connectionState === "failed" || pc.connectionState === "closed") {
        this.removePeer(peerId)
      }
    }

    return pc
  }

  async createOfferForPeer(peerId, userMeta) {
    const pc = this.ensurePeerConnection(peerId, userMeta)
    try {
      const offer = await pc.createOffer({ offerToReceiveAudio: true, offerToReceiveVideo: true })
      await pc.setLocalDescription(offer)
      this.subscription.perform("signal", {
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
  }

  async onSignalReceived(data) {
    if (data.target_id !== this.clientId) return

    const peerId = data.sender_id
    const pc = this.ensurePeerConnection(peerId, data.user)
    this.ensurePeerTile(peerId, data.user, data)

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
        this.subscription.perform("signal", {
          client_id: this.clientId,
          target_id: peerId,
          signal_type: "answer",
          payload: pc.localDescription.toJSON(),
          audio_enabled: this.audioEnabled,
          video_enabled: this.videoEnabled,
          screen_sharing: this.screenSharing
        })
      } else if (data.signal_type === "answer") {
        await pc.setRemoteDescription(new RTCSessionDescription(data.payload))
        await this.flushCandidates(peerId, pc)
      } else if (data.signal_type === "ice_candidate" && data.payload) {
        if (pc.remoteDescription) {
          await pc.addIceCandidate(new RTCIceCandidate(data.payload))
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
    for (const candidate of queue) {
      await pc.addIceCandidate(new RTCIceCandidate(candidate))
    }
    this.pendingCandidates.delete(peerId)
  }

  onMediaStateUpdated(data) {
    const tile = this.peersGridTarget?.querySelector(`[data-peer-id="${data.sender_id}"]`)
    if (!tile) return
    this.applyTileMediaBadges(tile, data)
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
      <video autoplay playsinline class="hidden h-full w-full object-cover"></video>
      <audio autoplay class="hidden"></audio>
      <div data-peer-placeholder class="flex h-full w-full flex-col items-center justify-center bg-inset p-4 pb-10 text-center">
        <div class="flex h-12 w-12 items-center justify-center rounded-xl border border-outline bg-card font-display text-base font-semibold text-on-surface">${this.escapeHtml(initials)}</div>
        <p class="mt-2 text-xs font-semibold text-on-surface">${this.escapeHtml(name)}</p>
        <p class="text-[11px] text-on-surface-muted">${this.escapeHtml(roleLabel)}</p>
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

  applyTileMediaBadges(tile, state) {
    const badgeEl = tile.querySelector("[data-peer-badges]")
    const videoEl = tile.querySelector("video")
    const placeholderEl = tile.querySelector("[data-peer-placeholder]")
    if (!badgeEl) return

    const badges = []
    badges.push(state.audio_enabled === false ? "Mute" : "Mic On")
    if (state.screen_sharing) {
      badges.push("Share Screen")
    } else {
      badges.push(state.video_enabled ? "Cam On" : "Cam Off")
    }
    badgeEl.textContent = badges.join(" · ")

    const hasLiveVideoTrack = videoEl?.srcObject?.getVideoTracks()?.length > 0
    if (state.video_enabled === false && !state.screen_sharing) {
      videoEl?.classList.add("hidden")
      placeholderEl?.classList.remove("hidden")
    } else if (hasLiveVideoTrack && (state.video_enabled || state.screen_sharing)) {
      videoEl?.classList.remove("hidden")
      placeholderEl?.classList.add("hidden")
    }
  }

  removePeer(peerId) {
    const peerState = this.peers.get(peerId)
    if (peerState) {
      peerState.pc.close()
      this.peers.delete(peerId)
    }
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

  toggleMic() {
    if (!this.localStream || this.localStream.getAudioTracks().length === 0) return
    this.audioEnabled = !this.audioEnabled
    this.localStream.getAudioTracks().forEach((track) => { track.enabled = this.audioEnabled })
    this.broadcastMediaState()
    this.updateMediaButtons()
  }

  toggleCam() {
    if (!this.localStream || this.localStream.getVideoTracks().length === 0) return
    this.videoEnabled = !this.videoEnabled
    this.localStream.getVideoTracks().forEach((track) => { track.enabled = this.videoEnabled })
    this.showLocalPlaceholder(!this.videoEnabled && !this.screenSharing)
    this.broadcastMediaState()
    this.updateMediaButtons()
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
    this.callActive = false
    this.stopSpeechRecognition({ preserveCaption: true })
    this.stopAllMediaStreams()
    this.closeAllPeers()
    if (this.peersGridTarget) {
      this.peersGridTarget.innerHTML = ""
    }
    this.subscription?.perform("leave", { client_id: this.clientId })
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

  endMeetingSession() {
    this.closeEndCallModal()
    this.leaveCall({ reason: "Mengakhiri panggilan untuk semua peserta..." })
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

    const camTrack = this.localStream?.getVideoTracks()[0] || null
    this.replaceOutgoingVideoTrack(camTrack)

    if (this.localStream && this.videoEnabled) {
      this.attachLocalVideo(this.localStream)
      this.showLocalPlaceholder(false)
    } else {
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
    this.peers.forEach((peerState, peerId) => {
      const { pc } = peerState
      const sender = pc.getSenders().find((s) => s.track?.kind === "video")
        || pc.getTransceivers().find((t) => t.receiver?.track?.kind === "video")?.sender
      if (sender) {
        sender.replaceTrack(newTrack).catch(() => {})
      } else if (newTrack && stream) {
        pc.addTrack(newTrack, stream)
        this.createOfferForPeer(peerId, peerState.user)
      }
    })
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
    if (iconEl) iconEl.textContent = iconName
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
      const hasMic = Boolean(this.localStream?.getAudioTracks().length)
      this.micButtonTarget.disabled = !hasMic
      this.setDockButtonContent(
        this.micButtonTarget,
        this.audioEnabled ? "mic" : "mic_off",
        this.audioEnabled ? "Mic Aktif" : "Mic Mute"
      )
      this.micButtonTarget.className = `${circleBase} ${
        !hasMic
          ? "bg-white/10 text-white/40 cursor-not-allowed"
          : this.audioEnabled
            ? "bg-white/15 text-inverse-on-surface hover:bg-white/25 cursor-pointer"
            : "bg-danger text-on-danger hover:bg-danger-hover cursor-pointer"
      }`
    }

    if (this.hasCamButtonTarget) {
      const hasCam = Boolean(this.localStream?.getVideoTracks().length)
      this.camButtonTarget.disabled = !hasCam
      this.setDockButtonContent(
        this.camButtonTarget,
        this.videoEnabled ? "videocam" : "videocam_off",
        this.videoEnabled ? "Cam Aktif" : "Cam Off"
      )
      this.camButtonTarget.className = `${circleBase} ${
        !hasCam
          ? "bg-white/10 text-white/40 cursor-not-allowed"
          : this.videoEnabled
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
    this.liveCaptionsTarget.className = `mt-3 min-h-[34px] rounded-xl border px-3.5 py-2 text-xs leading-relaxed ${tones[tone] || tones.slate}`
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

  submitQuickCaption(event) {
    event.preventDefault()
    if (!this.hasQuickCaptionInputTarget) return

    const text = this.quickCaptionInputTarget.value.trim()
    if (!text) return

    this.appendTranscriptLine(`${this.userNameValue}: ${text}`)
    this.subscription?.perform("transcript_chunk", {
      client_id: this.clientId,
      text
    })
    this.setLiveCaption(`${this.userNameValue}: ${text}`, "indigo")
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
    const line = `${data.speaker}: ${data.text}`
    this.appendTranscriptLine(line, false)
    this.setLiveCaption(line, "indigo")
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

