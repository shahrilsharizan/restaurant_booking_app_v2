import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RestaurantPackage {
  const RestaurantPackage({
    required this.documentId,
    required this.packageId,
    required this.name,
    required this.details,
    required this.category,
    required this.imageUrl,
    required this.dishes,
    required this.allergyNotes,
    required this.basePricePerPax,
    required this.services,
  });

  final String documentId;
  final String packageId;
  final String name;
  final String details;
  final String category;
  final String imageUrl;
  final List<String> dishes;
  final List<String> allergyNotes;
  final double basePricePerPax;
  final List<PackageService> services;

  factory RestaurantPackage.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? {};
    final rawPrice = data['base_price_per_pax'];

    return RestaurantPackage(
      documentId: snapshot.id,
      packageId: (data['package_id'] as String?) ?? snapshot.id,
      name: (data['name'] as String?) ?? 'Untitled Package',
      details: (data['details'] as String?) ?? '',
      category: (data['category'] as String?) ?? 'Cuisine',
      imageUrl:
          (data['image_url'] as String?) ?? (data['imageUrl'] as String?) ?? '',
      dishes: _readStringList(data['dishes']),
      allergyNotes: _readStringList(
        data['allergy_notes'] ?? data['allergyNotes'] ?? data['ingredients'],
      ),
      basePricePerPax: rawPrice is num ? rawPrice.toDouble() : 0,
      services: PackageService.readList(data['services']),
    );
  }

  static List<String> _readStringList(Object? value) {
    if (value is Iterable) {
      return value
          .whereType<String>()
          .where((item) => item.trim().isNotEmpty)
          .toList(growable: false);
    }

    return const [];
  }
}

class PackageService {
  const PackageService({
    required this.serviceId,
    required this.name,
    required this.price,
  });

  final String serviceId;
  final String name;
  final double price;

  factory PackageService.fromMap(Map<String, dynamic> data, int index) {
    final rawPrice = data['price'];
    final name = (data['name'] as String?) ?? 'Service ${index + 1}';

    return PackageService(
      serviceId:
          (data['service_id'] as String?) ??
          (data['id'] as String?) ??
          name.toLowerCase().replaceAll(' ', '_'),
      name: name,
      price: rawPrice is num ? rawPrice.toDouble() : 0,
    );
  }

  static List<PackageService> readList(Object? value) {
    if (value is Iterable) {
      final services = <PackageService>[];
      var index = 0;
      for (final item in value) {
        if (item is Map) {
          services.add(
            PackageService.fromMap(Map<String, dynamic>.from(item), index),
          );
          index++;
        } else if (item is String && item.trim().isNotEmpty) {
          services.add(
            PackageService(
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

    return const [
      PackageService(
        serviceId: 'private_booth',
        name: 'Private Booth',
        price: 50,
      ),
      PackageService(
        serviceId: 'birthday_decorations',
        name: 'Birthday Decorations',
        price: 80,
      ),
      PackageService(
        serviceId: 'custom_design',
        name: 'Custom Design',
        price: 120,
      ),
    ];
  }
}

final packageRepositoryProvider = Provider<PackageRepository>((ref) {
  return PackageRepository();
});

final packagesStreamProvider = StreamProvider<List<RestaurantPackage>>((ref) {
  return ref.watch(packageRepositoryProvider).watchPackages();
});

final packageByIdProvider = StreamProvider.family<RestaurantPackage?, String>((
  ref,
  packageId,
) {
  return ref.watch(packageRepositoryProvider).watchPackage(packageId);
});

class PackageRepository {
  Stream<List<RestaurantPackage>> watchPackages() {
    if (Firebase.apps.isEmpty) {
      return Stream.value(_demoPackages);
    }

    return FirebaseFirestore.instance.collection('packages').snapshots().map((
      snapshot,
    ) {
      final packages = snapshot.docs
          .map(RestaurantPackage.fromFirestore)
          .toList(growable: false);
      packages.sort((a, b) => a.name.compareTo(b.name));
      return packages;
    });
  }

  Stream<RestaurantPackage?> watchPackage(String packageId) {
    if (Firebase.apps.isEmpty) {
      RestaurantPackage? package;
      for (final demoPackage in _demoPackages) {
        if (demoPackage.packageId == packageId) {
          package = demoPackage;
          break;
        }
      }

      return Stream.value(package);
    }

    return FirebaseFirestore.instance
        .collection('packages')
        .doc(packageId)
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) {
            return null;
          }

          return RestaurantPackage.fromFirestore(snapshot);
        });
  }

  Future<String> createPackage(PackageDraft draft) async {
    final doc = await _packagesCollection.add(draft.toFirestore());
    await doc.update({'package_id': doc.id});
    return doc.id;
  }

  Future<void> updatePackage({
    required String documentId,
    required PackageDraft draft,
  }) {
    return _packagesCollection.doc(documentId).update(draft.toFirestore());
  }

  Future<void> deletePackage(String documentId) {
    return _packagesCollection.doc(documentId).delete();
  }

  CollectionReference<Map<String, dynamic>> get _packagesCollection {
    if (Firebase.apps.isEmpty) {
      throw Exception('Firebase is not configured yet.');
    }

    return FirebaseFirestore.instance.collection('packages');
  }
}

class PackageDraft {
  const PackageDraft({
    required this.name,
    required this.details,
    required this.category,
    required this.imageUrl,
    required this.dishes,
    required this.basePricePerPax,
    required this.services,
  });

  final String name;
  final String details;
  final String category;
  final String imageUrl;
  final List<String> dishes;
  final double basePricePerPax;
  final List<PackageService> services;

  Map<String, dynamic> toFirestore() {
    return {
      'name': name.trim(),
      'details': details.trim(),
      'category': category.trim(),
      'image_url': imageUrl.trim(),
      'dishes': dishes
          .map((dish) => dish.trim())
          .where((dish) => dish.isNotEmpty)
          .toList(growable: false),
      'base_price_per_pax': basePricePerPax,
      'services': services
          .map(
            (service) => {
              'service_id': service.serviceId,
              'name': service.name,
              'price': service.price,
            },
          )
          .toList(growable: false),
    };
  }
}

const _demoPackages = [
  RestaurantPackage(
    packageId: 'demo-royal',
    documentId: 'demo-royal',
    name: 'Royal Dinner Package',
    details:
        'Premium private dining menu with starter, main course, dessert, and drinks.',
    category: 'Fine Dining',
    imageUrl: '',
    dishes: ['Truffle mushroom soup', 'Grilled salmon', 'Chocolate mousse'],
    allergyNotes: ['Contains dairy', 'May contain nuts'],
    basePricePerPax: 188,
    services: [
      PackageService(
        serviceId: 'private_booth',
        name: 'Private Booth',
        price: 50,
      ),
      PackageService(
        serviceId: 'birthday_decorations',
        name: 'Birthday Decorations',
        price: 80,
      ),
      PackageService(
        serviceId: 'custom_design',
        name: 'Custom Design',
        price: 120,
      ),
    ],
  ),
  RestaurantPackage(
    packageId: 'demo-family',
    documentId: 'demo-family',
    name: 'Family Celebration Package',
    details:
        'Balanced group menu for birthdays, reunions, and small private events.',
    category: 'Malay Cuisine',
    imageUrl: '',
    dishes: ['Nasi minyak', 'Ayam masak merah', 'Kuih platter'],
    allergyNotes: ['Contains coconut milk', 'May contain peanuts'],
    basePricePerPax: 128,
    services: [
      PackageService(
        serviceId: 'private_booth',
        name: 'Private Booth',
        price: 50,
      ),
      PackageService(
        serviceId: 'birthday_decorations',
        name: 'Birthday Decorations',
        price: 80,
      ),
      PackageService(
        serviceId: 'custom_design',
        name: 'Custom Design',
        price: 120,
      ),
    ],
  ),
  RestaurantPackage(
    packageId: 'demo-corporate',
    documentId: 'demo-corporate',
    name: 'Corporate Event Package',
    details:
        'Elegant business event package with multi-course dining and table service.',
    category: 'Italian Cuisine',
    imageUrl: '',
    dishes: ['Bruschetta', 'Seafood pasta', 'Tiramisu'],
    allergyNotes: ['Contains gluten', 'Contains shellfish'],
    basePricePerPax: 168,
    services: [
      PackageService(
        serviceId: 'private_booth',
        name: 'Private Booth',
        price: 50,
      ),
      PackageService(
        serviceId: 'birthday_decorations',
        name: 'Birthday Decorations',
        price: 80,
      ),
      PackageService(
        serviceId: 'custom_design',
        name: 'Custom Design',
        price: 120,
      ),
    ],
  ),
];
