import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'notification_cubit.dart';
import 'notifications_screen.dart';

class NotificationBellIcon extends StatelessWidget {
  final Color? color;
  final double size;
  const NotificationBellIcon({super.key, this.color, this.size = 26});

  Future<void> _open(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
    if (context.mounted) context.read<NotificationCubit>().refreshUnreadCount();
  }

  @override
  Widget build(BuildContext context) {
    final unread = context.watch<NotificationCubit>().state.unreadCount;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: () => _open(context),
          icon: Icon(Icons.notifications_none_rounded, color: color, size: size),
        ),
        if (unread > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
          ),
      ],
    );
  }
}