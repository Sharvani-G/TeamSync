import 'dart:async';

import 'package:flutter/material.dart';

import '../services/call_ringtone_service.dart';

class IncomingCallOverlayScreen extends StatefulWidget {
  final String callerName;
  final String projectTitle;
  final FutureOr<void> Function() onAccept;
  final FutureOr<void> Function() onDecline;

  const IncomingCallOverlayScreen({
    super.key,
    required this.callerName,
    required this.projectTitle,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  State<IncomingCallOverlayScreen> createState() => _IncomingCallOverlayScreenState();
}

class _IncomingCallOverlayScreenState extends State<IncomingCallOverlayScreen> {
  final CallRingtoneService _ringtoneService = CallRingtoneService();
  bool _ending = false;

  @override
  void initState() {
    super.initState();
    _ringtoneService.start();
  }

  Future<void> _accept() async {
    if (_ending) return;
    _ending = true;
    await _ringtoneService.stop();
    if (!mounted) return;
    widget.onAccept();
  }

  Future<void> _decline() async {
    if (_ending) return;
    _ending = true;
    await _ringtoneService.stop();
    if (!mounted) return;
    widget.onDecline();
  }

  @override
  void dispose() {
    _ringtoneService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF091017),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D1721), Color(0xFF091017)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: const Color(0xFF121C27),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 92,
                      width: 92,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF203142),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: const Icon(Icons.call, color: Colors.white, size: 42),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Incoming call',
                      style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.callerName,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.projectTitle,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.62)),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _decline,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFE35D6A)),
                              foregroundColor: const Color(0xFFE35D6A),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text('Decline'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _accept,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF67D47D),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text('Accept'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}