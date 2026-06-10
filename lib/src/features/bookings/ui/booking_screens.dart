import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_date_formatter.dart';
import '../../auth/application/auth_session_provider.dart';
import '../../packages/data/package_repository.dart';
import '../data/booking_repository.dart';

const _purple = Color(0xFF6C2DDC);
const _panelGrey = Color(0xFFEFEFEF);

class BookingFormScreen extends ConsumerStatefulWidget {
  const BookingFormScreen({super.key, required this.packageId});

  final String packageId;

  @override
  ConsumerState<BookingFormScreen> createState() => _BookingFormScreenState();
}

class _BookingFormScreenState extends ConsumerState<BookingFormScreen> {
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  final Set<String> _selectedServiceIds = {};
  var _guestCount = 1;
  var _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final packageState = ref.watch(packageByIdProvider(widget.packageId));
    final session = ref.watch(authSessionProvider).valueOrNull;

    return Scaffold(
      body: SafeArea(
        child: packageState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _CenteredMessage(
            title: 'Unable to open booking form',
            message: error.toString(),
          ),
          data: (package) {
            if (package == null) {
              return const _CenteredMessage(
                title: 'Package not found',
                message: 'Please choose another package.',
              );
            }

            final isGuest = session?.isGuest ?? true;
            if (isGuest) {
              return _CenteredMessage(
                title: 'Login required',
                message: 'Create an account or login before placing a booking.',
                actionLabel: 'Go to Sign Up',
                onAction: () => context.go('/sign-up'),
              );
            }

            final selectedServices = _selectedServicesFor(package);
            final totalPrice = _calculateTotalPrice(
              basePricePerPax: package.basePricePerPax,
              guestCount: _guestCount,
              selectedServices: selectedServices,
            );

            return ListView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
              children: [
                _PageTitle(
                  title: 'Booking Form',
                  onBack: () => context.go('/packages/${package.documentId}'),
                ),
                const SizedBox(height: 12),
                _GreyPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        package.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                        ),
                      ),
                      const Text(
                        '* Note: Event bookings must be placed at least 7 days in advance.',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _PickerRow(
                        label: 'Start Date:',
                        value: _selectedDate == null
                            ? 'Select Date'
                            : formatAppDate(_selectedDate!),
                        onPressed: _pickDate,
                      ),
                      const SizedBox(height: 18),
                      _PickerRow(
                        label: 'Start Time:',
                        value: _selectedTime == null
                            ? 'Select Time'
                            : _selectedTime!.format(context),
                        onPressed: _pickTime,
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Number of Guests:',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                          SizedBox(
                            width: 100,
                            child: TextFormField(
                              initialValue: '$_guestCount',
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                              onChanged: (value) {
                                final count = int.tryParse(value) ?? 1;
                                setState(
                                  () => _guestCount = count < 1 ? 1 : count,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _GreyPanel(
                  child: _ServiceSelector(
                    services: package.services,
                    selectedServiceIds: _selectedServiceIds,
                    onChanged: (service, isSelected) {
                      setState(() {
                        if (isSelected) {
                          _selectedServiceIds.add(service.serviceId);
                        } else {
                          _selectedServiceIds.remove(service.serviceId);
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(height: 20),
                _GreyPanel(
                  child: _TotalPriceBreakdown(
                    title: 'Total Price',
                    basePricePerPax: package.basePricePerPax,
                    guestCount: _guestCount,
                    selectedServices: selectedServices,
                    totalPrice: totalPrice,
                  ),
                ),
                const SizedBox(height: 30),
                Center(
                  child: FilledButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => _placeBooking(
                            package,
                            session!.uid,
                            selectedServices,
                            totalPrice,
                          ),
                    style: _purpleButtonStyle(const Size(210, 52)),
                    child: _isSubmitting
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Place Booking',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                            ),
                          ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final sevenDaysFromNow = DateTime(now.year, now.month, now.day + 7);
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? sevenDaysFromNow,
      firstDate: sevenDaysFromNow,
      lastDate: DateTime(now.year + 2),
    );

    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );

    if (time != null) {
      setState(() => _selectedTime = time);
    }
  }

  Future<void> _placeBooking(
    RestaurantPackage package,
    String uid,
    List<BookingService> selectedServices,
    double totalPrice,
  ) async {
    if (_selectedDate == null || _selectedTime == null) {
      _showSnackBar('Please select a date and time.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final bookingId = await ref
          .read(bookingRepositoryProvider)
          .createBooking(
            BookingDraft(
              uid: uid,
              packageId: package.packageId,
              packageDocumentId: package.documentId,
              packageName: package.name,
              eventDate: formatAppDate(_selectedDate!),
              eventTime: _selectedTime!.format(context),
              numGuests: _guestCount,
              selectedServices: selectedServices,
              totalPrice: totalPrice,
            ),
          );

      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _BookingSuccessDialog(bookingId: bookingId),
      );
    } catch (error) {
      _showSnackBar(error.toString());
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  List<BookingService> _selectedServicesFor(RestaurantPackage package) {
    return package.services
        .where((service) => _selectedServiceIds.contains(service.serviceId))
        .map(
          (service) => BookingService(
            serviceId: service.serviceId,
            name: service.name,
            price: service.price,
          ),
        )
        .toList(growable: false);
  }
}

class BookingListScreen extends ConsumerWidget {
  const BookingListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider).valueOrNull;
    final uid = session?.uid ?? '';
    final bookingsState = ref.watch(userBookingsProvider(uid));

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () => context.go('/packages'),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Bookings',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: bookingsState.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => _CenteredMessage(
                  title: 'Unable to load bookings',
                  message: error.toString(),
                ),
                data: (bookings) {
                  final activeBookings = bookings
                      .where((booking) => booking.status != 'cancelled')
                      .toList(growable: false);

                  if (session?.isGuest ?? true) {
                    return _CenteredMessage(
                      title: 'Login required',
                      message: 'Login or sign up to view your bookings.',
                      actionLabel: 'Go to Login',
                      onAction: () => context.go('/login'),
                    );
                  }

                  if (activeBookings.isEmpty) {
                    return const _CenteredMessage(
                      title: 'No bookings yet',
                      message: 'Your confirmed bookings will appear here.',
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(32, 0, 32, 24),
                    itemCount: activeBookings.length,
                    itemBuilder: (context, index) {
                      return _BookingListCard(booking: activeBookings[index]);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BookingInfoScreen extends ConsumerWidget {
  const BookingInfoScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingState = ref.watch(bookingByIdProvider(bookingId));

    return Scaffold(
      body: SafeArea(
        child: bookingState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _CenteredMessage(
            title: 'Unable to load booking',
            message: error.toString(),
          ),
          data: (booking) {
            if (booking == null) {
              return const _CenteredMessage(
                title: 'Booking not found',
                message: 'This booking may have been removed.',
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
              children: [
                _PageTitle(
                  title: 'Booking Info',
                  onBack: () => context.go('/bookings'),
                ),
                const SizedBox(height: 32),
                _GreyPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InfoRow(
                        icon: Icons.celebration,
                        label: booking.packageName,
                      ),
                      _InfoRow(
                        icon: Icons.badge,
                        label: 'Booking ID: ${booking.bookingId}',
                      ),
                      _InfoRow(
                        icon: Icons.calendar_month,
                        label: booking.displayEventDate,
                      ),
                      _InfoRow(
                        icon: Icons.access_time,
                        label: booking.eventTime,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _GreyPanel(
                  child: _BookingTotalSummary(
                    booking: booking,
                    title: 'Total Price',
                  ),
                ),
                const SizedBox(height: 38),
                Center(
                  child: FilledButton(
                    onPressed: () => _showCancelDialog(context, ref, booking),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(240, 56),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: const Text(
                      'Cancel Application',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _showCancelDialog(
    BuildContext context,
    WidgetRef ref,
    Booking booking,
  ) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Cancel Application?',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          Column(
            children: [
              FilledButton(
                onPressed: () async {
                  await ref
                      .read(bookingRepositoryProvider)
                      .cancelBooking(booking.bookingId);
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                  if (context.mounted) {
                    context.go('/bookings');
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(220, 42),
                ),
                child: const Text('YES, CANCEL IT'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ModifyBookingScreen extends ConsumerStatefulWidget {
  const ModifyBookingScreen({
    super.key,
    required this.bookingId,
    this.backRoute = '/bookings',
    this.successHomeRoute = '/packages',
    this.successDoneRoute = '/bookings',
  });

  final String bookingId;
  final String backRoute;
  final String successHomeRoute;
  final String successDoneRoute;

  @override
  ConsumerState<ModifyBookingScreen> createState() =>
      _ModifyBookingScreenState();
}

class _ModifyBookingScreenState extends ConsumerState<ModifyBookingScreen> {
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  final Set<String> _selectedServiceIds = {};
  int? _guestCount;
  var _initialized = false;
  var _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final bookingState = ref.watch(bookingByIdProvider(widget.bookingId));

    return Scaffold(
      body: SafeArea(
        child: bookingState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _CenteredMessage(
            title: 'Unable to modify booking',
            message: error.toString(),
          ),
          data: (booking) {
            if (booking == null) {
              return const _CenteredMessage(
                title: 'Booking not found',
                message: 'This booking may have been removed.',
              );
            }

            _initializeFromBooking(booking);
            final packageState = ref.watch(
              packageByIdProvider(booking.packageDocumentId),
            );

            return packageState.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _CenteredMessage(
                title: 'Unable to load services',
                message: error.toString(),
              ),
              data: (package) {
                final services = package?.services ?? const <PackageService>[];
                final selectedServices = _selectedServicesFor(
                  services,
                  booking.selectedServices,
                );
                final basePricePerPax = _basePricePerPaxFor(booking);
                final totalPrice = _calculateTotalPrice(
                  basePricePerPax: basePricePerPax,
                  guestCount: _guestCount ?? booking.numGuests,
                  selectedServices: selectedServices,
                );

                return ListView(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                  children: [
                    _PageTitle(title: 'Modify Booking', onBack: _goBack),
                    const SizedBox(height: 12),
                    _GreyPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            booking.packageName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            '* Note: Event bookings must be placed at least 7 days in advance.',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 24),
                          _PickerRow(
                            label: 'Start Date:',
                            value: _selectedDate == null
                                ? booking.displayEventDate
                                : formatAppDate(_selectedDate!),
                            onPressed: _pickDate,
                          ),
                          const SizedBox(height: 18),
                          _PickerRow(
                            label: 'Start Time:',
                            value: _selectedTime == null
                                ? booking.eventTime
                                : _selectedTime!.format(context),
                            onPressed: _pickTime,
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Number of Guests:',
                                  style: TextStyle(fontWeight: FontWeight.w900),
                                ),
                              ),
                              SizedBox(
                                width: 100,
                                child: TextFormField(
                                  initialValue: '$_guestCount',
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                  onChanged: (value) {
                                    final count = int.tryParse(value) ?? 1;
                                    setState(
                                      () => _guestCount = count < 1 ? 1 : count,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _GreyPanel(
                      child: _ServiceSelector(
                        services: services,
                        selectedServiceIds: _selectedServiceIds,
                        onChanged: (service, isSelected) {
                          setState(() {
                            if (isSelected) {
                              _selectedServiceIds.add(service.serviceId);
                            } else {
                              _selectedServiceIds.remove(service.serviceId);
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 18),
                    _GreyPanel(
                      child: _TotalPriceBreakdown(
                        title: 'Updated Total Price',
                        basePricePerPax: basePricePerPax,
                        guestCount: _guestCount ?? booking.numGuests,
                        selectedServices: selectedServices,
                        totalPrice: totalPrice,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Center(
                      child: FilledButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => _confirmChanges(
                                booking,
                                selectedServices,
                                totalPrice,
                              ),
                        style: _purpleButtonStyle(const Size(260, 54)),
                        child: const Text(
                          'Confirm changes',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _initializeFromBooking(Booking booking) {
    if (_initialized) {
      return;
    }

    _selectedDate = parseAppDate(booking.eventDate);
    _guestCount = booking.numGuests == 0 ? 1 : booking.numGuests;
    _selectedServiceIds.addAll(
      booking.selectedServices.map((service) => service.serviceId),
    );
    _initialized = true;
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }

    context.go(widget.backRoute);
  }

  double _basePricePerPaxFor(Booking booking) {
    final oldGuestCount = booking.numGuests == 0 ? 1 : booking.numGuests;
    final serviceTotal = booking.selectedServices.fold<double>(
      0,
      (total, service) => total + service.price,
    );
    return (booking.totalPrice - serviceTotal) / oldGuestCount;
  }

  List<BookingService> _selectedServicesFor(
    List<PackageService> packageServices,
    List<BookingService> savedServices,
  ) {
    final byId = {
      for (final service in packageServices) service.serviceId: service,
    };

    return _selectedServiceIds
        .map((serviceId) {
          final packageService = byId[serviceId];
          if (packageService != null) {
            return BookingService(
              serviceId: packageService.serviceId,
              name: packageService.name,
              price: packageService.price,
            );
          }

          return savedServices.firstWhere(
            (service) => service.serviceId == serviceId,
            orElse: () =>
                BookingService(serviceId: serviceId, name: serviceId, price: 0),
          );
        })
        .toList(growable: false);
  }

  // --- Updated _pickDate logic inside ModifyBookingScreen ---
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final sevenDaysFromNow = DateTime(now.year, now.month, now.day + 7);
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? sevenDaysFromNow,
      firstDate:
          sevenDaysFromNow, // Restricts modification selection to 7 days ahead
      lastDate: DateTime(now.year + 2),
    );

    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );

    if (time != null) {
      setState(() => _selectedTime = time);
    }
  }

  Future<void> _confirmChanges(
    Booking booking,
    List<BookingService> selectedServices,
    double totalPrice,
  ) async {
    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(bookingRepositoryProvider)
          .updateBooking(
            bookingId: booking.bookingId,
            eventDate: _selectedDate == null
                ? formatStoredAppDate(booking.eventDate)
                : formatAppDate(_selectedDate!),
            eventTime: _selectedTime == null
                ? booking.eventTime
                : _selectedTime!.format(context),
            numGuests: _guestCount ?? booking.numGuests,
            selectedServices: selectedServices,
            totalPrice: totalPrice,
          );

      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _ModifySuccessDialog(
          homeRoute: widget.successHomeRoute,
          doneRoute: widget.successDoneRoute,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}

class _BookingListCard extends StatelessWidget {
  const _BookingListCard({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 22),
      padding: const EdgeInsets.all(22),
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
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ),
              Container(
                width: 110,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF2DCC67),
                  border: Border.all(width: 3),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'ACTIVE',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          InkWell(
            onTap: () => _showBookingBackdrop(context, booking),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 2),
              child: Text('Details', style: TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(height: 24),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Booking ID', style: TextStyle(color: Colors.black54)),
              Text('Date & Time'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  booking.bookingId,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                '${booking.displayEventDate}  ${booking.eventTime}',
                textAlign: TextAlign.right,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton(
                onPressed: () =>
                    context.push('/bookings/${booking.bookingId}/edit'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black,
                  side: const BorderSide(color: Color(0xFF2DCC67)),
                ),
                child: const Text('Modify Booking'),
              ),
              OutlinedButton(
                onPressed: () => _showBookingBackdrop(context, booking),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black,
                  side: const BorderSide(color: Colors.red),
                ),
                child: const Text('View Details'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ServiceSelector extends StatelessWidget {
  const _ServiceSelector({
    required this.services,
    required this.selectedServiceIds,
    required this.onChanged,
  });

  final List<PackageService> services;
  final Set<String> selectedServiceIds;
  final void Function(PackageService service, bool isSelected) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Add-on Services',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 16),
        if (services.isEmpty)
          Text(
            'No add-on services available.',
            style: Theme.of(context).textTheme.bodySmall,
          )
        else
          ...services.map(
            (service) => CheckboxListTile(
              value: selectedServiceIds.contains(service.serviceId),
              onChanged: (value) => onChanged(service, value ?? false),
              contentPadding: EdgeInsets.zero,
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              title: Row(
                children: [
                  Expanded(child: Text(service.name)),
                  Text(
                    'RM ${service.price.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _TotalPriceBreakdown extends StatelessWidget {
  const _TotalPriceBreakdown({
    required this.title,
    required this.basePricePerPax,
    required this.guestCount,
    required this.selectedServices,
    required this.totalPrice,
  });

  final String title;
  final double basePricePerPax;
  final int guestCount;
  final List<BookingService> selectedServices;
  final double totalPrice;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            _PricePill(label: 'RM ${totalPrice.toStringAsFixed(0)}'),
          ],
        ),
        const SizedBox(height: 12),
        _PriceLine(
          label: 'Package x $guestCount',
          value: basePricePerPax * guestCount,
        ),
        ...selectedServices.map(
          (service) => _PriceLine(label: service.name, value: service.price),
        ),
      ],
    );
  }
}

class _BookingTotalSummary extends StatelessWidget {
  const _BookingTotalSummary({required this.booking, required this.title});

  final Booking booking;
  final String title;

  @override
  Widget build(BuildContext context) {
    final serviceTotal = booking.selectedServices.fold<double>(
      0,
      (total, service) => total + service.price,
    );
    final packageTotal = booking.totalPrice - serviceTotal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            _PricePill(label: 'RM ${booking.totalPrice.toStringAsFixed(0)}'),
          ],
        ),
        const SizedBox(height: 12),
        _PriceLine(
          label: 'Package x ${booking.numGuests}',
          value: packageTotal,
        ),
        ...booking.selectedServices.map(
          (service) => _PriceLine(label: service.name, value: service.price),
        ),
      ],
    );
  }
}

class _PriceLine extends StatelessWidget {
  const _PriceLine({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Text(
            'RM ${value.toStringAsFixed(0)}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800),
          ),
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
                _BackdropRow(label: 'Booking ID', value: booking.bookingId),
                _BackdropRow(label: 'Date', value: booking.displayEventDate),
                _BackdropRow(label: 'Time', value: booking.eventTime),
                _BackdropRow(label: 'Guests', value: '${booking.numGuests}'),
                if (booking.selectedServices.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  const Text(
                    'Services',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  ...booking.selectedServices.map(
                    (service) => _BackdropRow(
                      label: service.name,
                      value: 'RM ${service.price.toStringAsFixed(0)}',
                    ),
                  ),
                ],
                _BackdropRow(
                  label: 'Total',
                  value: 'RM ${booking.totalPrice.toStringAsFixed(0)}',
                ),
                _BackdropRow(label: 'Status', value: booking.status),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          final router = GoRouter.of(context);
                          Navigator.of(context).pop();
                          router.push('/bookings/${booking.bookingId}/edit');
                        },
                        child: const Text('Modify Booking'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          final router = GoRouter.of(context);
                          Navigator.of(context).pop();
                          router.go('/bookings/${booking.bookingId}');
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

double _calculateTotalPrice({
  required double basePricePerPax,
  required int guestCount,
  required List<BookingService> selectedServices,
}) {
  final serviceTotal = selectedServices.fold<double>(
    0,
    (total, service) => total + service.price,
  );
  return (basePricePerPax * guestCount) + serviceTotal;
}

class _BackdropRow extends StatelessWidget {
  const _BackdropRow({required this.label, required this.value});

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

class _BookingSuccessDialog extends StatelessWidget {
  const _BookingSuccessDialog({required this.bookingId});

  final String bookingId;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text(
        'Congratulations, your booking is confirmed!',
        textAlign: TextAlign.center,
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        Column(
          children: [
            FilledButton(
              onPressed: () {
                final router = GoRouter.of(context);
                Navigator.of(context).pop();
                router.go('/bookings/$bookingId');
              },
              style: _purpleButtonStyle(const Size(250, 52)),
              child: const Text('Go to Booking Info'),
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: () {
                final router = GoRouter.of(context);
                Navigator.of(context).pop();
                router.go('/packages');
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                minimumSize: const Size(250, 52),
              ),
              child: const Text('Home'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ModifySuccessDialog extends StatelessWidget {
  const _ModifySuccessDialog({
    required this.homeRoute,
    required this.doneRoute,
  });

  final String homeRoute;
  final String doneRoute;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text(
        'Success!',
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
      content: const Text(
        'The booking has been modified successfully',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        Column(
          children: [
            FilledButton(
              onPressed: () {
                final router = GoRouter.of(context);
                Navigator.of(context).pop();
                router.go(homeRoute);
              },
              style: _purpleButtonStyle(const Size(230, 48)),
              child: const Text('Home'),
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: () {
                final router = GoRouter.of(context);
                Navigator.of(context).pop();
                router.go(doneRoute);
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                minimumSize: const Size(230, 48),
              ),
              child: const Text('Done'),
            ),
          ],
        ),
      ],
    );
  }
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.label,
    required this.value,
    required this.onPressed,
  });

  final String label;
  final String value;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        FilledButton(
          onPressed: onPressed,
          style: _purpleButtonStyle(const Size(138, 40)),
          child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
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
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back),
        ),
        const SizedBox(width: 4),
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            color: Colors.black,
          ),
        ),
      ],
    );
  }
}

class _GreyPanel extends StatelessWidget {
  const _GreyPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _panelGrey,
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(icon, size: 28),
          const SizedBox(width: 20),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _PricePill extends StatelessWidget {
  const _PricePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 106,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _purple,
        borderRadius: BorderRadius.circular(24),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

ButtonStyle _purpleButtonStyle(Size minimumSize) {
  return FilledButton.styleFrom(
    backgroundColor: _purple,
    foregroundColor: Colors.white,
    minimumSize: minimumSize,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
  );
}
