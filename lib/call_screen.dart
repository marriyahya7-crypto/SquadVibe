import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

const _callPurple = Color(0xFF9B5CFF);
const _callBackground = Color(0xFF100D19);
const _callPanel = Color(0xFF201A2D);

class CallScreen extends StatefulWidget {
  final String peerUid;
  final String peerName;
  final bool isCaller;
  final bool isVideo;
  final String? callId;

  const CallScreen({
    super.key,
    required this.peerUid,
    required this.peerName,
    required this.isCaller,
    required this.isVideo,
    this.callId,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final _db = FirebaseFirestore.instance;
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  RTCPeerConnection? _peer;
  MediaStream? _localStream;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _callSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _candidateSubscription;
  DocumentReference<Map<String, dynamic>>? _callRef;
  String? _callId;
  String _status = 'Préparation de l’appel…';
  bool _ready = false;
  bool _ending = false;
  bool _muted = false;
  bool _cameraOff = false;
  bool _speaker = true;
  bool _remoteDescriptionSet = false;
  final List<RTCIceCandidate> _pendingCandidates = [];

  @override
  void initState() {
    super.initState();
    _startCall();
  }

  Future<void> _startCall() async {
    try {
      await _localRenderer.initialize();
      await _remoteRenderer.initialize();

      final me = FirebaseAuth.instance.currentUser;
      if (me == null) throw Exception('Reconnecte-toi pour appeler.');

      if (widget.isCaller) {
        final myProfile = await _db.collection('users').doc(me.uid).get();
        final myName = myProfile.data()?['username'] as String? ??
            me.email?.split('@').first ?? 'Joueur';
        _callRef = _db.collection('calls').doc();
        _callId = _callRef!.id;
        await _callRef!.set({
          'callerUid': me.uid,
          'calleeUid': widget.peerUid,
          'callerName': myName,
          'calleeName': widget.peerName,
          'type': widget.isVideo ? 'video' : 'audio',
          'status': 'ringing',
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        if (widget.callId == null) throw Exception('Appel introuvable.');
        _callId = widget.callId;
        _callRef = _db.collection('calls').doc(_callId);
        final callSnapshot = await _callRef!.get();
        if (!callSnapshot.exists) throw Exception('Cet appel n’existe plus.');
        final callData = callSnapshot.data()!;
        if (callData['status'] != 'ringing' ||
            callData['calleeUid'] != me.uid) {
          throw Exception('Cet appel n’est plus disponible.');
        }
      }

      await _createPeer();
      _listenToCall();
      _listenToCandidates();

      if (widget.isCaller) {
        final offer = await _peer!.createOffer({
          'offerToReceiveAudio': 1,
          'offerToReceiveVideo': widget.isVideo ? 1 : 0,
        });
        await _peer!.setLocalDescription(offer);
        await _callRef!.update({
          'offer': {'sdp': offer.sdp, 'type': offer.type},
        });
        if (mounted) setState(() => _status = 'Appel en cours…');
      } else {
        final snapshot = await _callRef!.get();
        final offerMap = snapshot.data()?['offer'];
        if (offerMap is! Map) {
          throw Exception('L’offre d’appel est introuvable. Réessaie.');
        }
        await _peer!.setRemoteDescription(
          RTCSessionDescription(
            offerMap['sdp'] as String?,
            offerMap['type'] as String?,
          ),
        );
        _remoteDescriptionSet = true;
        await _flushCandidates();
        final answer = await _peer!.createAnswer({
          'offerToReceiveAudio': 1,
          'offerToReceiveVideo': widget.isVideo ? 1 : 0,
        });
        await _peer!.setLocalDescription(answer);
        await _callRef!.update({
          'answer': {'sdp': answer.sdp, 'type': answer.type},
          'status': 'accepted',
        });
        if (mounted) setState(() => _status = 'Connecté à l’appel…');
      }
      if (mounted) setState(() => _ready = true);
    } catch (error) {
      if (mounted) {
        setState(() => _status = error.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _createPeer() async {
    final config = <String, dynamic>{
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
      ],
      'sdpSemantics': 'unified-plan',
    };
    _peer = await createPeerConnection(config);
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': widget.isVideo
          ? {
              'facingMode': 'user',
              'width': {'ideal': 640},
              'height': {'ideal': 480},
              'frameRate': {'ideal': 24},
            }
          : false,
    });
    _localRenderer.srcObject = _localStream;
    for (final track in _localStream!.getTracks()) {
      await _peer!.addTrack(track, _localStream!);
    }
    _peer!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteRenderer.srcObject = event.streams.first;
        if (mounted) setState(() => _status = 'Appel connecté');
      }
    };
    _peer!.onIceCandidate = (candidate) async {
      if (candidate.candidate == null || _callRef == null) return;
      final collection = widget.isCaller ? 'callerCandidates' : 'calleeCandidates';
      try {
        await _callRef!.collection(collection).add({
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid ?? '',
          'sdpMLineIndex': candidate.sdpMLineIndex ?? 0,
        });
      } catch (_) {}
    };
    _peer!.onConnectionState = (state) {
      if (!mounted) return;
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        setState(() => _status = 'Appel connecté');
      } else if (state ==
          RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        setState(() => _status = 'Connexion impossible. Réessaie avec un autre réseau.');
      } else if (state ==
          RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        setState(() => _status = 'Connexion interrompue…');
      }
    };
  }

  void _listenToCall() {
    _callSubscription = _callRef!.snapshots().listen((snapshot) async {
      if (!snapshot.exists || !mounted) return;
      final data = snapshot.data()!;
      final status = data['status'] as String? ?? '';
      if (status == 'ended' || status == 'rejected') {
        if (mounted) setState(() => _status = status == 'rejected'
            ? 'Appel refusé.'
            : 'Appel terminé.');
        await Future<void>.delayed(const Duration(milliseconds: 600));
        if (mounted && !_ending) Navigator.of(context).maybePop();
        return;
      }
      if (widget.isCaller && !_remoteDescriptionSet && data['answer'] is Map) {
        final answer = Map<String, dynamic>.from(data['answer'] as Map);
        try {
          await _peer?.setRemoteDescription(RTCSessionDescription(
            answer['sdp'] as String?,
            answer['type'] as String?,
          ));
          _remoteDescriptionSet = true;
          await _flushCandidates();
          if (mounted) setState(() => _status = 'Appel connecté');
        } catch (_) {}
      }
    });
  }

  void _listenToCandidates() {
    final collection = widget.isCaller ? 'calleeCandidates' : 'callerCandidates';
    _candidateSubscription = _callRef!
        .collection(collection)
        .snapshots()
        .listen((snapshot) async {
      for (final change in snapshot.docChanges) {
        if (change.type != DocumentChangeType.added) continue;
        final data = change.doc.data();
        if (data == null || data['candidate'] == null) continue;
        final candidate = RTCIceCandidate(
          data['candidate'] as String?,
          data['sdpMid'] as String?,
          data['sdpMLineIndex'] as int?,
        );
        if (!_remoteDescriptionSet) {
          _pendingCandidates.add(candidate);
        } else {
          try {
            await _peer?.addCandidate(candidate);
          } catch (_) {}
        }
      }
    });
  }

  Future<void> _flushCandidates() async {
    for (final candidate in List<RTCIceCandidate>.from(_pendingCandidates)) {
      try {
        await _peer?.addCandidate(candidate);
      } catch (_) {}
    }
    _pendingCandidates.clear();
  }

  Future<void> _toggleMute() async {
    _muted = !_muted;
    for (final track in _localStream?.getAudioTracks() ?? <MediaStreamTrack>[]) {
      track.enabled = !_muted;
    }
    if (mounted) setState(() {});
  }

  Future<void> _toggleCamera() async {
    _cameraOff = !_cameraOff;
    for (final track in _localStream?.getVideoTracks() ?? <MediaStreamTrack>[]) {
      track.enabled = !_cameraOff;
    }
    if (mounted) setState(() {});
  }

  Future<void> _switchCamera() async {
    final tracks = _localStream?.getVideoTracks() ?? <MediaStreamTrack>[];
    if (tracks.isNotEmpty) await Helper.switchCamera(tracks.first);
  }

  Future<void> _endCall() async {
    if (_ending) return;
    _ending = true;
    try {
      if (_callRef != null) {
        final snapshot = await _callRef!.get();
        if (snapshot.exists && snapshot.data()?['status'] != 'ended') {
          await _callRef!.update({'status': 'ended'});
        }
      }
    } catch (_) {}
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
    _callSubscription?.cancel();
    _candidateSubscription?.cancel();
    _localStream?.getTracks().forEach((track) => track.stop());
    _remoteRenderer.srcObject = null;
    _localRenderer.srcObject = null;
    _peer?.close();
    _localStream?.dispose();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _callBackground,
      appBar: AppBar(
        backgroundColor: _callBackground,
        title: Text(widget.isVideo ? 'Appel vidéo' : 'Appel vocal'),
        actions: [
          if (widget.isVideo)
            IconButton(
              tooltip: 'Changer de caméra',
              onPressed: _switchCamera,
              icon: const Icon(Icons.cameraswitch_outlined),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (widget.isVideo && _remoteRenderer.srcObject != null)
                    RTCVideoView(
                      _remoteRenderer,
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    )
                  else
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF2B1B43), _callBackground],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 48,
                              backgroundColor: _callPurple.withValues(alpha: 0.22),
                              child: Text(
                                widget.peerName.isEmpty ? '?' : widget.peerName[0].toUpperCase(),
                                style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(widget.peerName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 8),
                            Text(_status, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                            if (!_ready) ...[
                              const SizedBox(height: 20),
                              const CircularProgressIndicator(color: _callPurple),
                            ],
                          ],
                        ),
                      ),
                    ),
                  if (widget.isVideo && _localRenderer.srcObject != null)
                    Positioned(
                      right: 14,
                      top: 14,
                      width: 110,
                      height: 155,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: _cameraOff
                            ? Container(color: _callPanel, child: const Icon(Icons.videocam_off))
                            : RTCVideoView(
                                _localRenderer,
                                mirror: true,
                                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                              ),
                      ),
                    ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 18,
                    child: Text(_status, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
              decoration: const BoxDecoration(
                color: _callPanel,
                borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ControlButton(
                    icon: _muted ? Icons.mic_off : Icons.mic,
                    label: _muted ? 'Activer micro' : 'Couper micro',
                    onTap: _toggleMute,
                  ),
                  if (widget.isVideo)
                    _ControlButton(
                      icon: _cameraOff ? Icons.videocam_off : Icons.videocam,
                      label: _cameraOff ? 'Activer caméra' : 'Couper caméra',
                      onTap: _toggleCamera,
                    ),
                  _ControlButton(
                    icon: _speaker ? Icons.volume_up : Icons.hearing,
                    label: _speaker ? 'Audio' : 'Écoute',
                    onTap: () async {
                      _speaker = !_speaker;
                      await Helper.setSpeakerphoneOn(_speaker);
                      if (mounted) setState(() {});
                    },
                  ),
                  _ControlButton(
                    icon: Icons.call_end,
                    label: 'Raccrocher',
                    background: Colors.redAccent,
                    onTap: _endCall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color background;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.background = const Color(0xFF3A2A52),
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filled(
          onPressed: onTap,
          style: IconButton.styleFrom(
            backgroundColor: background,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.all(16),
          ),
          icon: Icon(icon),
        ),
        const SizedBox(height: 5),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.white70)),
      ],
    );
  }
}
