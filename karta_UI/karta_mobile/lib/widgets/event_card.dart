import 'package:flutter/material.dart';
import 'package:karta_shared/karta_shared.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
class EventCard extends StatelessWidget {
  final EventDto event;
  final VoidCallback onTap;
  final bool showFavoriteButton;
  const EventCard({
    super.key,
    required this.event,
    required this.onTap,
    this.showFavoriteButton = true,
  });
  String _formatDate(DateTime date) {
    final dateTime = date.toLocal();
    return DateFormat('EEE - d.M', 'bs').format(dateTime);
  }
  String _formatPrice(List<PriceTierDto> tiers) {
    if (tiers.isEmpty) return 'N/A';
    final minPrice = tiers.map((t) => t.price).reduce((a, b) => a < b ? a : b);
    return 'From ${minPrice.toStringAsFixed(0)}KM';
  }
  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final favoritesProvider = context.watch<FavoritesProvider>();
    final isAuthenticated = authProvider.isAuthenticated;
    final isFavorite = favoritesProvider.isFavorite(event.id);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  height: 140,
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundGray,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    image: event.coverImageUrl != null
                        ? DecorationImage(
                            image: NetworkImage(ApiClient.getImageUrl(event.coverImageUrl!) ?? ''),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: event.coverImageUrl == null
                      ? const Center(
                          child: Icon(
                            Icons.image_outlined,
                            size: 48,
                            color: AppTheme.textTertiary,
                          ),
                        )
                      : null,
                ),
                if (showFavoriteButton && isAuthenticated)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () {
                        favoritesProvider.toggleFavorite(event.id, event: event);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          size: 20,
                          color: isFavorite ? Colors.red : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatDate(event.startsAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${event.venue}, ${event.city}',
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatPrice(event.priceTiers),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}