import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
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
          SnackBar(content: Text(message)),
        );
      }
    } catch (_) {
      if (mounted && showErrors) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Could not refresh your account. Check your connection and try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRefreshingProfile = false);
    }
  }

  Future<void> _openAccountSettingsDialog(User user) async {
    final displayNameController =
        TextEditingController(text: user.displayName ?? '');
    final photoUrlController = TextEditingController(text: user.photoURL ?? '');

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Account Settings',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: displayNameController,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Display Name',
                labelStyle: TextStyle(color: Colors.grey[300]),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey[700]!),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFE50914)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: photoUrlController,
              keyboardType: TextInputType.url,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Photo URL (optional)',
                labelStyle: TextStyle(color: Colors.grey[300]),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey[700]!),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFE50914)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE50914),
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    final displayNameInput = displayNameController.text.trim();
    final photoUrlInput = photoUrlController.text.trim();
    displayNameController.dispose();
    photoUrlController.dispose();

    if (shouldSave != true || !mounted) return;

    final currentDisplayName = (user.displayName ?? '').trim();
    final currentPhotoUrl = (user.photoURL ?? '').trim();

    final displayNameUpdate =
        displayNameInput == currentDisplayName ? null : displayNameInput;
    final photoUrlUpdate =
        photoUrlInput == currentPhotoUrl ? null : photoUrlInput;

    if (displayNameUpdate == null && photoUrlUpdate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No changes to save')),
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
            content: Text('Photo URL must start with http:// or https://'),
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
          const SnackBar(content: Text('Profile updated successfully')),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'Failed to update profile.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update profile.')),
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
          const SnackBar(content: Text('Signed out successfully')),
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
          SnackBar(content: Text(errorMessage)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('An unexpected error occurred: ${e.toString()}')),
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
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Delete Account',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone.',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
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
          const SnackBar(content: Text('Account deleted successfully')),
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
          SnackBar(content: Text(errorMessage)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('An unexpected error occurred: ${e.toString()}')),
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
            content: Text(
              'Verification email sent. Check your inbox and spam folder, follow the link, then return here.',
            ),
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
          SnackBar(content: Text(errorMessage)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Could not send the verification email. Please try again.')),
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
        backgroundColor: const Color(0xFF0A0A0A),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.account_circle_outlined,
                  size: 100,
                  color: Color(0xFFE50914),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Browsing as guest',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Enjoy browsing without an account. Sign in whenever you want to post, reply or like discussions in the community.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[400],
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
                      backgroundColor: const Color(0xFFE50914),
                      foregroundColor: Colors.white,
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
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        title: const Text('Profile',
            style: TextStyle(fontWeight: FontWeight.w800)),
        foregroundColor: Colors.white,
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
        color: const Color(0xFFE50914),
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
                  color: const Color(0xFF171724),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.18),
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
                          colors: [Color(0xFF00E5FF), Color(0xFFFFD700)],
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
                                color: const Color(0xFF252536),
                                alignment: Alignment.center,
                                child: Text(
                                  user.displayName?.isNotEmpty == true
                                      ? user.displayName![0].toUpperCase()
                                      : user.email?[0].toUpperCase() ?? '?',
                                  style: const TextStyle(
                                    color: Colors.white,
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
                          color: Colors.white,
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    Text(
                      user.email ?? 'No email',
                      style: const TextStyle(
                        color: Colors.white60,
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
                          color:
                              const Color(0xFF00E676).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF00E676)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_rounded,
                                color: Color(0xFF00E676), size: 16),
                            SizedBox(width: 7),
                            Text('Email verified',
                                style: TextStyle(
                                    color: Color(0xFF00E676), fontSize: 12)),
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
                        color: Color(0xFFFFD700),
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
                        color: Color(0xFFFFD700),
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
                    backgroundColor: const Color(0xFF1A1A27),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
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
                    foregroundColor: Colors.red,
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
      color: const Color(0xFF171724),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon,
              color: isEnabled ? const Color(0xFF00E5FF) : Colors.grey),
        ),
        title: Text(
          title,
          style: TextStyle(
              color: isEnabled ? Colors.white : Colors.grey,
              fontWeight: FontWeight.w700),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios_rounded,
          size: 15,
          color: isEnabled ? Colors.grey : Colors.grey[700],
        ),
        onTap: isEnabled ? onTap : null,
      ),
    );
  }
}
