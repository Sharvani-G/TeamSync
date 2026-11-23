import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class IncomingCallOverlayScreen extends StatefulWidget {
  final String callerName;
  final String projectTitle;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

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
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _dismissTimer = Timer(const Duration(seconds: 45), () {
      widget.onDecline();
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.75),
      child: Center(
        child: Container(
          width: 380,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppTheme.panel,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.rule, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 46,
                backgroundColor: AppTheme.accent,
                child: Text(
                  widget.callerName.isNotEmpty ? widget.callerName[0].toUpperCase() : '?',
                  style: AppTheme.displayFont(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '${widget.callerName} is calling',
                style: AppTheme.displayFont(
                  color: AppTheme.ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Project: ${widget.projectTitle}',
                style: AppTheme.bodyFont(
                  color: AppTheme.inkSecondary,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _CallActionBtn(
                    icon: Icons.call_end_rounded,
                    color: AppTheme.danger,
                    label: 'Decline',
                    onTap: widget.onDecline,
                  ),
                  const SizedBox(width: 48),
                  _CallActionBtn(
                    icon: Icons.videocam_rounded,
                    color: const Color(0xFF10B981),
                    label: 'Join Call',
                    onTap: widget.onAccept,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CallActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _CallActionBtn({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: AppTheme.bodyFont(
            color: AppTheme.ink,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
