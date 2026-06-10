import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/application/auth_session_provider.dart';
import '../../auth/data/auth_repository.dart';
import '../../bookings/data/booking_repository.dart';

class UserDashboardScreen extends ConsumerWidget {
  const UserDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider).valueOrNull;
    final uid = session?.uid ?? '';
    final bookingsState = ref.watch(userBookingsProvider(uid));

    return Scaffold(
      body: SafeArea(
        child: bookingsState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _DashboardMessage(
            title: 'Unable to load dashboard',
            message: error.toString(),
          ),
          data: (bookings) {
            final activeBookings = bookings
                .where((booking) => booking.status != 'cancelled')
                .toList(growable: false);
            final historyBookings = bookings
                .where((booking) => booking.status == 'cancelled')
                .toList(growable: false);
            final visibleHistory = historyBookings.isEmpty
                ? bookings.take(3).toList(growable: false)
                : historyBookings.take(3).toList(growable: false);

            return ListView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
              children: [
                _DashboardHeader(session: session),
                const SizedBox(height: 28),
                const Text(
                  'Booking History',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 18),
                if (visibleHistory.isEmpty)
                  const _DashboardMessage(
                    title: 'No previous bookings',
                    message:
                        'Completed or cancelled bookings will appear here.',
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: visibleHistory
                        .map((booking) => _HistoryBookingTile(booking: booking))
                        .toList(growable: false),
                  ),
                const SizedBox(height: 34),
                const Text(
                  'Active Bookings',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 20),
                if (session?.isGuest ?? true)
                  _DashboardMessage(
                    title: 'Login required',
                    message: 'Login or sign up to view your bookings.',
                    actionLabel: 'Go to Login',
                    onAction: () => context.go('/login'),
                  )
                else if (activeBookings.isEmpty)
                  const _DashboardMessage(
                    title: 'No active bookings',
                    message: 'Your active bookings will appear here.',
                  )
                else
                  ...activeBookings.map(
                    (booking) => _ActiveBookingCard(booking: booking),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.session});

  final AuthenticatedUser? session;

  @override
  Widget build(BuildContext context) {
    final name = (session?.fullName.trim().isNotEmpty ?? false)
        ? session!.fullName
        : session?.username ?? 'Guest';
    final username = session?.isGuest ?? true
        ? '@Guest'
        : '@${session!.username}';

    return Row(
      children: [
        IconButton(
          tooltip: 'Back',
          onPressed: () => context.go('/packages'),
          icon: const Icon(Icons.arrow_back),
        ),
        const SizedBox(width: 6),
        _ProfileAvatar(imageUrl: session?.profileImageUrl ?? ''),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(username, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: 26,
      backgroundColor: colorScheme.primaryContainer,
      foregroundImage: imageUrl.trim().isEmpty ? null : NetworkImage(imageUrl),
      child: const Icon(Icons.person, size: 28),
    );
  }
}

class _HistoryBookingTile extends StatelessWidget {
  const _HistoryBookingTile({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _showBookingBackdrop(context, booking),
      child: SizedBox(
        width: 92,
        child: Column(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
            ),
            const SizedBox(height: 12),
            Text(
              booking.packageName,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 18),
            Text(
              booking.displayEventDate,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveBookingCard extends StatelessWidget {
  const _ActiveBookingCard({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  booking.packageName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const _ActiveBadge(),
            ],
          ),
          const SizedBox(height: 14),
          _CardMetaRow(
            label: 'Booking ID',
            value: booking.bookingId,
            label2: 'Time',
            value2: booking.eventTime,
          ),
          const SizedBox(height: 12),
          _CardMetaRow(
            label: 'Date',
            value: booking.displayEventDate,
            label2: 'Services',
            value2: booking.selectedServices.isEmpty
                ? '-'
                : booking.selectedServices
                      .map((service) => service.name)
                      .join(', '),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () => context.push(
                  '/bookings/${booking.bookingId}/edit',
                  extra: {'backRoute': '/user-dashboard'},
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF2DCC67)),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('Modify Booking',
                style: TextStyle(fontSize: 12, color: Colors.black),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => context.go('/bookings/${booking.bookingId}'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('Cancel Booking',
                style: TextStyle(fontSize: 12, color: Colors.black),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CardMetaRow extends StatelessWidget {
  const _CardMetaRow({
    required this.label,
    required this.value,
    required this.label2,
    required this.value2,
  });

  final String label;
  final String value;
  final String label2;
  final String value2;

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall;
    return Row(
      children: [
        Expanded(
          child: _MetaText(label: label, value: value, style: small),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetaText(label: label2, value: value2, style: small),
        ),
      ],
    );
  }
}

class _MetaText extends StatelessWidget {
  const _MetaText({
    required this.label,
    required this.value,
    required this.style,
  });

  final String label;
  final String value;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: style),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _ActiveBadge extends StatelessWidget {
  const _ActiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF2DCC67),
        border: Border.all(width: 2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'ACTIVE',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _DashboardMessage extends StatelessWidget {
  const _DashboardMessage({
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

Future<void> _showBookingBackdrop(BuildContext context, Booking booking) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black45,
    isScrollControlled: true,
    builder: (context) {
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        booking.packageName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _SheetRow(label: 'Booking ID', value: booking.bookingId),
                _SheetRow(label: 'Date', value: booking.displayEventDate),
                _SheetRow(label: 'Time', value: booking.eventTime),
                _SheetRow(label: 'Guests', value: '${booking.numGuests}'),
                _SheetRow(
                  label: 'Total',
                  value: 'RM ${booking.totalPrice.toStringAsFixed(0)}',
                ),
                _SheetRow(label: 'Status', value: booking.status),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _SheetRow extends StatelessWidget {
  const _SheetRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 94,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
