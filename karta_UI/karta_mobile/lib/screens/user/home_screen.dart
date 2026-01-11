import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:karta_shared/karta_shared.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../widgets/event_card.dart';
import '../../widgets/category_button.dart';
import '../../widgets/popular_events_carousel.dart';
import '../../services/viewed_events_service.dart';
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}
class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _searchController = TextEditingController();
  String? _selectedCategory;
  String? _selectedCity;
  String? _selectedTimeFilter;
  bool _hasActiveFilters = false;
  Timer? _searchDebounce;
  List<String> _viewedEventIds = [];
  final List<Map<String, dynamic>> _timeFilters = [
    {'label': 'Today', 'value': 'today', 'icon': Icons.today},
    {'label': 'This Week', 'value': 'this_week', 'icon': Icons.date_range},
    {'label': 'Be Ready', 'value': 'be_ready', 'icon': Icons.upcoming},
  ];
  final Map<String, IconData> _categoryIcons = {
    'Sport': Icons.sports_soccer,
    'Culture': Icons.theater_comedy,
    'Music': Icons.music_note,
    'Film': Icons.movie,
    'Theater': Icons.theater_comedy,
    'Festival': Icons.celebration,
    'Conference': Icons.business,
    'Workshop': Icons.school,
    'Exhibition': Icons.palette,
    'Comedy': Icons.sentiment_satisfied_alt,
    'Other': Icons.event,
  };
  IconData _getCategoryIcon(String category) {
    return _categoryIcons[category] ?? Icons.event;
  }
  final List<String> _popularCities = [
    'Sarajevo',
    'Mostar',
    'Zenica',
    'Tuzla',
    'Banjaluka',
    'Trebinje',
  ];
  final bool _useTestData = false;
  List<EventDto> _getTestEvents() {
    final now = DateTime.now();
    return [
      EventDto(
        id: '1',
        title: 'Event long name - Kulturna predstava u centru',
        slug: 'kulturna-predstava-centar',
        description: 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. In sed orci vestibulum, pharetra sapien sed, dictum nulla. Nulla dignissim, risus a porta mattis, nisl et porta orci. Nam nec libero non mauris volutpat porttitor.',
        startsAt: now.add(const Duration(days: 7)),
        endsAt: now.add(const Duration(days: 7, hours: 3)),
        venue: 'Kamerni teatar 55',
        city: 'Sarajevo',
        country: 'Bosnia and Herzegovina',
        category: 'Culture',
        status: 'Published',
        createdAt: now.subtract(const Duration(days: 30)),
        priceTiers: [
          const PriceTierDto(
            id: '1',
            name: 'Standard',
            price: 15.0,
            currency: 'KM',
            capacity: 100,
            sold: 50,
          ),
        ],
        coverImageUrl: null,
      ),
      EventDto(
        id: '2',
        title: 'Teatar predstava - Večernja scena',
        slug: 'teatar-predstava-vecernja',
        description: 'Opis druge predstave sa dugim tekstom.',
        startsAt: now.add(const Duration(days: 10)),
        endsAt: now.add(const Duration(days: 10, hours: 2)),
        venue: 'Narodno pozorište',
        city: 'Sarajevo',
        country: 'Bosnia and Herzegovina',
        category: 'Culture',
        status: 'Published',
        createdAt: now.subtract(const Duration(days: 25)),
        priceTiers: [
          const PriceTierDto(
            id: '2',
            name: 'Standard',
            price: 20.0,
            currency: 'KM',
            capacity: 150,
            sold: 50,
          ),
        ],
        coverImageUrl: null,
      ),
      EventDto(
        id: '3',
        title: 'FK Sarajevo vs FK Željezničar - Derby',
        slug: 'sarajevo-vs-zeljeznicar-derby',
        description: 'Najveći derbi u BiH.',
        startsAt: now.add(const Duration(days: 5)),
        endsAt: now.add(const Duration(days: 5, hours: 2)),
        venue: 'Olimpijski stadion Asim Ferhatović Hase',
        city: 'Sarajevo',
        country: 'Bosnia and Herzegovina',
        category: 'Sport',
        status: 'Published',
        createdAt: now.subtract(const Duration(days: 20)),
        priceTiers: [
          const PriceTierDto(
            id: '3',
            name: 'Zapad',
            price: 10.0,
            currency: 'KM',
            capacity: 500,
            sold: 300,
          ),
          const PriceTierDto(
            id: '4',
            name: 'Istok',
            price: 15.0,
            currency: 'KM',
            capacity: 500,
            sold: 200,
          ),
        ],
        coverImageUrl: null,
      ),
      EventDto(
        id: '4',
        title: 'Košarkaška utakmica - KK Bosna vs KK Igokea',
        slug: 'kosarka-bosna-vs-igokea',
        description: 'Regionalna košarkaška liga.',
        startsAt: now.add(const Duration(days: 8)),
        endsAt: now.add(const Duration(days: 8, hours: 2)),
        venue: 'Dvorana Mirza Delibašić',
        city: 'Sarajevo',
        country: 'Bosnia and Herzegovina',
        category: 'Sport',
        status: 'Published',
        createdAt: now.subtract(const Duration(days: 15)),
        priceTiers: [
          const PriceTierDto(
            id: '5',
            name: 'Standard',
            price: 12.0,
            currency: 'KM',
            capacity: 300,
            sold: 150,
          ),
        ],
        coverImageUrl: null,
      ),
      EventDto(
        id: '5',
        title: 'Koncert klasične muzike',
        slug: 'koncert-klasicne-muzike',
        description: 'Sarajevska filharmonija izvodi Mocarta.',
        startsAt: now.add(const Duration(days: 15)),
        endsAt: now.add(const Duration(days: 15, hours: 2)),
        venue: 'Kamerni teatar 55',
        city: 'Sarajevo',
        country: 'Bosnia and Herzegovina',
        category: 'Music',
        status: 'Published',
        createdAt: now.subtract(const Duration(days: 10)),
        priceTiers: [
          const PriceTierDto(
            id: '6',
            name: 'Standard',
            price: 25.0,
            currency: 'KM',
            capacity: 200,
            sold: 120,
          ),
        ],
        coverImageUrl: null,
      ),
    ];
  }
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadViewedEvents();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_useTestData) {
        _loadEvents();
      }
    });
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      print('🟢 HomeScreen: App resumed, reloading viewed events');
      _loadViewedEvents();
    }
  }
  Future<void> _loadViewedEvents() async {
    print('🟢 HomeScreen: Loading viewed events...');
    final viewedIds = await ViewedEventsService.getViewedEvents();
    print('🟢 HomeScreen: Loaded ${viewedIds.length} viewed events: $viewedIds');
    if (mounted) {
      setState(() {
        _viewedEventIds = viewedIds;
      });
      print('🟢 HomeScreen: State updated with viewed events');
    }
  }
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }
  Future<void> _loadEvents() async {
    final eventProvider = context.read<EventProvider>();
    await eventProvider.loadEvents(
      query: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
      category: _selectedCategory,
      city: _selectedCity,
      usePublicEndpoint: true,
    );
  }
  void _onCategorySelected(String? category) {
    setState(() {
      _selectedCategory = category == _selectedCategory ? null : category;
      _updateActiveFilters();
    });
    _applyFilters();
  }
  void _onCitySelected(String city) {
    setState(() {
      _selectedCity = city == _selectedCity ? null : city;
      _updateActiveFilters();
    });
    _applyFilters();
  }
  void _onTimeFilterSelected(String? timeFilter) {
    setState(() {
      _selectedTimeFilter = timeFilter == _selectedTimeFilter ? null : timeFilter;
      _updateActiveFilters();
    });
    _applyFilters();
  }
  void _updateActiveFilters() {
    _hasActiveFilters = _selectedCategory != null || 
                        _selectedCity != null || 
                        _selectedTimeFilter != null ||
                        _searchController.text.trim().isNotEmpty;
  }
  void _clearFilters() {
    setState(() {
      _selectedCategory = null;
      _selectedCity = null;
      _selectedTimeFilter = null;
      _searchController.clear();
      _hasActiveFilters = false;
    });
    _applyFilters();
  }
  bool _matchesTimeFilter(EventDto event) {
    if (_selectedTimeFilter == null) return true;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventStart = DateTime(
      event.startsAt.year,
      event.startsAt.month,
      event.startsAt.day,
    );
    switch (_selectedTimeFilter) {
      case 'today':
        return eventStart.isAtSameMomentAs(today);
      case 'this_week':
        final weekEnd = today.add(const Duration(days: 7));
        return eventStart.isAfter(today.subtract(const Duration(days: 1))) && 
               eventStart.isBefore(weekEnd);
      case 'be_ready':
        final weekEnd = today.add(const Duration(days: 7));
        return eventStart.isAfter(weekEnd) || eventStart.isAtSameMomentAs(weekEnd);
      default:
        return true;
    }
  }
  void _applyFilters() {
    _updateActiveFilters();
    _loadEvents();
  }
  List<EventDto> _getEventsByCategory(List<EventDto> events, String category) {
    return events
        .where((e) => e.category == category && e.isPublished && !e.isDraft)
        .take(10)
        .toList();
  }
  List<EventDto> _getMostPopularEvents(List<EventDto> events, {int limit = 5}) {
    final sortedEvents = List<EventDto>.from(events);
    sortedEvents.sort((a, b) {
      final aTotalSold = a.priceTiers.fold(0, (sum, tier) => sum + tier.sold);
      final bTotalSold = b.priceTiers.fold(0, (sum, tier) => sum + tier.sold);
      return bTotalSold.compareTo(aTotalSold);
    });
    return sortedEvents
        .where((e) => e.priceTiers.any((tier) => tier.sold > 0))
        .take(limit)
        .toList();
  }
  List<Map<String, dynamic>> _getDynamicCategories(List<EventDto> events) {
    final Map<String, int> categoryCount = {};
    for (var event in events) {
      final category = event.category;
      categoryCount[category] = (categoryCount[category] ?? 0) + 1;
    }
    final categories = categoryCount.entries
        .map((entry) => {
              'label': entry.key,
              'value': entry.key,
              'icon': _getCategoryIcon(entry.key),
              'count': entry.value,
            })
        .toList();
    categories.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    return categories;
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              backgroundColor: Colors.white,
              elevation: 0,
              title: Text(
                'karta.ba',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () {
                    _showMenu(context);
                  },
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search events',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _applyFilters();
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _updateActiveFilters();
                    });
                    _searchDebounce?.cancel();
                    if (value.trim().isEmpty) {
                      _applyFilters();
                    } else {
                      _searchDebounce = Timer(const Duration(milliseconds: 500), () {
                        if (mounted) {
                          _applyFilters();
                        }
                      });
                    }
                  },
                  onSubmitted: (_) {
                    _searchDebounce?.cancel();
                    _applyFilters();
                  },
                ),
              ),
            ),
            if (!_hasActiveFilters)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _timeFilters.map((filter) {
                        final isSelected = _selectedTimeFilter == filter['value'];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(filter['label'] as String),
                            avatar: Icon(
                              filter['icon'] as IconData,
                              size: 18,
                              color: isSelected ? Colors.white : AppTheme.primaryColor,
                            ),
                            selected: isSelected,
                            onSelected: (_) => _onTimeFilterSelected(filter['value'] as String),
                            backgroundColor: Colors.white,
                            selectedColor: AppTheme.primaryColor,
                            checkmarkColor: Colors.white,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : AppTheme.textPrimary,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: isSelected ? AppTheme.primaryColor : AppTheme.backgroundGray,
                                width: 1.5,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            if (_hasActiveFilters)
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              if (_selectedCategory != null)
                                Chip(
                                  label: Text(_selectedCategory!),
                                  avatar: Icon(
                                    _getCategoryIcon(_selectedCategory!),
                                    size: 18,
                                  ),
                                  onDeleted: () => _onCategorySelected(_selectedCategory),
                                  deleteIcon: const Icon(Icons.close, size: 18),
                                ),
                              if (_selectedCity != null) ...[
                                const SizedBox(width: 8),
                                Chip(
                                  label: Text(_selectedCity!),
                                  avatar: const Icon(Icons.location_on, size: 18),
                                  onDeleted: () => _onCitySelected(_selectedCity!),
                                  deleteIcon: const Icon(Icons.close, size: 18),
                                ),
                              ],
                              if (_selectedTimeFilter != null) ...[
                                const SizedBox(width: 8),
                                Chip(
                                  label: Text(
                                    _timeFilters.firstWhere((f) => f['value'] == _selectedTimeFilter)['label'] as String,
                                  ),
                                  avatar: Icon(
                                    _timeFilters.firstWhere((f) => f['value'] == _selectedTimeFilter)['icon'] as IconData,
                                    size: 18,
                                  ),
                                  onDeleted: () => _onTimeFilterSelected(_selectedTimeFilter),
                                  deleteIcon: const Icon(Icons.close, size: 18),
                                ),
                              ],
                              if (_searchController.text.trim().isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Chip(
                                  label: Text('"${_searchController.text.trim()}"'),
                                  avatar: const Icon(Icons.search, size: 18),
                                  onDeleted: () {
                                    _searchController.clear();
                                    _applyFilters();
                                  },
                                  deleteIcon: const Icon(Icons.close, size: 18),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _clearFilters,
                        icon: const Icon(Icons.clear_all, size: 18),
                        label: const Text('Clear all'),
                      ),
                    ],
                  ),
                ),
              ),
            if (!_hasActiveFilters)
              _useTestData
                  ? SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: PopularEventsCarousel(
                          events: _getMostPopularEvents(_getTestEvents()),
                          onEventTap: (event) async {
                            await Navigator.pushNamed(
                              context,
                              AppRoutes.eventDetail,
                              arguments: event,
                            );
                            await _loadViewedEvents();
                          },
                        ),
                      ),
                    )
                  : Consumer<EventProvider>(
                      builder: (context, eventProvider, child) {
                        if (!eventProvider.isLoading && eventProvider.error == null) {
                          final allEvents = eventProvider.events?.items ?? [];
                          final publishedEvents = allEvents
                              .where((e) => e.isPublished && !e.isDraft)
                              .toList();
                          final popularEvents = _getMostPopularEvents(publishedEvents);
                          if (popularEvents.isNotEmpty) {
                            return SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                child: PopularEventsCarousel(
                                  events: popularEvents,
                                  onEventTap: (event) async {
                                    await Navigator.pushNamed(
                                      context,
                                      AppRoutes.eventDetail,
                                      arguments: event,
                                    );
                                    await _loadViewedEvents();
                                  },
                                ),
                              ),
                            );
                          }
                        }
                        return const SliverToBoxAdapter(child: SizedBox.shrink());
                      },
                    ),
            _useTestData
                ? SliverToBoxAdapter(
                    child: _buildCategoriesSection(_getTestEvents()),
                  )
                : Consumer<EventProvider>(
                    builder: (context, eventProvider, child) {
                      if (!eventProvider.isLoading && eventProvider.error == null) {
                        final allEvents = eventProvider.events?.items ?? [];
                        final publishedEvents = allEvents
                            .where((e) => e.isPublished && !e.isDraft)
                            .toList();
                        if (publishedEvents.isNotEmpty) {
                          return SliverToBoxAdapter(
                            child: _buildCategoriesSection(publishedEvents),
                          );
                        }
                      }
                      return const SliverToBoxAdapter(child: SizedBox.shrink());
                    },
                  ),
            _useTestData
                ? SliverToBoxAdapter(
                    child: _buildTestEventsList(),
                  )
                : Consumer<EventProvider>(
                    builder: (context, eventProvider, child) {
                      if (eventProvider.isLoading) {
                        return const SliverToBoxAdapter(
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: CircularProgressIndicator(),
                            ),
                          ),
                        );
                      }
                      if (eventProvider.error != null) {
                        return SliverToBoxAdapter(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                children: [
                                  Text(
                                    'Error loading events',
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    eventProvider.error!,
                                    style: Theme.of(context).textTheme.bodySmall,
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _loadEvents,
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }
                      final allEvents = eventProvider.events?.items ?? [];
                      final events = allEvents.where((e) => 
                        e.isPublished && !e.isDraft && _matchesTimeFilter(e)
                      ).toList();
                      if (_hasActiveFilters) {
                        if (events.isEmpty) {
                          return SliverToBoxAdapter(
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.search_off,
                                      size: 64,
                                      color: AppTheme.textTertiary,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No events found',
                                      style: Theme.of(context).textTheme.headlineSmall,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Try adjusting your filters or search terms',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: AppTheme.textSecondary,
                                          ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 24),
                                    ElevatedButton.icon(
                                      onPressed: _clearFilters,
                                      icon: const Icon(Icons.clear_all),
                                      label: const Text('Clear all filters'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }
                        return SliverList(
                          delegate: SliverChildListDelegate([
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Found ${events.length} event${events.length == 1 ? '' : 's'}',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          color: AppTheme.textSecondary,
                                        ),
                                  ),
                                  if (events.isNotEmpty)
                                    TextButton.icon(
                                      onPressed: _clearFilters,
                                      icon: const Icon(Icons.filter_alt_off, size: 18),
                                      label: const Text('Clear'),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 280,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.only(left: 16, right: 4),
                                itemCount: events.length,
                                itemBuilder: (context, index) {
                                  return EventCard(
                                    event: events[index],
                                    onTap: () async {
                                      await Navigator.pushNamed(
                                        context,
                                        AppRoutes.eventDetail,
                                        arguments: events[index],
                                      );
                                      await _loadViewedEvents();
                                    },
                                  );
                                },
                              ),
                            ),
                            if (_viewedEventIds.isNotEmpty) ...[
                              const SizedBox(height: 24),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.history,
                                          color: AppTheme.primaryColor,
                                          size: 24,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Still interested?',
                                          style: Theme.of(context).textTheme.headlineSmall,
                                        ),
                                      ],
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        await ViewedEventsService.clearViewedEvents();
                                        await _loadViewedEvents();
                                      },
                                      child: const Text('Clear'),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  'Events you recently viewed',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 280,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.only(left: 16, right: 4),
                                  itemCount: _viewedEventIds.length,
                                  itemBuilder: (context, index) {
                                    final eventId = _viewedEventIds[index];
                                    final allEventsList = eventProvider.events?.items ?? [];
                                    final event = allEventsList.cast<EventDto?>().firstWhere(
                                      (e) => e?.id == eventId && e!.isPublished && !e.isDraft,
                                      orElse: () => null,
                                    );
                                    if (event == null) {
                                      return const SizedBox.shrink();
                                    }
                                    return EventCard(
                                      event: event,
                                      onTap: () async {
                                        await Navigator.pushNamed(
                                          context,
                                          AppRoutes.eventDetail,
                                          arguments: event,
                                        );
                                        await _loadViewedEvents();
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                            const SizedBox(height: 32),
                          ]),
                        );
                      }
                      if (events.isEmpty) {
                        return const SliverToBoxAdapter(
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.event_busy,
                                    size: 64,
                                    color: AppTheme.textTertiary,
                                  ),
                                  SizedBox(height: 16),
                                  Text('No events available'),
                                  SizedBox(height: 8),
                                  Text(
                                    'Check back later for new events',
                                    style: TextStyle(color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }
                      final cultureEvents = _getEventsByCategory(events, 'Culture');
                      final sportEvents = _getEventsByCategory(events, 'Sport');
                      final musicEvents = _getEventsByCategory(events, 'Music');
                      final filmEvents = _getEventsByCategory(events, 'Film');
                      return SliverList(
                        delegate: SliverChildListDelegate([
                          if (cultureEvents.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'Culture events',
                                style: Theme.of(context).textTheme.headlineSmall,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 280,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.only(left: 16, right: 4),
                                itemCount: cultureEvents.length,
                                itemBuilder: (context, index) {
                                  return EventCard(
                                    event: cultureEvents[index],
                                    onTap: () async {
                                      await Navigator.pushNamed(
                                        context,
                                        AppRoutes.eventDetail,
                                        arguments: cultureEvents[index],
                                      );
                                      await _loadViewedEvents();
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                          if (sportEvents.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'Sport events',
                                style: Theme.of(context).textTheme.headlineSmall,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 280,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.only(left: 16, right: 4),
                                itemCount: sportEvents.length,
                                itemBuilder: (context, index) {
                                  return EventCard(
                                    event: sportEvents[index],
                                    onTap: () async {
                                      await Navigator.pushNamed(
                                        context,
                                        AppRoutes.eventDetail,
                                        arguments: sportEvents[index],
                                      );
                                      await _loadViewedEvents();
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                          if (musicEvents.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'Music events',
                                style: Theme.of(context).textTheme.headlineSmall,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 280,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.only(left: 16, right: 4),
                                itemCount: musicEvents.length,
                                itemBuilder: (context, index) {
                                  return EventCard(
                                    event: musicEvents[index],
                                    onTap: () async {
                                      await Navigator.pushNamed(
                                        context,
                                        AppRoutes.eventDetail,
                                        arguments: musicEvents[index],
                                      );
                                      await _loadViewedEvents();
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                          if (filmEvents.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'Film events',
                                style: Theme.of(context).textTheme.headlineSmall,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 280,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.only(left: 16, right: 4),
                                itemCount: filmEvents.length,
                                itemBuilder: (context, index) {
                                  return EventCard(
                                    event: filmEvents[index],
                                    onTap: () async {
                                      await Navigator.pushNamed(
                                        context,
                                        AppRoutes.eventDetail,
                                        arguments: filmEvents[index],
                                      );
                                      await _loadViewedEvents();
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'Popular cities',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: _popularCities.map((city) {
                                final isSelected = _selectedCity == city;
                                return ChoiceChip(
                                  label: Text(city),
                                  selected: isSelected,
                                  onSelected: (_) => _onCitySelected(city),
                                  backgroundColor: AppTheme.backgroundGray,
                                  selectedColor: AppTheme.primaryColor,
                                  labelStyle: TextStyle(
                                    color: isSelected ? Colors.white : AppTheme.textSecondary,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          if (_viewedEventIds.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.history,
                                        color: AppTheme.primaryColor,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Still interested?',
                                        style: Theme.of(context).textTheme.headlineSmall,
                                      ),
                                    ],
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      await ViewedEventsService.clearViewedEvents();
                                      await _loadViewedEvents();
                                    },
                                    child: const Text('Clear'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'Events you recently viewed',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 280,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.only(left: 16, right: 4),
                                itemCount: _viewedEventIds.length,
                                itemBuilder: (context, index) {
                                  final eventId = _viewedEventIds[index];
                                  final event = events.cast<EventDto?>().firstWhere(
                                    (e) => e?.id == eventId,
                                    orElse: () => null,
                                  );
                                  if (event == null) {
                                    return const SizedBox.shrink();
                                  }
                                  return EventCard(
                                    event: event,
                                    onTap: () async {
                                      await Navigator.pushNamed(
                                        context,
                                        AppRoutes.eventDetail,
                                        arguments: event,
                                      );
                                      await _loadViewedEvents();
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                          const SizedBox(height: 32),
                        ]),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
  Widget _buildTestEventsList() {
    final allEvents = _getTestEvents();
    final publishedEvents = allEvents.where((e) => e.isPublished && !e.isDraft).toList();
    final cultureEvents = _getEventsByCategory(publishedEvents, 'Culture');
    final sportEvents = _getEventsByCategory(publishedEvents, 'Sport');
    return Column(
      children: [
        if (cultureEvents.isNotEmpty) ...[
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Culture events',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 280,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 16, right: 4),
              itemCount: cultureEvents.length,
              itemBuilder: (context, index) {
                return EventCard(
                  event: cultureEvents[index],
                  onTap: () async {
                    await Navigator.pushNamed(
                      context,
                      AppRoutes.eventDetail,
                      arguments: cultureEvents[index],
                    );
                    await _loadViewedEvents();
                  },
                );
              },
            ),
          ),
        ],
        if (sportEvents.isNotEmpty) ...[
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Sport events',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 280,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 16, right: 4),
              itemCount: sportEvents.length,
              itemBuilder: (context, index) {
                return EventCard(
                  event: sportEvents[index],
                  onTap: () async {
                    await Navigator.pushNamed(
                      context,
                      AppRoutes.eventDetail,
                      arguments: sportEvents[index],
                    );
                    await _loadViewedEvents();
                  },
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Popular cities',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _popularCities.map((city) {
              final isSelected = _selectedCity == city;
              return ChoiceChip(
                label: Text(city),
                selected: isSelected,
                onSelected: (_) => _onCitySelected(city),
                backgroundColor: AppTheme.backgroundGray,
                selectedColor: AppTheme.primaryColor,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppTheme.textSecondary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              );
            }).toList(),
          ),
        ),
        if (_viewedEventIds.isNotEmpty) ...[
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.history,
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Still interested?',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () async {
                    await ViewedEventsService.clearViewedEvents();
                    await _loadViewedEvents();
                  },
                  child: const Text('Clear'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Events you recently viewed',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 280,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 16, right: 4),
              itemCount: _viewedEventIds.length,
              itemBuilder: (context, index) {
                final eventId = _viewedEventIds[index];
                final event = publishedEvents.cast<EventDto?>().firstWhere(
                  (e) => e?.id == eventId,
                  orElse: () => null,
                );
                if (event == null) {
                  return const SizedBox.shrink();
                }
                return EventCard(
                  event: event,
                  onTap: () async {
                    await Navigator.pushNamed(
                      context,
                      AppRoutes.eventDetail,
                      arguments: event,
                    );
                    await _loadViewedEvents();
                  },
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 32),
      ],
    );
  }
  Widget _buildCategoriesSection(List<EventDto> events) {
    final categories = _getDynamicCategories(events);
    if (categories.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Categories',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${categories.length}',
                  style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                final eventCount = category['count'] as int;
                return Stack(
                  children: [
                    CategoryButton(
                      icon: category['icon'] as IconData,
                      label: category['label'] as String,
                      isSelected: _selectedCategory == category['value'],
                      onTap: () => _onCategorySelected(category['value'] as String),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _selectedCategory == category['value']
                              ? Colors.white
                              : AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$eventCount',
                          style: TextStyle(
                            color: _selectedCategory == category['value']
                                ? AppTheme.primaryColor
                                : Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  void _showMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        final authProvider = context.read<AuthProvider>();
        final user = authProvider.currentUser;
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (user != null) ...[
                InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.profile);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${user.firstName.isNotEmpty ? user.firstName[0] : ''}${user.lastName.isNotEmpty ? user.lastName[0] : ''}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${user.firstName} ${user.lastName}',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                user.email,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: AppTheme.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 32),
              ],
              ListTile(
                leading: const Icon(Icons.confirmation_number_outlined),
                title: const Text('My Tickets'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, AppRoutes.tickets);
                },
              ),
              ListTile(
                leading: const Icon(Icons.event_outlined),
                title: const Text('My Events'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, AppRoutes.myEvents);
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('My Profile'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, AppRoutes.profile);
                },
              ),
              const Divider(height: 16),
              ListTile(
                leading: const Icon(Icons.logout, color: AppTheme.error),
                title: const Text('Logout', style: TextStyle(color: AppTheme.error)),
                onTap: () async {
                  await authProvider.logout();
                  if (context.mounted) {
                    Navigator.pop(context);
                    Navigator.pushReplacementNamed(context, AppRoutes.login);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}