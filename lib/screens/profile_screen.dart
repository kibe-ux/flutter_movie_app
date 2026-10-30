import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../utils/cinema_palette.dart';
import '../widgets/safe_network_image.dart';
import '../widgets/email_verification_notice.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with WidgetsBindingObserver {
  bool _isLoading = false;
  bool _isSendingVerification = false;
  bool _isRefreshingProfile = false;

  bool get _isBusy =>
      _isLoading || _isSendingVerification || _isRefreshingProfile;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && context.read<AuthService>().isAuthenticated) {
        _refreshUserData(showErrors: false);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    final authService = context.read<AuthService>();
    if (authService.isAuthenticated && !authService.isEmailVerified) {
      _refreshUserData(showErrors: false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _refreshUserData({
    bool showSuccessMessage = false,
    bool checkVerification = false,
    bool showErrors = true,
  }) async {
    if (_isBusy) return;
    setState(() => _isRefreshingProfile = true);
    try {
      final authService = context.read<AuthService>();
      await authService.reloadCurrentUser();
      if (!mounted) return;
      if (showSuccessMessage || checkVerification) {
        final message = checkVerification
            ? authService.isEmailVerified
                ? 'Your email is verified.'
                : 'Confirmation is still pending. Follow the link in your verification email, then check again.'
            : 'Profile refreshed';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              backgroundColor: CinemaPalette.wine,
              content: Text(message,
                  style: const TextStyle(color: CinemaPalette.ivory))),
        );
      }
    } catch (_) {
      if (mounted && showErrors) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: CinemaPalette.wine,
            content: Text(
                'Could not refresh your account. Check your connection and try again.',
                style: TextStyle(color: CinemaPalette.ivory)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRefreshingProfile = false);
    }
  }

  Future<void> _openAccountSettingsDialog(User user) async {
    final changes = await showDialog<_ProfileChanges>(
      context: context,
      builder: (_) => _AccountSettingsDialog(
        displayName: user.displayName ?? '',
        photoUrl: user.photoURL ?? '',
      ),
    );
    if (changes == null || !mounted) return;
    final displayNameInput = changes.displayName;
    final photoUrlInput = changes.photoUrl;

    final currentDisplayName = (user.displayName ?? '').trim();
    final currentPhotoUrl = (user.photoURL ?? '').trim();

    final displayNameUpdate =
        displayNameInput == currentDisplayName ? null : displayNameInput;
    final photoUrlUpdate =
        photoUrlInput == currentPhotoUrl ? null : photoUrlInput;

    if (displayNameUpdate == null && photoUrlUpdate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            backgroundColor: CinemaPalette.wine,
            content: Text('No changes to save',
                style: TextStyle(color: CinemaPalette.ivory))),
      );
      return;
    }

    if (photoUrlUpdate != null && photoUrlUpdate.isNotEmpty) {
      final uri = Uri.tryParse(photoUrlUpdate);
      final isValidWebUrl = uri != null &&
          uri.hasScheme &&
          (uri.scheme == 'http' || uri.scheme == 'https');
      if (!isValidWebUrl) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: CinemaPalette.wine,
            content: Text('Photo URL must start with http:// or https://',
                style: TextStyle(color: CinemaPalette.ivory)),
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      final authService = context.read<AuthService>();
      await authService.updateProfile(
        displayName: displayNameUpdate,
        photoURL: photoUrlUpdate,
      );
      await authService.reloadCurrentUser();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              backgroundColor: CinemaPalette.wine,
              content: Text('Profile updated successfully',
                  style: TextStyle(color: CinemaPalette.ivory))),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: CinemaPalette.wine,
            content: Text(e.message ?? 'Failed to update profile.',
                style: const TextStyle(color: CinemaPalette.ivory)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              backgroundColor: CinemaPalette.wine,
              content: Text('Failed to update profile.',
                  style: TextStyle(color: CinemaPalette.ivory))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signOut() async {
    setState(() => _isLoading = true);

    try {
      final authService = context.read<AuthService>();
      await authService.signOut();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              backgroundColor: CinemaPalette.wine,
              content: Text('Signed out successfully',
                  style: TextStyle(color: CinemaPalette.ivory))),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String errorMessage = 'Error signing out.';
        if (e.code == 'network-request-failed') {
          errorMessage =
              'Network error. Please check your connection and try again.';
        } else {
          errorMessage = e.message ?? errorMessage;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              backgroundColor: CinemaPalette.wine,
              content: Text(errorMessage,
                  style: const TextStyle(color: CinemaPalette.ivory))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              backgroundColor: CinemaPalette.wine,
              content: Text('An unexpected error occurred: ${e.toString()}',
                  style: const TextStyle(color: CinemaPalette.ivory))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteAccount() async {
    final authService = context.read<AuthService>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: CinemaPalette.surface,
        title: const Text(
          'Delete Account',
          style: TextStyle(color: CinemaPalette.ivory),
        ),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone.',
          style: TextStyle(color: CinemaPalette.ivory),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(foregroundColor: CinemaPalette.muted),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: CinemaPalette.gold),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      await authService.deleteAccount();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              backgroundColor: CinemaPalette.wine,
              content: Text('Account deleted successfully',
                  style: TextStyle(color: CinemaPalette.ivory))),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String errorMessage = 'Error deleting account.';
        if (e.code == 'requires-recent-login') {
          errorMessage =
              'For security reasons, please sign out and sign in again before deleting your account.';
        } else if (e.code == 'network-request-failed') {
          errorMessage =
              'Network error. Please check your connection and try again.';
        } else {
          errorMessage = e.message ?? errorMessage;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              backgroundColor: CinemaPalette.wine,
              content: Text(errorMessage,
                  style: const TextStyle(color: CinemaPalette.ivory))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              backgroundColor: CinemaPalette.wine,
              content: Text('An unexpected error occurred: ${e.toString()}',
                  style: const TextStyle(color: CinemaPalette.ivory))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendEmailVerification() async {
    if (_isBusy) return;
    setState(() => _isSendingVerification = true);

    try {
      final authService = context.read<AuthService>();
      await authService.sendEmailVerification();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: CinemaPalette.wine,
            content: Text(
                'Verification email sent. Check your inbox and spam folder, follow the link, then return here.',
                style: TextStyle(color: CinemaPalette.ivory)),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String errorMessage = 'Failed to send verification email.';
        if (e.code == 'too-many-requests') {
          errorMessage = 'Too many requests. Please try again later.';
        } else if (e.code == 'no-current-user') {
          errorMessage = 'You need to sign in again.';
        } else {
          errorMessage = e.code == 'network-request-failed'
              ? 'Check your connection and try again.'
              : 'Could not send the verification email. Please try again.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              backgroundColor: CinemaPalette.wine,
              content: Text(errorMessage,
                  style: const TextStyle(color: CinemaPalette.ivory))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              backgroundColor: CinemaPalette.wine,
              content: Text(
                  'Could not send the verification email. Please try again.',
                  style: TextStyle(color: CinemaPalette.ivory))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSendingVerification = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final user = authService.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: CinemaPalette.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.account_circle_outlined,
                  size: 100,
                  color: CinemaPalette.gold,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Browsing as guest',
                  style: TextStyle(
                    color: CinemaPalette.ivory,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Enjoy browsing without an account. Sign in whenever you want to post, reply or like discussions in the community.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: CinemaPalette.muted,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CinemaPalette.gold,
                      foregroundColor: CinemaPalette.background,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Sign In / Sign Up',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: CinemaPalette.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: CinemaPalette.appBarGradient,
          ),
        ),
        title: const Text('Profile',
            style: TextStyle(fontWeight: FontWeight.w800)),
        foregroundColor: CinemaPalette.ivory,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _isBusy
                ? null
                : () => _refreshUserData(showSuccessMessage: true),
            tooltip: 'Refresh Profile',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshUserData,
        color: CinemaPalette.gold,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: CinemaPalette.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: CinemaPalette.gold.withValues(alpha: 0.18),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 112,
                      height: 112,
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [CinemaPalette.wine, CinemaPalette.gold],
                        ),
                      ),
                      child: ClipOval(
                        child: user.photoURL?.isNotEmpty == true
                            ? SafeNetworkImage(
                                imageUrl: user.photoURL,
                                width: 106,
                                height: 106,
                                placeholderIconSize: 34,
                              )
                            : Container(
                                color: CinemaPalette.wine,
                                alignment: Alignment.center,
                                child: Text(
                                  user.displayName?.isNotEmpty == true
                                      ? user.displayName![0].toUpperCase()
                                      : user.email?[0].toUpperCase() ?? '?',
                                  style: const TextStyle(
                                    color: CinemaPalette.ivory,
                                    fontSize: 38,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (user.displayName != null &&
                        user.displayName!.isNotEmpty)
                      Text(
                        user.displayName!,
                        style: const TextStyle(
                          color: CinemaPalette.ivory,
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    Text(
                      user.email ?? 'No email',
                      style: const TextStyle(
                        color: CinemaPalette.muted,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Email Verification Status
                    if (!authService.isEmailVerified)
                      EmailVerificationNotice(
                        isBusy: _isBusy,
                        isSending: _isSendingVerification,
                        onSend: _sendEmailVerification,
                        onCheck: () =>
                            _refreshUserData(checkVerification: true),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: CinemaPalette.gold.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: CinemaPalette.gold),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_rounded,
                                color: CinemaPalette.gold, size: 16),
                            SizedBox(width: 7),
                            Text('Email verified',
                                style: TextStyle(
                                    color: CinemaPalette.gold, fontSize: 12)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              const Align(
                alignment: Alignment.centerLeft,
                child: Text('PROFILE',
                    style: TextStyle(
                        color: CinemaPalette.gold,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2)),
              ),
              const SizedBox(height: 10),

              // Account Actions
              _buildActionTile(
                icon: Icons.person,
                title: 'Account Settings',
                onTap: () => _openAccountSettingsDialog(user),
                isEnabled: !_isBusy,
              ),

              _buildActionTile(
                icon: Icons.favorite,
                title: 'My Favorites',
                onTap: () {
                  Navigator.of(context).pushNamed('/favorites');
                },
              ),

              const SizedBox(height: 18),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('ACCOUNT',
                    style: TextStyle(
                        color: CinemaPalette.gold,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2)),
              ),
              const SizedBox(height: 10),

              // Sign Out Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isBusy ? null : _signOut,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CinemaPalette.surface,
                    foregroundColor: CinemaPalette.ivory,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: CinemaPalette.gold),
                        )
                      : const Text('Sign Out'),
                ),
              ),

              const SizedBox(height: 16),

              // Delete Account Button
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _isBusy ? null : _deleteAccount,
                  style: TextButton.styleFrom(
                    foregroundColor: CinemaPalette.gold,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Delete Account'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isEnabled = true,
  }) {
    return Card(
      color: CinemaPalette.surface,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: CinemaPalette.ivory.withValues(alpha: 0.07)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: CinemaPalette.gold.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon,
              color: isEnabled ? CinemaPalette.gold : CinemaPalette.muted),
        ),
        title: Text(
          title,
          style: TextStyle(
              color: isEnabled ? CinemaPalette.ivory : CinemaPalette.muted,
              fontWeight: FontWeight.w700),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios_rounded,
          size: 15,
          color: isEnabled ? CinemaPalette.muted : CinemaPalette.muted,
        ),
        onTap: isEnabled ? onTap : null,
      ),
    );
  }
}

typedef _ProfileChanges = ({String displayName, String photoUrl});

class _AccountSettingsDialog extends StatefulWidget {
  const _AccountSettingsDialog(
      {required this.displayName, required this.photoUrl});

  final String displayName;
  final String photoUrl;

  @override
  State<_AccountSettingsDialog> createState() => _AccountSettingsDialogState();
}

class _AccountSettingsDialogState extends State<_AccountSettingsDialog> {
  late final TextEditingController _displayNameController;
  late final TextEditingController _photoUrlController;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(text: widget.displayName);
    _photoUrlController = TextEditingController(text: widget.photoUrl);
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _photoUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: CinemaPalette.surface,
        title: const Text(
          'Account Settings',
          style: TextStyle(color: CinemaPalette.ivory),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _displayNameController,
              cursorColor: CinemaPalette.gold,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(color: CinemaPalette.ivory),
              decoration: const InputDecoration(
                labelText: 'Display Name',
                labelStyle: TextStyle(color: CinemaPalette.muted),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: CinemaPalette.muted),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: CinemaPalette.gold),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _photoUrlController,
              cursorColor: CinemaPalette.gold,
              keyboardType: TextInputType.url,
              style: const TextStyle(color: CinemaPalette.ivory),
              decoration: const InputDecoration(
                labelText: 'Photo URL (optional)',
                labelStyle: TextStyle(color: CinemaPalette.muted),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: CinemaPalette.muted),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: CinemaPalette.gold),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(foregroundColor: CinemaPalette.muted),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              FocusScope.of(context).unfocus();
              Navigator.of(context).pop<_ProfileChanges>((
                displayName: _displayNameController.text.trim(),
                photoUrl: _photoUrlController.text.trim(),
              ));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: CinemaPalette.gold,
              foregroundColor: CinemaPalette.background,
            ),
            child: const Text('Save'),
          ),
        ],
      );
}
