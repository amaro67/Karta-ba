import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/event_provider.dart';
import '../../providers/auth_provider.dart';
import '../../model/event/event_dto.dart';
import '../../utils/base_textfield.dart';
import '../../utils/error_dialog.dart';
import '../../utils/api_client.dart';
class EventFormScreen extends StatefulWidget {
  final EventDto? event;
  const EventFormScreen({super.key, this.event});
  @override
  State<EventFormScreen> createState() => _EventFormScreenState();
}
class _EventFormScreenState extends State<EventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _venueController = TextEditingController();
  final _cityController = TextEditingController();
  final _countryController = TextEditingController();
  final _categoryController = TextEditingController();
  final _tagsController = TextEditingController();
  final _coverImageUrlController = TextEditingController();
  final List<_TicketOptionController> _ticketOptions = [];
  final List<String> _supportedCurrencies = const ['BAM', 'EUR', 'USD'];
  DateTime? _startsAt;
  DateTime? _endsAt;
  String _status = 'Draft';
  bool _isLoading = false;
  @override
  void initState() {
    super.initState();
    if (widget.event != null) {
      _populateForm(widget.event!);
    } else {
      _countryController.text = 'Bosnia and Herzegovina';
    }
    _initializeTicketOptions();
    _coverImageUrlController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }
  void _populateForm(EventDto event) {
    _titleController.text = event.title;
    _descriptionController.text = event.description ?? '';
    _venueController.text = event.venue;
    _cityController.text = event.city;
    _countryController.text = event.country;
    _categoryController.text = event.category;
    _tagsController.text = event.tags ?? '';
    _coverImageUrlController.text = event.coverImageUrl ?? '';
    _startsAt = event.startsAt;
    _endsAt = event.endsAt;
    final validStatuses = ['Draft', 'Published', 'Cancelled', 'Archived'];
    _status = validStatuses.contains(event.status) ? event.status : 'Draft';
  }
  void _initializeTicketOptions() {
    if (widget.event != null && widget.event!.priceTiers.isNotEmpty) {
      for (final tier in widget.event!.priceTiers) {
        _ticketOptions.add(
          _TicketOptionController(
            name: tier.name,
            price: tier.price.toStringAsFixed(2),
            capacity: tier.capacity.toString(),
            currency: tier.currency,
          ),
        );
      }
    } else {
      _ticketOptions.add(_TicketOptionController());
    }
  }
  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _venueController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    _categoryController.dispose();
    _tagsController.dispose();
    _coverImageUrlController.dispose();
    for (final option in _ticketOptions) {
      option.dispose();
    }
    super.dispose();
  }
  Future<void> _selectDate(
    BuildContext context,
    bool isStartDate,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStartDate ? _startsAt : _endsAt) ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(
          (isStartDate ? _startsAt : _endsAt) ?? DateTime.now(),
        ),
      );
      if (time != null) {
        setState(() {
          final dateTime = DateTime(
            picked.year,
            picked.month,
            picked.day,
            time.hour,
            time.minute,
          );
          if (isStartDate) {
            _startsAt = dateTime;
            if (_endsAt != null && _endsAt!.isBefore(_startsAt!)) {
              _endsAt = null;
            }
          } else {
            _endsAt = dateTime;
          }
        });
      }
    }
  }
  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_startsAt == null) {
      ErrorDialog.show(
        context,
        title: 'Validation Error',
        message: 'Please select a start date and time',
      );
      return;
    }
    setState(() => _isLoading = true);
    List<Map<String, dynamic>>? priceTiers;
    try {
      priceTiers = _buildPriceTiersPayload();
    } catch (e) {
      setState(() => _isLoading = false);
      ErrorDialog.show(
        context,
        title: 'Validation Error',
        message: e.toString(),
      );
      return;
    }
    final eventData = {
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      'venue': _venueController.text.trim(),
      'city': _cityController.text.trim(),
      'country': _countryController.text.trim(),
      'startsAt': _startsAt!.toIso8601String(),
      'endsAt': _endsAt?.toIso8601String(),
      'category': _categoryController.text.trim(),
      'tags': _tagsController.text.trim().isEmpty
          ? null
          : _tagsController.text.trim(),
      'coverImageUrl': _coverImageUrlController.text.trim().isEmpty
          ? null
          : _coverImageUrlController.text.trim(),
      if (widget.event != null && _status != widget.event!.status) 'status': _status,
      'priceTiers': priceTiers,
    };
    final eventProvider = context.read<EventProvider>();
    final success = widget.event == null
        ? await eventProvider.createEvent(eventData)
        : await eventProvider.updateEvent(widget.event!.id, eventData);
    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.event == null
                  ? 'Event created successfully'
                  : 'Event updated successfully',
            ),
          ),
        );
      } else {
        ErrorDialog.show(
          context,
          title: 'Error',
          message: eventProvider.error ?? 'Failed to save event',
        );
      }
    }
  }
  List<Map<String, dynamic>> _buildPriceTiersPayload() {
    if (_ticketOptions.isEmpty) {
      throw Exception('Dodajte barem jednu opciju karte.');
    }
    final tiers = <Map<String, dynamic>>[];
    for (var i = 0; i < _ticketOptions.length; i++) {
      final option = _ticketOptions[i];
      final tierIndex = i + 1;
      final name = option.nameController.text.trim();
      final priceText = option.priceController.text.trim().replaceAll(',', '.');
      final capacityText = option.capacityController.text.trim();
      final price = double.tryParse(priceText);
      final capacity = int.tryParse(capacityText);
      if (name.isEmpty) {
        throw Exception('Unesite naziv za opciju karte #$tierIndex.');
      }
      if (price == null || price <= 0) {
        throw Exception('Unesite validnu cijenu za opciju karte #$tierIndex.');
      }
      if (capacity == null || capacity <= 0) {
        throw Exception('Unesite validan kapacitet za opciju karte #$tierIndex.');
      }
      tiers.add({
        'name': name,
        'price': price,
        'currency': option.currency,
        'capacity': capacity,
      });
    }
    return tiers;
  }
  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final bool showVerificationBanner =
        authProvider.isOrganizer && !authProvider.isAdmin && !authProvider.isOrganizerVerified;
    final bool publishDisabled = widget.event != null && showVerificationBanner;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.event == null ? 'Create Event' : 'Edit Event'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  if (showVerificationBanner) ...[
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orangeAccent),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.warning_amber_outlined, color: Colors.orange),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Vaš organizatorski profil još nije verifikovan. Događaji će ostati u Draft statusu dok admin ne potvrdi vaš nalog.',
                              style: TextStyle(
                                color: Colors.orange.shade900,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                    _SectionCard(
                      title: 'Basic Information',
                      icon: Icons.info_outline,
                      child: Column(
                        children: [
                          BaseTextField(
                            key: const ValueKey('title_field'),
                            label: 'Title *',
                            hint: 'Enter event title',
                            controller: _titleController,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Title is required';
                              }
                              if (value.length > 200) {
                                return 'Title must be less than 200 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          BaseTextField(
                            key: const ValueKey('description_field'),
                            label: 'Description',
                            hint: 'Enter event description',
                            controller: _descriptionController,
                            maxLines: 5,
                            maxLength: 2000,
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: BaseTextField(
                                  key: const ValueKey('category_field'),
                                  label: 'Category *',
                                  hint: 'e.g., Music, Sports, Theater',
                                  controller: _categoryController,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Category is required';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: BaseTextField(
                                  key: const ValueKey('tags_field'),
                                  label: 'Tags',
                                  hint: 'Comma-separated tags',
                                  controller: _tagsController,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _SectionCard(
                      title: 'Location',
                      icon: Icons.location_on_outlined,
                      child: Column(
                        children: [
                          BaseTextField(
                            key: const ValueKey('venue_field'),
                            label: 'Venue *',
                            hint: 'Enter venue name',
                            controller: _venueController,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Venue is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: BaseTextField(
                                  key: const ValueKey('city_field'),
                                  label: 'City *',
                                  hint: 'Enter city',
                                  controller: _cityController,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'City is required';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: BaseTextField(
                                  key: const ValueKey('country_field'),
                                  label: 'Country *',
                                  hint: 'Enter country',
                                  controller: _countryController,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Country is required';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _SectionCard(
                      title: 'Date & Time',
                      icon: Icons.calendar_today_outlined,
                      child: Row(
                        children: [
                          Expanded(
                            child: _DatePickerField(
                              label: 'Start Date & Time *',
                              value: _startsAt,
                              onTap: () => _selectDate(context, true),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _DatePickerField(
                              label: 'End Date & Time',
                              value: _endsAt,
                              onTap: () => _selectDate(context, false),
                              isOptional: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _SectionCard(
                      title: 'Ticket Options',
                      icon: Icons.confirmation_number_outlined,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dodajte različite vrste karata (npr. Early Bird, VIP, Regular) sa cijenom i kapacitetom.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey.shade600,
                                ),
                          ),
                          const SizedBox(height: 20),
                          ..._ticketOptions.asMap().entries.map(
                            (entry) => Padding(
                              padding: EdgeInsets.only(bottom: entry.key == _ticketOptions.length - 1 ? 0 : 16),
                              child: _TicketOptionCard(
                                option: entry.value,
                                currencies: _supportedCurrencies,
                                onRemove: _ticketOptions.length == 1
                                    ? null
                                    : () {
                                        setState(() {
                                          entry.value.dispose();
                                          _ticketOptions.removeAt(entry.key);
                                        });
                                      },
                                onCurrencyChanged: (currency) {
                                  setState(() {
                                    entry.value.currency = currency;
                                  });
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _ticketOptions.add(_TicketOptionController());
                              });
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Dodaj opciju karte'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _SectionCard(
                      title: 'Media',
                      icon: Icons.image_outlined,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          BaseTextField(
                            key: const ValueKey('cover_image_field'),
                            label: 'Cover Image URL',
                            hint: 'Enter image URL',
                            controller: _coverImageUrlController,
                          ),
                          if (_coverImageUrlController.text.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                ApiClient.getImageUrl(_coverImageUrlController.text) ?? '',
                                width: double.infinity,
                                height: 200,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  height: 200,
                                  color: const Color(0xFFF5F5F5),
                                  child: const Center(
                                    child: Icon(
                                      Icons.broken_image,
                                      color: Color(0xFF9E9E9E),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (widget.event != null) ...[
                      const SizedBox(height: 20),
                      _SectionCard(
                        title: 'Status',
                        icon: Icons.flag_outlined,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFFE0E0E0),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DropdownButtonFormField<String>(
                                initialValue: _status,
                                decoration: InputDecoration(
                                  labelText: 'Status',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none,
                                  ),
                                  filled: true,
                                  fillColor: Colors.transparent,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                                items: [
                                  DropdownMenuItem(
                                    value: 'Draft',
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: Colors.orange,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        const Text('Draft'),
                                      ],
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Published',
                                    enabled: !publishDisabled,
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: Colors.green,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        const Text('Published'),
                                      ],
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Cancelled',
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        const Text('Cancelled'),
                                      ],
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Archived',
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: Colors.grey,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        const Text('Archived'),
                                      ],
                                    ),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value == 'Published' && publishDisabled) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Admin mora verifikovati vaš nalog prije objave događaja.'),
                                        backgroundColor: Colors.orange,
                                      ),
                                    );
                                    return;
                                  }
                                  if (value != null) {
                                    setState(() => _status = value);
                                  }
                                },
                              ),
                              if (publishDisabled)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8, left: 8, right: 8),
                                  child: Text(
                                    'Objava događaja će biti omogućena nakon admin verifikacije.',
                                    style: TextStyle(
                                      color: Colors.orange.shade800,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                widget.event == null ? 'Create Event' : 'Update Event',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
class _TicketOptionController {
  final TextEditingController nameController;
  final TextEditingController priceController;
  final TextEditingController capacityController;
  String currency;
  _TicketOptionController({
    String name = '',
    String price = '',
    String capacity = '',
    String? currency,
  })  : nameController = TextEditingController(text: name),
        priceController = TextEditingController(text: price),
        capacityController = TextEditingController(text: capacity),
        currency = currency ?? 'BAM';
  void dispose() {
    nameController.dispose();
    priceController.dispose();
    capacityController.dispose();
  }
}
class _TicketOptionCard extends StatelessWidget {
  final _TicketOptionController option;
  final List<String> currencies;
  final VoidCallback? onRemove;
  final ValueChanged<String> onCurrencyChanged;
  const _TicketOptionCard({
    required this.option,
    required this.currencies,
    this.onRemove,
    required this.onCurrencyChanged,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0)),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Opcija karte',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              if (onRemove != null)
                IconButton(
                  tooltip: 'Ukloni opciju',
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
          ),
          const SizedBox(height: 16),
          BaseTextField(
            label: 'Naziv *',
            hint: 'npr. Early Bird, VIP',
            controller: option.nameController,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: BaseTextField(
                  label: 'Cijena *',
                  hint: 'npr. 25.00',
                  controller: option.priceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 130,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Valuta',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF212121),
                            fontSize: 13,
                          ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: option.currency,
                      items: currencies
                          .map(
                            (currency) => DropdownMenuItem(
                              value: currency,
                              child: Text(currency),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          onCurrencyChanged(value);
                        }
                      },
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          BaseTextField(
            label: 'Kapacitet *',
            hint: 'Koliko karata ove vrste je dostupno',
            controller: option.capacityController,
            keyboardType: TextInputType.number,
          ),
        ],
      ),
    );
  }
}
class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE0E0E0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      Theme.of(context).colorScheme.primary.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: Theme.of(context).colorScheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF212121),
                      fontSize: 20,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }
}
class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final bool isOptional;
  const _DatePickerField({
    required this.label,
    required this.value,
    required this.onTap,
    this.isOptional = false,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF212121),
                fontSize: 13,
              ),
        ),
        const SizedBox(height: 10),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            decoration: BoxDecoration(
              border: Border.all(
                color: value != null
                    ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
                    : const Color(0xFFE0E0E0),
                width: value != null ? 1.5 : 1,
              ),
              borderRadius: BorderRadius.circular(10),
              color: Colors.white,
              boxShadow: value != null
                  ? [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: value != null
                        ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                        : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.calendar_today,
                    color: value != null
                        ? Theme.of(context).colorScheme.primary
                        : const Color(0xFF757575),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    value != null
                        ? DateFormat('MMM dd, yyyy HH:mm').format(value!)
                        : isOptional
                            ? 'Select end date (optional)'
                            : 'Select start date',
                    style: TextStyle(
                      color: value != null
                          ? const Color(0xFF212121)
                          : const Color(0xFF9E9E9E),
                      fontSize: 14,
                      fontWeight: value != null ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down,
                  color: const Color(0xFF757575),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}