import 'package:flutter/material.dart';
import 'package:karta_shared/karta_shared.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
class PopularEventsCarousel extends StatefulWidget {
  final List<EventDto> events;
  final Function(EventDto) onEventTap;
  const PopularEventsCarousel({
    super.key,
    required this.events,
    required this.onEventTap,
  });
  @override
  State<PopularEventsCarousel> createState() => _PopularEventsCarouselState();
}
class _PopularEventsCarouselState extends State<PopularEventsCarousel> {
  late PageController _pageController;
  int _currentPage = 0;
  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.9);
    _pageController.addListener(() {
      int next = _pageController.page!.round();
      if (_currentPage != next) {
        setState(() {
          _currentPage = next;
        });
      }
    });
  }
  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
  String _formatDate(DateTime date) {
    final dateTime = date.toLocal();
    return DateFormat('EEE, d MMM yyyy • HH:mm', 'bs').format(dateTime);
  }
  String _formatPrice(List<PriceTierDto> tiers) {
    if (tiers.isEmpty) return 'N/A';
    final minPrice = tiers.map((t) => t.price).reduce((a, b) => a < b ? a : b);
    return 'From ${minPrice.toStringAsFixed(0)} KM';
  }
  int _getTotalSoldTickets(EventDto event) {
    return event.priceTiers.fold(0, (sum, tier) => sum + tier.sold);
  }
  @override
  Widget build(BuildContext context) {
    if (widget.events.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(
                Icons.local_fire_department,
                color: AppTheme.warning,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Most Popular',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 240,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.events.length,
            itemBuilder: (context, index) {
              final event = widget.events[index];
              final isActive = index == _currentPage;
              final totalSold = _getTotalSoldTickets(event);
              return AnimatedScale(
                scale: isActive ? 1.0 : 0.95,
                duration: const Duration(milliseconds: 300),
                child: GestureDetector(
                  onTap: () => widget.onEventTap(event),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isActive ? 0.15 : 0.08),
                          blurRadius: isActive ? 20 : 10,
                          offset: Offset(0, isActive ? 8 : 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: event.coverImageUrl != null
                                ? Image.network(
                                    ApiClient.getImageUrl(event.coverImageUrl!) ?? '',
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: AppTheme.backgroundGray,
                                        child: const Center(
                                          child: Icon(
                                            Icons.image_outlined,
                                            size: 64,
                                            color: AppTheme.textTertiary,
                                          ),
                                        ),
                                      );
                                    },
                                  )
                                : Container(
                                    color: AppTheme.backgroundGray,
                                    child: const Center(
                                      child: Icon(
                                        Icons.image_outlined,
                                        size: 64,
                                        color: AppTheme.textTertiary,
                                      ),
                                    ),
                                  ),
                          ),
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.8),
                                  ],
                                  stops: const [0.3, 1.0],
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.warning,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.local_fire_department,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$totalSold sold',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            left: 16,
                            right: 16,
                            bottom: 16,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    event.category,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  event.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_today,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        _formatDate(event.startsAt),
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.9),
                                          fontSize: 12,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        '${event.venue}, ${event.city}',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.9),
                                          fontSize: 12,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _formatPrice(event.priceTiers),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        if (widget.events.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.events.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 8,
                width: _currentPage == index ? 24 : 8,
                decoration: BoxDecoration(
                  color: _currentPage == index
                      ? AppTheme.primaryColor
                      : AppTheme.textTertiary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
      ],
    );
  }
}