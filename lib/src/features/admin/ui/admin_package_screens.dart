import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../packages/data/package_repository.dart';

const _purple = Color(0xFF6C2DDC);
const _panelGrey = Color(0xFFEFEFEF);

class AdminPackageListScreen extends ConsumerWidget {
  const AdminPackageListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packagesState = ref.watch(packagesStreamProvider);

    return Scaffold(
      body: SafeArea(
        child: packagesState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) =>
              _Message(title: 'Unable to load packages', message: '$error'),
          data: (packages) => ListView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
            children: [
              _PageTitle(
                title: 'Package List',
                onBack: () => context.go('/admin'),
              ),
              const SizedBox(height: 20),
              if (packages.isEmpty)
                const _Message(
                  title: 'No packages',
                  message: 'Create a new package to show it here.',
                )
              else
                ...packages.map(
                  (package) => _AdminPackageCard(package: package),
                ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => context.go('/admin/packages/new'),
                style: _purpleButtonStyle(const Size.fromHeight(54)),
                child: const Text('Create New Package'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminPackageCard extends ConsumerWidget {
  const _AdminPackageCard({required this.package});

  final RestaurantPackage package;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _panelGrey,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            package.name,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 14),
          Text(
            'RM ${package.basePricePerPax.toStringAsFixed(0)} /Pax',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          Text(package.details, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FilledButton(
                onPressed: () =>
                    context.go('/admin/packages/${package.documentId}/edit'),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Modify'),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: () => _confirmDelete(context, ref, package),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    RestaurantPackage package,
  ) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete package?'),
        content: Text('Delete ${package.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Go Back'),
          ),
          FilledButton(
            onPressed: () async {
              await ref
                  .read(packageRepositoryProvider)
                  .deletePackage(package.documentId);
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class AdminCreatePackageScreen extends StatelessWidget {
  const AdminCreatePackageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _PackageFormScreen();
  }
}

class AdminEditPackageScreen extends ConsumerWidget {
  const AdminEditPackageScreen({super.key, required this.packageId});

  final String packageId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packageState = ref.watch(packageByIdProvider(packageId));
    return packageState.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        body: _Message(title: 'Unable to load package', message: '$error'),
      ),
      data: (package) {
        if (package == null) {
          return const Scaffold(
            body: _Message(
              title: 'Package not found',
              message: 'Choose another package.',
            ),
          );
        }
        return _PackageFormScreen(package: package);
      },
    );
  }
}

class _PackageFormScreen extends ConsumerStatefulWidget {
  const _PackageFormScreen({this.package});

  final RestaurantPackage? package;

  @override
  ConsumerState<_PackageFormScreen> createState() => _PackageFormScreenState();
}

class _PackageFormScreenState extends ConsumerState<_PackageFormScreen> {
  final _nameController = TextEditingController();
  final _detailsController = TextEditingController();
  final _categoryController = TextEditingController();
  final _imageController = TextEditingController();
  final _priceController = TextEditingController();
  final List<TextEditingController> _dishControllers = [];
  final List<_ServiceControllers> _serviceControllers = [];
  var _isSaving = false;

  bool get _isEditing => widget.package != null;

  @override
  void initState() {
    super.initState();
    final package = widget.package;
    if (package == null) {
      _dishControllers.add(TextEditingController());
      _serviceControllers.add(_ServiceControllers.empty());
      return;
    }

    _nameController.text = package.name;
    _detailsController.text = package.details;
    _categoryController.text = package.category;
    _imageController.text = package.imageUrl;
    _priceController.text = package.basePricePerPax.toStringAsFixed(0);
    _dishControllers.addAll(
      (package.dishes.isEmpty ? [''] : package.dishes).map(
        (dish) => TextEditingController(text: dish),
      ),
    );
    _serviceControllers.addAll(
      (package.services.isEmpty
              ? const [PackageService(serviceId: '', name: '', price: 0)]
              : package.services)
          .map(_ServiceControllers.fromService),
    );
  }

  @override
  void dispose() {
    for (final controller in [
      _nameController,
      _detailsController,
      _categoryController,
      _imageController,
      _priceController,
      ..._dishControllers,
    ]) {
      controller.dispose();
    }
    for (final service in _serviceControllers) {
      service.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
          children: [
            _PageTitle(
              title: _isEditing ? 'Edit Package' : 'Create Package',
              onBack: () => context.go('/admin/packages'),
            ),
            const SizedBox(height: 14),
            _Panel(
              children: [
                _LabeledField(
                  label: 'Package name:',
                  controller: _nameController,
                ),
                _LabeledField(
                  label: 'Category:',
                  controller: _categoryController,
                ),
                _LabeledField(
                  label: 'Details:',
                  controller: _detailsController,
                  maxLines: 4,
                ),
                const Text(
                  'Package menu:',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                ..._dishControllers.asMap().entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(child: TextField(controller: entry.value)),
                        IconButton(
                          tooltip: 'Remove dish',
                          onPressed: _dishControllers.length == 1
                              ? null
                              : () => setState(() {
                                  entry.value.dispose();
                                  _dishControllers.removeAt(entry.key);
                                }),
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                      ],
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(
                      () => _dishControllers.add(TextEditingController()),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Add dish'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _Panel(
              children: [
                _LabeledField(
                  label: 'Price /Pax:',
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                ),
                _LabeledField(
                  label: 'Image URL:',
                  controller: _imageController,
                ),
              ],
            ),
            const SizedBox(height: 14),
            _Panel(
              children: [
                const Text(
                  'Services:',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                ..._serviceControllers.asMap().entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: entry.value.nameController,
                            decoration: const InputDecoration(
                              labelText: 'Service',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: entry.value.priceController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.]'),
                              ),
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Price',
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remove service',
                          onPressed: _serviceControllers.length == 1
                              ? null
                              : () => setState(() {
                                  entry.value.dispose();
                                  _serviceControllers.removeAt(entry.key);
                                }),
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                      ],
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => setState(
                    () => _serviceControllers.add(_ServiceControllers.empty()),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Add service'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isSaving ? null : _savePackage,
              style: _purpleButtonStyle(const Size.fromHeight(54)),
              child: Text(_isEditing ? 'Update Package' : 'Create Package'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _savePackage() async {
    final validationError = _validateForm();
    if (validationError != null) {
      _showFormError(validationError);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final draft = PackageDraft(
        name: _nameController.text,
        details: _detailsController.text,
        category: _categoryController.text,
        imageUrl: _imageController.text,
        dishes: _dishControllers.map((controller) => controller.text).toList(),
        basePricePerPax: double.tryParse(_priceController.text) ?? 0,
        services: _serviceControllers
            .map((service) => service.toService())
            .where((service) => service.name.trim().isNotEmpty)
            .toList(growable: false),
      );

      final repository = ref.read(packageRepositoryProvider);
      if (_isEditing) {
        await repository.updatePackage(
          documentId: widget.package!.documentId,
          draft: draft,
        );
      } else {
        await repository.createPackage(draft);
      }

      if (!mounted) return;
      await _showSuccessDialog(
        context,
        title: 'Success!',
        message: _isEditing
            ? 'Package successfully edited'
            : 'A new package is created',
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String? _validateForm() {
    if (_nameController.text.trim().isEmpty) {
      return 'Package name is required.';
    }
    if (_categoryController.text.trim().isEmpty) {
      return 'Category is required.';
    }
    if (_detailsController.text.trim().isEmpty) {
      return 'Details are required.';
    }
    if (_dishControllers.every(
      (controller) => controller.text.trim().isEmpty,
    )) {
      return 'Add at least one dish in the package menu.';
    }
    if (_priceController.text.trim().isEmpty ||
        double.tryParse(_priceController.text) == null) {
      return 'Enter a valid price per pax.';
    }
    if (_imageController.text.trim().isEmpty) {
      return 'Image URL is required.';
    }
    for (final service in _serviceControllers) {
      final hasName = service.nameController.text.trim().isNotEmpty;
      final hasPrice = service.priceController.text.trim().isNotEmpty;
      if (!hasName || !hasPrice) {
        return 'Each service needs a name and price.';
      }
      if (double.tryParse(service.priceController.text) == null) {
        return 'Each service price must be a number.';
      }
    }
    return null;
  }

  void _showFormError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ServiceControllers {
  _ServiceControllers({
    required this.nameController,
    required this.priceController,
    required this.serviceId,
  });

  factory _ServiceControllers.empty() {
    return _ServiceControllers(
      nameController: TextEditingController(),
      priceController: TextEditingController(),
      serviceId: '',
    );
  }

  factory _ServiceControllers.fromService(PackageService service) {
    return _ServiceControllers(
      nameController: TextEditingController(text: service.name),
      priceController: TextEditingController(
        text: service.price.toStringAsFixed(0),
      ),
      serviceId: service.serviceId,
    );
  }

  final TextEditingController nameController;
  final TextEditingController priceController;
  final String serviceId;

  PackageService toService() {
    final name = nameController.text.trim();
    return PackageService(
      serviceId: serviceId.isNotEmpty
          ? serviceId
          : name.toLowerCase().replaceAll(' ', '_'),
      name: name,
      price: double.tryParse(priceController.text) ?? 0,
    );
  }

  void dispose() {
    nameController.dispose();
    priceController.dispose();
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.controller,
    this.maxLines = 1,
    this.keyboardType,
    this.inputFormatters,
  });

  final String label;
  final TextEditingController controller;
  final int maxLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _panelGrey,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
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

Future<void> _showSuccessDialog(
  BuildContext context, {
  required String title,
  required String message,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      content: Text(message),
      actions: [
        FilledButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            context.go('/admin');
          },
          style: _purpleButtonStyle(const Size(160, 44)),
          child: const Text('Home'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            context.go('/admin/packages');
          },
          child: const Text('Done'),
        ),
      ],
    ),
  );
}

ButtonStyle _purpleButtonStyle(Size minimumSize) {
  return FilledButton.styleFrom(
    backgroundColor: _purple,
    foregroundColor: Colors.white,
    minimumSize: minimumSize,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
  );
}
