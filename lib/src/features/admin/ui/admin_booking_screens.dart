import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/data/auth_repository.dart';
import '../../bookings/data/booking_repository.dart';

const _panelGrey = Color(0xFFEFEFEF);
const _purple = Color(0xFF6C2DDC);

class AdminBookingsScreen extends ConsumerWidget {
  const AdminBookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsState = ref.watch(allBookingsProvider);
    return Scaffold(
      body: SafeArea(
        child: bookingsState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) =>
              _Message(title: 'Unable to load bookings', message: '$error'),
          data: (bookings) => _AdminBookingsList(bookings: bookings),
        ),
      ),
    );
  }
}

class _AdminBookingsList extends StatefulWidget {
  const _AdminBookingsList({required this.bookings});

  final List<Booking> bookings;

  @override
  State<_AdminBookingsList> createState() => _AdminBookingsListState();
}

class _AdminBookingsListState extends State<_AdminBookingsList> {
  final _searchController = TextEditingController();
  var _sortNewestFirst = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final visibleBookings = widget.bookings
        .where((booking) {
          if (query.isEmpty) return true;

          final services = booking.selectedServices
              .map((service) => service.name)
              .join(' ')
              .toLowerCase();
          return booking.bookingId.toLowerCase().contains(query) ||
              booking.packageName.toLowerCase().contains(query) ||
              booking.displayEventDate.toLowerCase().contains(query) ||
              booking.eventTime.toLowerCase().contains(query) ||
              booking.status.toLowerCase().contains(query) ||
              services.contains(query);
        })
        .toList(growable: false);

    visibleBookings.sort((a, b) {
      final aDate = a.eventDateTime;
      final bDate = b.eventDateTime;
      final comparison = switch ((aDate, bDate)) {
        (final DateTime left, final DateTime right) => left.compareTo(right),
        (null, null) => a.eventDate.compareTo(b.eventDate),
        (null, _) => 1,
        (_, null) => -1,
      };
      return _sortNewestFirst ? -comparison : comparison;
    });

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      children: [
        _PageTitle(title: 'Bookings', onBack: () => context.go('/admin')),
        const SizedBox(height: 18),
        TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                    icon: const Icon(Icons.close),
                  ),
            hintText: 'Search bookings...',
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () =>
                setState(() => _sortNewestFirst = !_sortNewestFirst),
            icon: Icon(
              _sortNewestFirst ? Icons.arrow_downward : Icons.arrow_upward,
            ),
            label: Text(
              _sortNewestFirst
                  ? 'Sort by Date: Newest'
                  : 'Sort by Date: Oldest',
            ),
          ),
        ),
        const SizedBox(height: 18),
        if (widget.bookings.isEmpty)
          const _Message(
            title: 'No bookings',
            message: 'Customer bookings will appear here.',
          )
        else if (visibleBookings.isEmpty)
          const _Message(
            title: 'No matching bookings',
            message: 'Try another search.',
          )
        else
          ...visibleBookings.map(
            (booking) => _AdminBookingCard(booking: booking),
          ),
      ],
    );
  }
}

class _AdminBookingCard extends StatelessWidget {
  const _AdminBookingCard({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => context.go('/admin/bookings/${booking.bookingId}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _panelGrey,
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
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
                _StatusBadge(status: booking.status),
              ],
            ),
            const SizedBox(height: 22),
            const Text('Details', style: TextStyle(fontSize: 20)),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _Meta(label: 'Booking ID', value: booking.bookingId),
                ),
                Expanded(
                  child: _Meta(label: 'Time', value: booking.eventTime),
                ),
                Expanded(
                  child: _Meta(
                    label: 'Services',
                    value: booking.selectedServices.isEmpty
                        ? '-'
                        : booking.selectedServices
                              .map((service) => service.name)
                              .join(', '),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _Meta(label: 'Date', value: booking.displayEventDate),
          ],
        ),
      ),
    );
  }
}

class AdminBookingInfoScreen extends ConsumerWidget {
  const AdminBookingInfoScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingState = ref.watch(bookingByIdProvider(bookingId));
    final usersState = ref.watch(usersStreamProvider);
    return Scaffold(
      body: SafeArea(
        child: bookingState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) =>
              _Message(title: 'Unable to load booking', message: '$error'),
          data: (booking) {
            if (booking == null) {
              return const _Message(
                title: 'Booking not found',
                message: 'Choose another booking.',
              );
            }
            final username = usersState.maybeWhen(
              data: (users) {
                for (final user in users) {
                  if (user.uid == booking.uid) {
                    if (user.username.trim().isNotEmpty) {
                      return user.username;
                    }
                    if (user.fullName.trim().isNotEmpty) {
                      return user.fullName;
                    }
                    return user.email;
                  }
                }
                return booking.uid;
              },
              orElse: () => booking.uid,
            );
            return ListView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
              children: [
                _PageTitle(
                  title: 'Booking Info',
                  onBack: () => context.go('/admin/bookings'),
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: _panelGrey,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Info(
                        icon: Icons.celebration,
                        label: booking.packageName,
                      ),
                      _Info(icon: Icons.badge_outlined, label: username),
                      _Info(
                        icon: Icons.calendar_month,
                        label: booking.displayEventDate,
                      ),
                      _Info(icon: Icons.access_time, label: booking.eventTime),
                      const SizedBox(height: 10),
                      const Text(
                        'Add-on Services',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      if (booking.selectedServices.isEmpty)
                        const Text('No services selected')
                      else
                        ...booking.selectedServices.map(
                          (service) => CheckboxListTile(
                            value: true,
                            onChanged: null,
                            title: Text(
                              '${service.name} - RM ${service.price.toStringAsFixed(0)}',
                            ),
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                        ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Total Price',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                          Chip(
                            label: Text(
                              'RM ${booking.totalPrice.toStringAsFixed(0)}',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: () => context.push(
                          '/bookings/${booking.bookingId}/edit',
                          extra: {
                            'backRoute': '/admin',
                            'successHomeRoute': '/admin',
                            'successDoneRoute': '/admin/bookings',
                          },
                        ),
                        style: FilledButton.styleFrom(backgroundColor: _purple),
                        child: const Text('Edit'),
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => _confirmDelete(context, ref, booking),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: const Text('Delete'),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Booking booking,
  ) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Booking?', textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          FilledButton(
            onPressed: () async {
              await ref
                  .read(bookingRepositoryProvider)
                  .deleteBooking(booking.bookingId);
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              if (context.mounted) context.go('/admin/bookings');
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('YES, DELETE IT'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: status == 'cancelled' ? Colors.red : const Color(0xFF2DCC67),
        border: Border.all(width: 2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.toUpperCase(),
        style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.black54)),
        const SizedBox(height: 6),
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, size: 30),
          const SizedBox(width: 18),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class _PageTitle extends StatelessWidget {
  const _PageTitle({required this.title, required this.onBack});
  final String title;
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back)),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.title, required this.message});
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
