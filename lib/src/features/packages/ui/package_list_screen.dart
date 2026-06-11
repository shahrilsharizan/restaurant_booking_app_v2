import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/application/auth_session_provider.dart';
import '../data/package_repository.dart';

class PackageListScreen extends ConsumerStatefulWidget {
  const PackageListScreen({super.key});

  @override
  ConsumerState<PackageListScreen> createState() => _PackageListScreenState();
}

class _PackageListScreenState extends ConsumerState<PackageListScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final packagesState = ref.watch(packagesStreamProvider);
    final session = ref.watch(authSessionProvider).valueOrNull;
    final isGuest = session?.isGuest ?? true;
    final displayName = isGuest
        ? 'Guest'
        : (session?.fullName.trim().isNotEmpty ?? false)
        ? session!.fullName
        : session?.username ?? 'User';

    return Scaffold(
      body: SafeArea(
        child: packagesState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _PackageMessage(
            title: 'Unable to load packages',
            message: error.toString(),
          ),
          data: (packages) => ListView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
            children: [
              Row(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => context.go('/user-dashboard'),
                    child: _UserAvatar(
                      imageUrl: session?.profileImageUrl ?? '',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Welcome,',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Settings',
                    onPressed: () => context.go('/user-profile'),
                    icon: const Icon(Icons.settings),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _searchController,
                readOnly: true,
                onTap: () => context.go('/search'),
                decoration: InputDecoration(
                  hintText: 'Search Package',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: const Color(0xFFEFEFEF),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              if (packages.isEmpty)
                const _PackageMessage(
                  title: 'No packages yet',
                  message:
                      'Add package documents in Firestore to show them here.',
                )
              else
                ...packages
                    .take(4)
                    .map(
                      (package) => PackagePreviewCard(
                        package,
                        isGuest: isGuest,
                        sourceRoute: '/packages',
                      ),
                    ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const _MainBottomNav(selectedIndex: 0),
    );
  }
}

class SearchResultsScreen extends ConsumerStatefulWidget {
  const SearchResultsScreen({super.key});

  @override
  ConsumerState<SearchResultsScreen> createState() =>
      _SearchResultsScreenState();
}

class _SearchResultsScreenState extends ConsumerState<SearchResultsScreen> {
  final _searchController = TextEditingController();
  var _query = '';
  var _showFilters = false;
  var _sortOrder = _PriceSort.none;
  var _maxPrice = _MaxPrice.any;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final packagesState = ref.watch(packagesStreamProvider);
    final session = ref.watch(authSessionProvider).valueOrNull;
    final isGuest = session?.isGuest ?? true;

    return Scaffold(
      body: SafeArea(
        child: packagesState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _PackageMessage(
            title: 'Unable to search packages',
            message: error.toString(),
          ),
          data: (packages) {
            final filteredPackages = _filterPackages(packages);

            return Stack(
              children: [
                NotificationListener<ScrollUpdateNotification>(
                  onNotification: _hideFiltersWhenScrollingDown,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 42, 24, 24),
                    children: [
                      Row(
                        children: [
                          IconButton(
                            tooltip: 'Back',
                            onPressed: () => context.go('/packages'),
                            icon: const Icon(Icons.arrow_back_ios_new),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Search',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              onChanged: (value) =>
                                  setState(() => _query = value),
                              decoration: InputDecoration(
                                hintText: 'Search Package',
                                prefixIcon: const Icon(Icons.search),
                                filled: true,
                                fillColor: const Color(0xFFEFEFEF),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 22,
                                  vertical: 14,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFFEFEFEF),
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () {
                              setState(() => _showFilters = !_showFilters);
                            },
                            icon: const Icon(Icons.tune),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      if (filteredPackages.isEmpty)
                        const _PackageMessage(
                          title: 'No results found',
                          message: 'Try changing your search or filters.',
                        )
                      else
                        ...filteredPackages.map(
                          (package) => PackagePreviewCard(
                            package,
                            isGuest: isGuest,
                            sourceRoute: '/search',
                          ),
                        ),
                    ],
                  ),
                ),
                if (_showFilters)
                  Positioned(
                    top: 148,
                    right: 24,
                    child: _SearchFilterPanel(
                      sortOrder: _sortOrder,
                      maxPrice: _maxPrice,
                      onSortChanged: (value) {
                        setState(() => _sortOrder = value);
                      },
                      onMaxPriceChanged: (value) {
                        setState(() => _maxPrice = value);
                      },
                      onClear: () {
                        setState(() {
                          _sortOrder = _PriceSort.none;
                          _maxPrice = _MaxPrice.any;
                        });
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<RestaurantPackage> _filterPackages(List<RestaurantPackage> packages) {
    final query = _query.trim().toLowerCase();
    final filteredPackages = packages
        .where((package) {
          final matchesSearch =
              query.isEmpty ||
              package.name.toLowerCase().contains(query) ||
              package.details.toLowerCase().contains(query) ||
              package.category.toLowerCase().contains(query);
          final matchesPrice =
              _maxPrice.value == null ||
              package.basePricePerPax <= _maxPrice.value!;

          return matchesSearch && matchesPrice;
        })
        .toList(growable: false);

    if (_sortOrder == _PriceSort.lowToHigh) {
      filteredPackages.sort(
        (a, b) => a.basePricePerPax.compareTo(b.basePricePerPax),
      );
    } else if (_sortOrder == _PriceSort.highToLow) {
      filteredPackages.sort(
        (a, b) => b.basePricePerPax.compareTo(a.basePricePerPax),
      );
    }

    return filteredPackages;
  }

  bool _hideFiltersWhenScrollingDown(ScrollUpdateNotification notification) {
    final scrollDelta = notification.scrollDelta;
    if (_showFilters && scrollDelta != null && scrollDelta > 0) {
      setState(() => _showFilters = false);
    }

    return false;
  }
}

enum _PriceSort { none, lowToHigh, highToLow }

enum _MaxPrice {
  any(null, 'Any'),
  rm100(100.0, 'RM100'),
  rm200(200.0, 'RM200'),
  rm300(300.0, 'RM300'),
  rm500(500.0, 'RM500');

  const _MaxPrice(this.value, this.label);

  final double? value;
  final String label;
}

class _SearchFilterPanel extends StatelessWidget {
  const _SearchFilterPanel({
    required this.sortOrder,
    required this.maxPrice,
    required this.onSortChanged,
    required this.onMaxPriceChanged,
    required this.onClear,
  });

  final _PriceSort sortOrder;
  final _MaxPrice maxPrice;
  final ValueChanged<_PriceSort> onSortChanged;
  final ValueChanged<_MaxPrice> onMaxPriceChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 10,
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 176,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE3E3E3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Filters:',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                TextButton(onPressed: onClear, child: const Text('Clear')),
              ],
            ),
            const SizedBox(height: 8),
            _FilterMenuButton<_PriceSort>(
              label: 'Price',
              valueLabel: switch (sortOrder) {
                _PriceSort.none => 'Default',
                _PriceSort.lowToHigh => 'Low to high',
                _PriceSort.highToLow => 'High to low',
              },
              items: const [
                _FilterMenuOption(_PriceSort.none, 'Default'),
                _FilterMenuOption(_PriceSort.lowToHigh, 'Low to high'),
                _FilterMenuOption(_PriceSort.highToLow, 'High to low'),
              ],
              onSelected: onSortChanged,
            ),
            const SizedBox(height: 12),
            _FilterMenuButton<_MaxPrice>(
              label: 'Max price',
              valueLabel: maxPrice.label,
              items: _MaxPrice.values
                  .map((price) => _FilterMenuOption(price, price.label))
                  .toList(growable: false),
              onSelected: onMaxPriceChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterMenuOption<T> {
  const _FilterMenuOption(this.value, this.label);

  final T value;
  final String label;
}

class _FilterMenuButton<T> extends StatelessWidget {
  const _FilterMenuButton({
    required this.label,
    required this.valueLabel,
    required this.items,
    required this.onSelected,
  });

  final String label;
  final String valueLabel;
  final List<_FilterMenuOption<T>> items;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      onSelected: onSelected,
      itemBuilder: (context) => items
          .map(
            (item) =>
                PopupMenuItem<T>(value: item.value, child: Text(item.label)),
          )
          .toList(growable: false),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF4C55B8)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    valueLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );
  }
}

class PackagePreviewCard extends StatelessWidget {
  const PackagePreviewCard(
    this.package, {
    super.key,
    required this.isGuest,
    required this.sourceRoute,
  });

  final RestaurantPackage package;
  final bool isGuest;
  final String sourceRoute;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFEFEFEF),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 96,
            width: double.infinity,
            child: PackageFoodImage(imageUrl: package.imageUrl),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.circle, size: 6),
                            const SizedBox(width: 4),
                            Text(
                              package.category,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        package.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: 0.7,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          package.details,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
                GestureDetector(
                  onTap: () => context.go(
                    '/packages/${package.documentId}',
                    extra: sourceRoute,
                  ),
                  child: Container(
                    width: 76,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C2DDC),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'RM${package.basePricePerPax.toStringAsFixed(0)}/PAX',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PackageDetailsScreen extends ConsumerWidget {
  const PackageDetailsScreen({
    super.key,
    required this.packageId,
    required this.backRoute,
  });

  final String packageId;
  final String backRoute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packageState = ref.watch(packageByIdProvider(packageId));
    final session = ref.watch(authSessionProvider).valueOrNull;
    final isGuest = session?.isGuest ?? true;

    return Scaffold(
      body: SafeArea(
        child: packageState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _PackageMessage(
            title: 'Unable to load package',
            message: error.toString(),
          ),
          data: (package) {
            if (package == null) {
              return const _PackageMessage(
                title: 'Package not found',
                message: 'This package may have been removed.',
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(24, 30, 24, 28),
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      onPressed: () => context.go(backRoute),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Package Details',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFEFEF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        package.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          height: 178,
                          width: double.infinity,
                          child: PackageFoodImage(imageUrl: package.imageUrl),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _PackageDetailsBody(package: package),
                      ),
                      const SizedBox(height: 24),
                      Align(
                        alignment: Alignment.center,
                        child: FilledButton(
                          onPressed: () {
                            if (isGuest) {
                              context.go('/sign-up');
                              return;
                            }

                            context.go('/bookings/new/${package.documentId}');
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF6C2DDC),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            minimumSize: const Size(150, 42),
                          ),
                          child: Text(
                            isGuest ? 'Register/Login to Book' : 'Book Package',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PackageDetailsBody extends StatelessWidget {
  const _PackageDetailsBody({required this.package});

  final RestaurantPackage package;

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: Theme.of(
        context,
      ).textTheme.bodyMedium!.copyWith(color: Colors.black),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _DetailLabel('Details:'),
          if (package.details.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(package.details),
          ],
          const SizedBox(height: 16),
          const _DetailLabel('Dishes:'),
          _BulletList(
            items: package.dishes.isEmpty
                ? const ['Dishes will be updated soon.']
                : package.dishes,
          ),
          const SizedBox(height: 16),
          RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.bodyMedium,
              children: [
                const TextSpan(
                  text: 'Price: ',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                TextSpan(
                  text:
                      'From RM ${package.basePricePerPax.toStringAsFixed(0)}/pax',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailLabel extends StatelessWidget {
  const _DetailLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontWeight: FontWeight.w900));
  }
}

class _BulletList extends StatelessWidget {
  const _BulletList({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items
            .map(
              (item) => Text(
                '- $item',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _MainBottomNav extends StatelessWidget {
  const _MainBottomNav({required this.selectedIndex});

  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) {
        if (index == 0) {
          context.go('/packages');
        } else if (index == 1) {
          context.go('/user-profile');
        } else if (index == 2) {
          context.go('/bookings');
        }
      },
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          label: 'Profile',
        ),
        NavigationDestination(
          icon: Icon(Icons.event_note_outlined),
          label: 'Bookings',
        ),
      ],
    );
  }
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 22,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      foregroundImage: imageUrl.trim().isEmpty ? null : NetworkImage(imageUrl),
      child: const Icon(Icons.person_outline, size: 24),
    );
  }
}

class _PackageMessage extends StatelessWidget {
  const _PackageMessage({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
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
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class PackageFoodImage extends StatelessWidget {
  const PackageFoodImage({super.key, required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final trimmedUrl = imageUrl.trim();
    if (trimmedUrl.isEmpty) {
      return CustomPaint(
        painter: _PackageImagePainter(),
        child: const SizedBox.expand(),
      );
    }

    return Image.network(
      trimmedUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return CustomPaint(
          painter: _PackageImagePainter(),
          child: const SizedBox.expand(),
        );
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }

        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}

class _PackageImagePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = const Color(0xFFE5E8EF));

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < 8; i++) {
      final path = Path()
        ..moveTo(size.width * (0.12 + i * 0.09), 0)
        ..quadraticBezierTo(
          size.width * 0.48,
          size.height * 0.45,
          size.width * (0.28 + i * 0.08),
          size.height,
        );
      canvas.drawPath(path, linePaint);
    }

    final crossPaint = Paint()
      ..color = Colors.black54
      ..strokeWidth = 1.4;
    canvas
      ..drawLine(Offset.zero, Offset(size.width, size.height), crossPaint)
      ..drawLine(Offset(size.width, 0), Offset(0, size.height), crossPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
