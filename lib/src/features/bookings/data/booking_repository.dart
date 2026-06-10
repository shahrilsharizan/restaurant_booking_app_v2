import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_date_formatter.dart';

class Booking {
  const Booking({
    required this.bookingId,
    required this.uid,
    required this.packageId,
    required this.packageDocumentId,
    required this.packageName,
    required this.eventDate,
    required this.eventTime,
    required this.numGuests,
    required this.selectedServices,
    required this.totalPrice,
    required this.status,
  });

  final String bookingId;
  final String uid;
  final String packageId;
  final String packageDocumentId;
  final String packageName;
  final String eventDate;
  final String eventTime;
  final int numGuests;
  final List<BookingService> selectedServices;
  final double totalPrice;
  final String status;

  DateTime? get eventDateTime => parseAppDate(eventDate);
  String get displayEventDate => formatStoredAppDate(eventDate);

  factory Booking.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final rawGuests = data['num_guests'];
    final rawPrice = data['total_price'];

    return Booking(
      bookingId: (data['booking_id'] as String?) ?? doc.id,
      uid: (data['uid'] as String?) ?? '',
      packageId: (data['package_id'] as String?) ?? '',
      packageDocumentId:
          (data['package_document_id'] as String?) ??
          (data['package_id'] as String?) ??
          '',
      packageName: (data['package_name'] as String?) ?? 'Package',
      eventDate: (data['event_date'] as String?) ?? '',
      eventTime: (data['event_time'] as String?) ?? '',
      numGuests: rawGuests is num ? rawGuests.toInt() : 0,
      selectedServices: BookingService.readList(data['selected_services']),
      totalPrice: rawPrice is num ? rawPrice.toDouble() : 0,
      status: (data['status'] as String?) ?? 'active',
    );
  }
}

class BookingService {
  const BookingService({
    required this.serviceId,
    required this.name,
    required this.price,
  });

  final String serviceId;
  final String name;
  final double price;

  Map<String, dynamic> toFirestore() {
    return {'service_id': serviceId, 'name': name, 'price': price};
  }

  factory BookingService.fromMap(Map<String, dynamic> data, int index) {
    final rawPrice = data['price'];
    final name = (data['name'] as String?) ?? 'Service ${index + 1}';

    return BookingService(
      serviceId:
          (data['service_id'] as String?) ??
          (data['id'] as String?) ??
          name.toLowerCase().replaceAll(' ', '_'),
      name: name,
      price: rawPrice is num ? rawPrice.toDouble() : 0,
    );
  }

  static List<BookingService> readList(Object? value) {
    if (value is Iterable) {
      final services = <BookingService>[];
      var index = 0;
      for (final item in value) {
        if (item is Map) {
          services.add(
            BookingService.fromMap(Map<String, dynamic>.from(item), index),
          );
          index++;
        } else if (item is String && item.trim().isNotEmpty) {
          services.add(
            BookingService(
              serviceId: item.toLowerCase().replaceAll(' ', '_'),
              name: item,
              price: 0,
            ),
          );
          index++;
        }
      }
      return services;
    }

    return const [];
  }
}

class BookingDraft {
  const BookingDraft({
    required this.uid,
    required this.packageId,
    required this.packageDocumentId,
    required this.packageName,
    required this.eventDate,
    required this.eventTime,
    required this.numGuests,
    required this.selectedServices,
    required this.totalPrice,
  });

  final String uid;
  final String packageId;
  final String packageDocumentId;
  final String packageName;
  final String eventDate;
  final String eventTime;
  final int numGuests;
  final List<BookingService> selectedServices;
  final double totalPrice;

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'package_id': packageId,
      'package_document_id': packageDocumentId,
      'package_name': packageName,
      'event_date': eventDate,
      'event_time': eventTime,
      'num_guests': numGuests,
      'selected_services': selectedServices
          .map((service) => service.toFirestore())
          .toList(growable: false),
      'total_price': totalPrice,
      'status': 'active',
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    };
  }
}

final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  return BookingRepository();
});

final userBookingsProvider = StreamProvider.family<List<Booking>, String>((
  ref,
  uid,
) {
  return ref.watch(bookingRepositoryProvider).watchUserBookings(uid);
});

final bookingByIdProvider = StreamProvider.family<Booking?, String>((
  ref,
  bookingId,
) {
  return ref.watch(bookingRepositoryProvider).watchBooking(bookingId);
});

final allBookingsProvider = StreamProvider<List<Booking>>((ref) {
  return ref.watch(bookingRepositoryProvider).watchAllBookings();
});

class BookingRepository {
  Stream<List<Booking>> watchUserBookings(String uid) {
    if (Firebase.apps.isEmpty || uid.isEmpty || uid == 'guest') {
      return Stream.value(const []);
    }

    return FirebaseFirestore.instance
        .collection('bookings')
        .where('uid', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
          final bookings = snapshot.docs.map(Booking.fromFirestore).toList();
          bookings.sort(_compareBookingsByDate);
          return bookings;
        });
  }

  Stream<Booking?> watchBooking(String bookingId) {
    if (Firebase.apps.isEmpty || bookingId.isEmpty) {
      return Stream.value(null);
    }

    return FirebaseFirestore.instance
        .collection('bookings')
        .doc(bookingId)
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) {
            return null;
          }

          return Booking.fromFirestore(snapshot);
        });
  }

  Stream<List<Booking>> watchAllBookings() {
    if (Firebase.apps.isEmpty) {
      return Stream.value(const []);
    }

    return FirebaseFirestore.instance.collection('bookings').snapshots().map((
      snapshot,
    ) {
      final bookings = snapshot.docs.map(Booking.fromFirestore).toList();
      bookings.sort(_compareBookingsByDate);
      return bookings;
    });
  }

  Future<String> createBooking(BookingDraft draft) async {
    final collection = _bookingsCollection;
    final doc = await collection.add(draft.toFirestore());
    await doc.update({'booking_id': doc.id});
    return doc.id;
  }

  Future<void> updateBooking({
    required String bookingId,
    required String eventDate,
    required String eventTime,
    required int numGuests,
    required List<BookingService> selectedServices,
    required double totalPrice,
  }) {
    return _bookingsCollection.doc(bookingId).update({
      'event_date': eventDate,
      'event_time': eventTime,
      'num_guests': numGuests,
      'selected_services': selectedServices
          .map((service) => service.toFirestore())
          .toList(growable: false),
      'total_price': totalPrice,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> cancelBooking(String bookingId) {
    return _bookingsCollection.doc(bookingId).update({
      'status': 'cancelled',
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteBooking(String bookingId) {
    return _bookingsCollection.doc(bookingId).delete();
  }

  CollectionReference<Map<String, dynamic>> get _bookingsCollection {
    if (Firebase.apps.isEmpty) {
      throw Exception('Firebase is not configured yet.');
    }

    return FirebaseFirestore.instance.collection('bookings');
  }
}

int _compareBookingsByDate(Booking a, Booking b) {
  final aDate = a.eventDateTime;
  final bDate = b.eventDateTime;
  if (aDate == null && bDate == null) {
    return a.eventDate.compareTo(b.eventDate);
  }
  if (aDate == null) return 1;
  if (bDate == null) return -1;
  return aDate.compareTo(bDate);
}
