import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:karta_shared/karta_shared.dart';
import '../../config/theme.dart';
import '../../providers/reviews_provider.dart';

class WriteReviewScreen extends StatefulWidget {
  const WriteReviewScreen({super.key});

  @override
  State<WriteReviewScreen> createState() => _WriteReviewScreenState();
}

class _WriteReviewScreenState extends State<WriteReviewScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  int _rating = 0;
  bool _isSubmitting = false;
  String? _eventId;
  String? _eventTitle;
  ReviewDto? _existingReview;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      _eventId = args['eventId'] as String?;
      _eventTitle = args['eventTitle'] as String?;
      _existingReview = args['existingReview'] as ReviewDto?;

      if (_existingReview != null) {
        _rating = _existingReview!.rating;
        _titleController.text = _existingReview!.title;
        _contentController.text = _existingReview!.content;
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    if (_eventId == null) return;

    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Molimo odaberite ocjenu'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final reviewsProvider = context.read<ReviewsProvider>();
    bool success;

    if (_existingReview != null) {
      // Update existing review
      success = await reviewsProvider.updateReview(
        _existingReview!.id,
        UpdateReviewRequest(
          rating: _rating,
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
        ),
      );
    } else {
      // Create new review
      success = await reviewsProvider.createReview(
        _eventId!,
        CreateReviewRequest(
          rating: _rating,
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
        ),
      );
    }

    setState(() => _isSubmitting = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_existingReview != null
              ? 'Recenzija uspješno ažurirana'
              : 'Recenzija uspješno poslana'),
          backgroundColor: AppTheme.success,
        ),
      );
      Navigator.of(context).pop(true);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(reviewsProvider.error ?? 'Greška pri slanju recenzije'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  Widget _buildStarRating() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Vaša ocjena',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            final starNumber = index + 1;
            return GestureDetector(
              onTap: () => setState(() => _rating = starNumber),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  starNumber <= _rating ? Icons.star : Icons.star_border,
                  size: 48,
                  color: starNumber <= _rating
                      ? Colors.amber
                      : AppTheme.textTertiary,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            _getRatingText(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: _rating > 0 ? AppTheme.textPrimary : AppTheme.textTertiary,
            ),
          ),
        ),
      ],
    );
  }

  String _getRatingText() {
    switch (_rating) {
      case 1:
        return 'Loše';
      case 2:
        return 'Ispod prosjeka';
      case 3:
        return 'Prosječno';
      case 4:
        return 'Dobro';
      case 5:
        return 'Odlično';
      default:
        return 'Dodirnite zvjezdice za ocjenu';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_existingReview != null ? 'Uredi recenziju' : 'Napiši recenziju'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_eventTitle != null) ...[
                Text(
                  _eventTitle!,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
              ],
              _buildStarRating(),
              const SizedBox(height: 32),
              Text(
                'Naslov',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: 'Kratki naslov vaše recenzije',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                maxLength: 100,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Molimo unesite naslov';
                  }
                  if (value.trim().length < 3) {
                    return 'Naslov mora imati najmanje 3 karaktera';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Vaše iskustvo',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _contentController,
                decoration: InputDecoration(
                  hintText: 'Opišite svoje iskustvo na događaju...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                maxLines: 5,
                maxLength: 1000,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Molimo opišite svoje iskustvo';
                  }
                  if (value.trim().length < 10) {
                    return 'Recenzija mora imati najmanje 10 karaktera';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitReview,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          _existingReview != null ? 'Ažuriraj recenziju' : 'Pošalji recenziju',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
