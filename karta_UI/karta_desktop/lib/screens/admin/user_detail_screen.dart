import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/organizer_provider.dart';
import '../../model/event/event_dto.dart';
import 'order_detail_screen.dart';
class UserDetailScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final bool initialEditMode;
  final bool isOwnProfile;
  const UserDetailScreen({
    super.key,
    required this.user,
    this.initialEditMode = false,
    this.isOwnProfile = false,
  });
  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}
class _UserDetailScreenState extends State<UserDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;
  late bool _emailConfirmed;
  late String _userId;
  late Set<String> _currentRoles;
  bool _isOrganizerVerified = false;
  bool _isVerifyingOrganizer = false;
  final List<String> _availableRoles = ['User', 'Organizer', 'Scanner', 'Admin'];
  bool _isEditing = false;
  bool _isSaving = false;
  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.user['firstName'] as String? ?? '');
    _lastNameController = TextEditingController(text: widget.user['lastName'] as String? ?? '');
    _emailController = TextEditingController(text: widget.user['email'] as String? ?? '');
    _emailConfirmed = widget.user['emailConfirmed'] == true;
    _userId = (widget.user['id'] ?? widget.user['Id']) as String? ?? '';
    _isOrganizerVerified = widget.user['isOrganizerVerified'] == true ||
        widget.user['IsOrganizerVerified'] == true;
    final initialRoles = (widget.user['roles'] as List<dynamic>? ?? [])
        .map((r) => r.toString())
        .toList();
    _currentRoles = Set<String>.from(initialRoles);
    _isEditing = widget.initialEditMode;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_isViewingOwnOrganizerProfile) {
        final organizerProvider = Provider.of<OrganizerProvider>(context, listen: false);
        if (!organizerProvider.isLoadingMyEvents) {
          organizerProvider.loadMyEvents();
        }
      } else {
        final adminProvider = Provider.of<AdminProvider>(context, listen: false);
        adminProvider.loadUserOrders(_userId);
      }
    });
  }
  bool get _isViewingOwnOrganizerProfile =>
      widget.isOwnProfile && _currentRoles.contains('Organizer');
  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }
  Color _getRoleColor(String role) {
    switch (role) {
      case 'Admin':
        return Colors.red;
      case 'Organizer':
        return Colors.blue;
      case 'Scanner':
        return Colors.green;
      case 'User':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }
  String get _fullName {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    return '$firstName $lastName'.trim().isEmpty ? 'Nepoznat korisnik' : '$firstName $lastName';
  }
  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isSaving = true;
    });
    bool success = false;
    String? errorMessage;
    if (widget.isOwnProfile) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      success = await authProvider.updateProfile(
        _firstNameController.text.trim().isNotEmpty 
            ? _firstNameController.text.trim() 
            : '',
        _lastNameController.text.trim().isNotEmpty 
            ? _lastNameController.text.trim() 
            : '',
      );
      errorMessage = authProvider.error;
      if (success) {
        final user = authProvider.currentUser;
        if (user != null) {
          _firstNameController.text = user.firstName;
          _lastNameController.text = user.lastName;
          _emailController.text = user.email;
          _emailConfirmed = user.emailConfirmed;
          _currentRoles = Set<String>.from(user.roles);
        }
      }
    } else {
      final adminProvider = Provider.of<AdminProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      success = await adminProvider.updateUser(
        userId: _userId,
        firstName: _firstNameController.text.trim().isNotEmpty 
            ? _firstNameController.text.trim() 
            : null,
        lastName: _lastNameController.text.trim().isNotEmpty 
            ? _lastNameController.text.trim() 
            : null,
        email: null,
        emailConfirmed: _emailConfirmed,
      );
      errorMessage = adminProvider.usersError;
      if (success && authProvider.currentUser?.id == _userId) {
        await authProvider.refreshCurrentUser();
      }
      if (success) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            adminProvider.loadUserOrders(_userId);
          }
        });
      }
    }
    if (mounted) {
      setState(() {
        _isSaving = false;
        if (success) {
          _isEditing = false;
        }
      });
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Korisnik je uspješno ažuriran'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorMessage ?? 'Greška pri ažuriranju korisnika',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  Future<void> _handleRoleToggle(String role, bool value) async {
    if (widget.isOwnProfile) {
      return;
    }
    final adminProvider = Provider.of<AdminProvider>(context, listen: false);
    if (value) {
      final success = await adminProvider.addUserToRole(_userId, role);
      if (mounted) {
        if (success) {
          setState(() {
            _currentRoles.add(role);
            if (role == 'Organizer') {
              _isOrganizerVerified = false;
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Rola $role je dodana korisniku'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
          adminProvider.loadUsers();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                adminProvider.usersError ?? 'Greška pri dodavanju role',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      final success = await adminProvider.removeUserFromRole(_userId, role);
      if (mounted) {
        if (success) {
          setState(() {
            _currentRoles.remove(role);
            if (role == 'Organizer') {
              _isOrganizerVerified = false;
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Rola $role je uklonjena od korisnika'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
          adminProvider.loadUsers();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                adminProvider.usersError ?? 'Greška pri uklanjanju role',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
  Future<void> _handleOrganizerVerificationToggle(bool value) async {
    if (widget.isOwnProfile) return;
    setState(() {
      _isVerifyingOrganizer = true;
    });
    final adminProvider = Provider.of<AdminProvider>(context, listen: false);
    final success = await adminProvider.setOrganizerVerification(_userId, value);
    if (!mounted) return;
    setState(() {
      _isVerifyingOrganizer = false;
      if (success) {
        _isOrganizerVerified = value;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? (value
                  ? 'Organizer je uspješno verifikovan'
                  : 'Verifikacija organizatora je uklonjena')
              : adminProvider.usersError ?? 'Greška pri ažuriranju verifikacije',
        ),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }
  void _loadUserData() {
    _firstNameController.text = widget.user['firstName'] as String? ?? '';
    _lastNameController.text = widget.user['lastName'] as String? ?? '';
    _emailController.text = widget.user['email'] as String? ?? '';
    _emailConfirmed = widget.user['emailConfirmed'] == true;
    _isOrganizerVerified = widget.user['isOrganizerVerified'] == true ||
        widget.user['IsOrganizerVerified'] == true;
    final initialRoles = (widget.user['roles'] as List<dynamic>? ?? [])
        .map((r) => r.toString())
        .toList();
    _currentRoles = Set<String>.from(initialRoles);
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.grey.shade900),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (!_isEditing)
            IconButton(
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
              icon: Icon(Icons.edit_outlined, color: Colors.grey.shade900),
            ),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            flex: 1,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _TicketHeader(
                    fullName: _fullName,
                    email: _emailController.text,
                    roles: _currentRoles.toList(),
                    isEditing: _isEditing,
                    isSaving: _isSaving,
                    onEditToggle: () {
                      setState(() {
                        _isEditing = !_isEditing;
                        if (!_isEditing) {
                          _loadUserData();
                        }
                      });
                    },
                    onSave: _handleSave,
                  ),
                  _PerforatedDivider(),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 700),
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Form(
                          key: _formKey,
                          child: _TicketBody(
                            firstNameController: _firstNameController,
                            lastNameController: _lastNameController,
                            emailController: _emailController,
                            emailConfirmed: _emailConfirmed,
                            currentRoles: _currentRoles,
                            availableRoles: _availableRoles,
                            isEditing: _isEditing,
                            isOwnProfile: widget.isOwnProfile,
                            isOrganizerVerified: _isOrganizerVerified,
                            showOrganizerVerification: !widget.isOwnProfile && _currentRoles.contains('Organizer'),
                            isVerificationInProgress: _isVerifyingOrganizer,
                            onOrganizerVerificationChanged: widget.isOwnProfile
                                ? null
                                : _handleOrganizerVerificationToggle,
                            onEditToggle: () {
                              setState(() {
                                _isEditing = true;
                              });
                            },
                            onEmailConfirmedChanged: (value) {
                              setState(() {
                                _emailConfirmed = value;
                              });
                            },
                            onRoleToggle: _handleRoleToggle,
                            getRoleColor: _getRoleColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: 1,
            color: Colors.grey.shade300,
          ),
          Expanded(
            flex: 1,
            child: _isViewingOwnOrganizerProfile
                ? const _OrganizerProfileStatsPanel()
                : _UserOrdersList(userId: _userId),
          ),
        ],
      ),
    );
  }
}
class _TicketHeader extends StatelessWidget {
  final String fullName;
  final String email;
  final List<String> roles;
  final bool isEditing;
  final bool isSaving;
  final VoidCallback onEditToggle;
  final VoidCallback onSave;
  const _TicketHeader({
    required this.fullName,
    required this.email,
    required this.roles,
    required this.isEditing,
    required this.isSaving,
    required this.onEditToggle,
    required this.onSave,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withOpacity(0.8),
          ],
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.confirmation_number,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            fullName,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            email,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.9),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          if (roles.isNotEmpty)
            Wrap(
              spacing: 8,
              alignment: WrapAlignment.center,
              children: roles.map<Widget>((role) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.5),
                    width: 1,
                  ),
                ),
                child: Text(
                  role,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              )).toList(),
            ),
          if (roles.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.5),
                  width: 1,
                ),
              ),
              child: const Text(
                'Nema rola',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          if (isEditing) ...[
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () {
                    onEditToggle();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: isSaving ? null : onSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save Changes'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
class _PerforatedDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 20,
      child: CustomPaint(
        painter: _PerforationPainter(),
        size: Size.infinite,
      ),
    );
  }
}
class _TicketBody extends StatelessWidget {
  final TextEditingController firstNameController;
  final TextEditingController lastNameController;
  final TextEditingController emailController;
  final bool emailConfirmed;
  final Set<String> currentRoles;
  final List<String> availableRoles;
  final bool isEditing;
  final bool isOwnProfile;
  final bool showOrganizerVerification;
  final bool isOrganizerVerified;
  final bool isVerificationInProgress;
  final VoidCallback onEditToggle;
  final ValueChanged<bool> onEmailConfirmedChanged;
  final Function(String, bool) onRoleToggle;
  final ValueChanged<bool>? onOrganizerVerificationChanged;
  final Color Function(String) getRoleColor;
  const _TicketBody({
    required this.firstNameController,
    required this.lastNameController,
    required this.emailController,
    required this.emailConfirmed,
    required this.currentRoles,
    required this.availableRoles,
    required this.isEditing,
    this.isOwnProfile = false,
    this.showOrganizerVerification = false,
    required this.isOrganizerVerified,
    this.isVerificationInProgress = false,
    required this.onEditToggle,
    required this.onEmailConfirmedChanged,
    required this.onRoleToggle,
    this.onOrganizerVerificationChanged,
    required this.getRoleColor,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'PROFILE INFORMATION',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
                letterSpacing: 2,
              ),
            ),
            if (!isEditing)
              TextButton.icon(
                onPressed: onEditToggle,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),
        _TicketField(
          label: 'First Name',
          controller: firstNameController,
          enabled: isEditing,
          icon: Icons.person_outline,
          validator: (value) {
            if (value != null && value.trim().isNotEmpty && value.length > 50) {
              return 'Ime ne može biti duže od 50 karaktera';
            }
            return null;
          },
        ),
        const SizedBox(height: 20),
        _TicketField(
          label: 'Last Name',
          controller: lastNameController,
          enabled: isEditing,
          icon: Icons.person_outline,
          validator: (value) {
            if (value != null && value.trim().isNotEmpty && value.length > 50) {
              return 'Prezime ne može biti duže od 50 karaktera';
            }
            return null;
          },
        ),
        const SizedBox(height: 20),
        _TicketField(
          label: 'Email',
          controller: emailController,
          enabled: false,
          icon: Icons.email_outlined,
          validator: (value) {
            if (value != null && value.trim().isNotEmpty) {
              if (!value.contains('@') || !value.contains('.')) {
                return 'Neispravna email adresa';
              }
            }
            return null;
          },
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Text(
            'Email cannot be changed',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (!isOwnProfile)
          CheckboxListTile(
            title: const Text('Email potvrđen'),
            value: emailConfirmed,
            enabled: isEditing,
            onChanged: isEditing
                ? (value) {
                    onEmailConfirmedChanged(value ?? false);
                  }
                : null,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
        if (!isOwnProfile) const SizedBox(height: 40),
        if (!isOwnProfile) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ROLE MANAGEMENT',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ...availableRoles.map((role) {
          final hasRole = currentRoles.contains(role);
          final color = getRoleColor(role);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: CheckboxListTile(
              title: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(role),
                ],
              ),
              value: hasRole,
              enabled: isEditing,
              onChanged: isEditing
                  ? (value) {
                      onRoleToggle(role, value ?? false);
                    }
                  : null,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
          );
          }),
        ],
        if (!isOwnProfile && showOrganizerVerification) ...[
          const SizedBox(height: 32),
          Text(
            'ORGANIZER VERIFICATION',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isOrganizerVerified ? Colors.green.shade200 : Colors.orange.shade200,
              ),
              color: (isOrganizerVerified ? Colors.green : Colors.orange).withOpacity(0.05),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isOrganizerVerified ? Icons.verified_outlined : Icons.hourglass_bottom_outlined,
                      color: isOrganizerVerified ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isOrganizerVerified ? 'Verified organizer' : 'Pending verification',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isOrganizerVerified ? Colors.green.shade800 : Colors.orange.shade800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  isOrganizerVerified
                      ? 'Korisnik može objavljivati svoje događaje.'
                      : 'Korisnik ne može objaviti događaj dok admin ne potvrdi organizatora.',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ElevatedButton.icon(
                      onPressed: (onOrganizerVerificationChanged == null || isVerificationInProgress)
                          ? null
                          : () => onOrganizerVerificationChanged!.call(!isOrganizerVerified),
                      icon: isVerificationInProgress
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              isOrganizerVerified ? Icons.shield_moon_outlined : Icons.verified_user_outlined,
                            ),
                      label: Text(
                        isOrganizerVerified ? 'Remove verification' : 'Verify organizer',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isOrganizerVerified ? Colors.redAccent : Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
class _TicketField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool enabled;
  final IconData icon;
  final bool obscureText;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  const _TicketField({
    required this.label,
    required this.controller,
    required this.enabled,
    required this.icon,
    this.obscureText = false,
    this.suffixIcon,
    this.validator,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: enabled,
          obscureText: obscureText,
          validator: validator,
          style: TextStyle(
            fontSize: 16,
            color: enabled ? Colors.grey.shade900 : Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.grey.shade400),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: enabled ? Colors.grey.shade50 : Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
        ],
    );
  }
}
class _PerforationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade300
      ..style = PaintingStyle.fill;
    final double spacing = 8;
    final double radius = 3;
    for (double x = spacing; x < size.width; x += spacing * 2) {
      canvas.drawCircle(Offset(x, size.height / 2), radius, paint);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
class _OrganizerProfileStatsPanel extends StatefulWidget {
  const _OrganizerProfileStatsPanel();
  @override
  State<_OrganizerProfileStatsPanel> createState() => _OrganizerProfileStatsPanelState();
}
class _OrganizerProfileStatsPanelState extends State<_OrganizerProfileStatsPanel> {
  bool _initialized = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final organizerProvider = Provider.of<OrganizerProvider>(context, listen: false);
      if (!organizerProvider.isLoadingMyEvents && organizerProvider.myEvents.isEmpty) {
        organizerProvider.loadMyEvents();
      }
      _initialized = true;
    }
  }
  @override
  Widget build(BuildContext context) {
    return Consumer<OrganizerProvider>(
      builder: (context, organizerProvider, child) {
        final events = organizerProvider.myEvents;
        if (organizerProvider.isLoadingMyEvents && events.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (organizerProvider.myEventsError != null && events.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade600, size: 48),
                const SizedBox(height: 12),
                Text(
                  'Greška pri učitavanju događaja',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  organizerProvider.myEventsError ?? '',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: organizerProvider.refreshMyEvents,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Pokušaj ponovo'),
                ),
              ],
            ),
          );
        }
        final displayedEvents = events.take(5).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pregled organizatora',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Brzi pregled performansi tvojih događaja.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Osvježi podatke',
                    onPressed: organizerProvider.refreshMyEvents,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _ProfileStatCard(
                          label: 'Ukupno događaja',
                          value: organizerProvider.totalEvents.toString(),
                          icon: Icons.event,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ProfileStatCard(
                          label: 'Objavljeni',
                          value: organizerProvider.publishedEvents.toString(),
                          icon: Icons.check_circle,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _ProfileStatCard(
                          label: 'Skice',
                          value: organizerProvider.draftEvents.toString(),
                          icon: Icons.edit_note,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ProfileStatCard(
                          label: 'Nadolazeći',
                          value: organizerProvider.upcomingEventsCount.toString(),
                          icon: Icons.schedule,
                          color: Colors.purple,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Text(
                    'Moji događaji',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Text(
                    '${events.length} ukupno',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: displayedEvents.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.event_busy, color: Colors.grey.shade500, size: 48),
                          const SizedBox(height: 12),
                          Text(
                            'Još nema događaja',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Kreiraj događaj kako bi ovdje vidio statistiku.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey.shade600,
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: displayedEvents.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final event = displayedEvents[index];
                        return _OrganizerEventTile(event: event);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
class _ProfileStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _ProfileStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
class _OrganizerEventTile extends StatelessWidget {
  final EventDto event;
  const _OrganizerEventTile({required this.event});
  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d. MMM yyyy • HH:mm');
    final statusColor = _statusColor(event.status, context);
    final lowestPrice = event.priceTiers.isNotEmpty
        ? event.priceTiers.map((tier) => tier.price).reduce((a, b) => a < b ? a : b)
        : 0.0;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    event.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    event.status,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    dateFormat.format(event.startsAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.place_outlined, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${event.venue}, ${event.city}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _EventSummaryChip(
                  icon: Icons.confirmation_number_outlined,
                  label: '${event.totalSold}/${event.totalCapacity} karata',
                ),
                _EventSummaryChip(
                  icon: Icons.attach_money,
                  label: 'Od ${lowestPrice.toStringAsFixed(2)} BAM',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  Color _statusColor(String status, BuildContext context) {
    switch (status.toLowerCase()) {
      case 'published':
        return Colors.green.shade600;
      case 'draft':
        return Colors.orange.shade600;
      case 'archived':
        return Colors.red.shade600;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }
}
class _EventSummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _EventSummaryChip({
    required this.icon,
    required this.label,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade700),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
          ),
        ],
      ),
    );
  }
}
class _UserOrdersList extends StatefulWidget {
  final String userId;
  const _UserOrdersList({required this.userId});
  @override
  State<_UserOrdersList> createState() => _UserOrdersListState();
}
class _UserOrdersListState extends State<_UserOrdersList> with AutomaticKeepAliveClientMixin {
  List<dynamic> _cachedOrders = [];
  @override
  bool get wantKeepAlive => true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final adminProvider = Provider.of<AdminProvider>(context, listen: false);
        adminProvider.loadUserOrders(widget.userId);
      }
    });
  }
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Consumer<AdminProvider>(
      builder: (context, adminProvider, child) {
        if (adminProvider.userOrders.isNotEmpty) {
          _cachedOrders = List<dynamic>.from(adminProvider.userOrders);
        }
        final orders = _cachedOrders.isNotEmpty ? _cachedOrders : adminProvider.userOrders;
        if (adminProvider.isLoadingUserOrders && orders.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }
        if (adminProvider.userOrdersError != null && orders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                Text(
                  'Greška pri učitavanju narudžbi',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  adminProvider.userOrdersError!,
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    adminProvider.loadUserOrders(widget.userId);
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Pokušaj ponovo'),
                ),
              ],
            ),
          );
        }
        if (orders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.shopping_cart_outlined,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'Nema narudžbi',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Korisnik još nije napravio nijednu narudžbu.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.shopping_cart,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Narudžbe korisnika',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const Spacer(),
                  Text(
                    '${orders.length} ${orders.length == 1 ? 'narudžba' : 'narudžbi'}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final order = orders[index];
                  return _OrderCard(
                    order: order,
                    onTap: () {
                      final orderId = order['id'] as String? ?? '';
                      if (orderId.isNotEmpty) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => OrderDetailScreen(orderId: orderId),
                          ),
                        );
                      }
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback? onTap;
  const _OrderCard({required this.order, this.onTap});
  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');
    final createdAt = order['createdAt'] != null
        ? DateTime.parse(order['createdAt'] as String)
        : null;
    final totalAmount = (order['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final currency = order['currency'] as String? ?? 'BAM';
    final status = order['status'] as String? ?? 'Unknown';
    final items = order['items'] as List<dynamic>? ?? [];
    int totalTickets = 0;
    for (var item in items) {
      final tickets = item['tickets'] as List<dynamic>? ?? [];
      totalTickets += tickets.length;
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Narudžba #${(order['id'] as String? ?? '').substring(0, 8)}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      if (createdAt != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 14,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              dateFormat.format(createdAt),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                _StatusChip(status: status),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.confirmation_number,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  '$totalTickets ${totalTickets == 1 ? 'karta' : 'karata'}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.shopping_bag,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  '${items.length} ${items.length == 1 ? 'stavka' : 'stavki'}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Ukupno:',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
                Text(
                  '${totalAmount.toStringAsFixed(2)} $currency',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }
}
class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'paid':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
  @override
  Widget build(BuildContext context) {
    final color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}