import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:team_sync/services/call_service.dart';

/// Call status badge widget
class CallStatusBadge extends StatelessWidget {
  final CallStatus status;
  final EdgeInsets padding;

  const CallStatusBadge({
    Key? key,
    required this.status,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  }) : super(key: key);

  Color _getStatusColor(CallStatus status) {
    switch (status) {
      case CallStatus.scheduled:
        return Colors.blue;
      case CallStatus.inProgress:
        return Colors.green;
      case CallStatus.completed:
        return Colors.grey;
      case CallStatus.cancelled:
        return Colors.red;
      case CallStatus.missedCall:
        return Colors.orange;
    }
  }

  String _getStatusLabel(CallStatus status) {
    switch (status) {
      case CallStatus.scheduled:
        return 'Scheduled';
      case CallStatus.inProgress:
        return 'In Progress';
      case CallStatus.completed:
        return 'Completed';
      case CallStatus.cancelled:
        return 'Cancelled';
      case CallStatus.missedCall:
        return 'Missed';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _getStatusColor(status).withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _getStatusColor(status),
          width: 1,
        ),
      ),
      child: Text(
        _getStatusLabel(status),
        style: TextStyle(
          color: _getStatusColor(status),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

/// Call card widget for displaying call information
class CallCard extends StatelessWidget {
  final CallData call;
  final VoidCallback? onTap;
  final VoidCallback? onJoinTap;
  final VoidCallback? onCancelTap;

  const CallCard({
    Key? key,
    required this.call,
    this.onTap,
    this.onJoinTap,
    this.onCancelTap,
  }) : super(key: key);

  String _getTimeDisplay() {
    final now = DateTime.now();
    final duration = call.scheduledAt.difference(now);

    if (duration.isNegative) {
      return 'Scheduled time passed';
    } else if (duration.inHours == 0) {
      return 'In ${duration.inMinutes} minutes';
    } else if (duration.inHours < 24) {
      return 'In ${duration.inHours} hours';
    } else {
      return 'In ${(duration.inHours / 24).toStringAsFixed(0)} days';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with status badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Call with ${call.initiatorName}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        Text(
                          DateFormat('MMM d, yyyy • h:mm a')
                              .format(call.scheduledAt),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8),
                  CallStatusBadge(status: call.status),
                ],
              ),
              SizedBox(height: 12),

              // Time remaining
              if (call.status == CallStatus.scheduled)
                Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Icon(Icons.schedule, size: 16, color: Colors.blue),
                      SizedBox(width: 8),
                      Text(
                        _getTimeDisplay(),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

              // Participants
              if (call.participants.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Icon(Icons.people, size: 16, color: Colors.grey),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${call.participants.length} participant${call.participants.length != 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Call duration (for completed calls)
              if (call.status == CallStatus.completed &&
                  call.startedAt != null &&
                  call.endedAt != null)
                Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Icon(Icons.timer, size: 16, color: Colors.grey),
                      SizedBox(width: 8),
                      Text(
                        _formatDuration(
                          call.endedAt!.difference(call.startedAt!),
                        ),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),

              // Actions
              if (call.status == CallStatus.scheduled ||
                  call.status == CallStatus.inProgress)
                SizedBox(
                  height: 36,
                  child: Row(
                    children: [
                      if (call.status == CallStatus.inProgress &&
                          onJoinTap != null)
                        Expanded(
                          child: ElevatedButton(
                            onPressed: onJoinTap,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                            child: Text('Join Call'),
                          ),
                        ),
                      if (onCancelTap != null) ...[
                        SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: onCancelTap,
                            child:
                                Text(call.status == CallStatus.inProgress
                                    ? 'End'
                                    : 'Cancel'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    } else {
      return '${duration.inMinutes}m';
    }
  }
}

/// Call control button for call UI
class CallControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final Color foregroundColor;
  final bool isActive;

  const CallControlButton({
    Key? key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.backgroundColor = Colors.grey,
    this.foregroundColor = Colors.white,
    this.isActive = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: FloatingActionButton(
        onPressed: onPressed,
        backgroundColor:
            isActive ? backgroundColor.withOpacity(0.8) : backgroundColor,
        foregroundColor: foregroundColor,
        mini: true,
        child: Icon(icon),
      ),
    );
  }
}

/// Call participants display widget
class CallParticipantsList extends StatelessWidget {
  final List<String> participants;
  final List<String> activeParticipants;

  const CallParticipantsList({
    Key? key,
    required this.participants,
    required this.activeParticipants,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Participants',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: participants.length,
          itemBuilder: (context, index) {
            final participantId = participants[index];
            final isActive = activeParticipants.contains(participantId);

            return Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.blue[100],
                        child: Text(
                          participantId.substring(0, 2).toUpperCase(),
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (isActive)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Participant ${index + 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          isActive ? 'In Call' : 'Invited',
                          style: TextStyle(
                            fontSize: 12,
                            color: isActive
                                ? Colors.green
                                : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Scheduled call reminder notification widget
class CallReminderNotification extends StatelessWidget {
  final String initiatorName;
  final DateTime scheduledAt;
  final VoidCallback onDismiss;
  final VoidCallback? onJoin;

  const CallReminderNotification({
    Key? key,
    required this.initiatorName,
    required this.scheduledAt,
    required this.onDismiss,
    this.onJoin,
  }) : super(key: key);

  String _getTimeUntilCall() {
    final now = DateTime.now();
    final duration = scheduledAt.difference(now);

    if (duration.isNegative) {
      return 'Call started';
    } else if (duration.inMinutes < 1) {
      return 'Starting now';
    } else if (duration.inMinutes < 60) {
      return 'In ${duration.inMinutes} minutes';
    } else {
      return 'In ${(duration.inHours)}h ${duration.inMinutes.remainder(60)}m';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.phone_in_talk, color: Colors.blue, size: 24),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Incoming Call',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'From $initiatorName • ${_getTimeUntilCall()}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              IconButton(
                onPressed: onDismiss,
                icon: Icon(Icons.close, size: 20),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
          if (onJoin != null) ...[
            SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 36,
              child: ElevatedButton(
                onPressed: onJoin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                ),
                child: Text('Join Call'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Screen sharing indicator
class ScreenSharingIndicator extends StatelessWidget {
  final bool isActive;
  final String sharingUserName;
  final VoidCallback? onStop;

  const ScreenSharingIndicator({
    Key? key,
    this.isActive = false,
    this.sharingUserName = '',
    this.onStop,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!isActive) return SizedBox.shrink();

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[300]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 8),
          Text(
            'Screen sharing: $sharingUserName',
            style: TextStyle(
              color: Colors.red[700],
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          if (onStop != null) ...[
            SizedBox(width: 8),
            GestureDetector(
              onTap: onStop,
              child: Icon(Icons.close, size: 16, color: Colors.red[700]),
            ),
          ],
        ],
      ),
    );
  }
}

/// Call timer widget for active calls
class CallTimer extends StatefulWidget {
  final DateTime callStartedAt;

  const CallTimer({
    Key? key,
    required this.callStartedAt,
  }) : super(key: key);

  @override
  State<CallTimer> createState() => _CallTimerState();
}

class _CallTimerState extends State<CallTimer> {
  late Future<void> _updateFuture;

  @override
  void initState() {
    super.initState();
    _updateFuture = Future.delayed(Duration(seconds: 1), () {
      if (mounted) setState(() {});
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours == 0) {
      return '$twoDigitMinutes:$twoDigitSeconds';
    }
    return '${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds';
  }

  @override
  Widget build(BuildContext context) {
    final duration = DateTime.now().difference(widget.callStartedAt);
    return Text(
      _formatDuration(duration),
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.grey[700],
      ),
    );
  }
}
