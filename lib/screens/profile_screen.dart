import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_provider.dart';
import '../config.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) return const SizedBox.shrink();

    final roleColor = _roleColor(user.role);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: CustomScrollView(
        slivers: [
          // ── Gradient header ────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [Color(0xFF1D4ED8), Color(0xFF2563EB), Color(0xFF0EA5E9)],
                ),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  child: Column(
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Profile', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                      const SizedBox(height: 24),
                      // Avatar
                      Stack(
                        children: [
                          Container(
                            width: 88, height: 88,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 12)],
                            ),
                            child: ClipOval(
                              child: user.avatarUrl != null
                                  ? Image.network(
                                      user.avatarUrl!.startsWith('http') ? user.avatarUrl! : '$kBaseUrl${user.avatarUrl}',
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => _avatarFallback(user.displayName),
                                    )
                                  : _avatarFallback(user.displayName),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(user.displayName,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 4),
                      Text(user.email, style: const TextStyle(fontSize: 13, color: Colors.white70)),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: roleColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: roleColor.withOpacity(0.5)),
                        ),
                        child: Text(user.role,
                            style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Account info ───────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                _section('Account', [
                  _tile(Icons.email_outlined, 'Email', user.email),
                  _tile(Icons.badge_outlined, 'Role', user.role),
                  _tile(Icons.verified_user_outlined, 'Status',
                      user.accountStatus ?? 'Active',
                      valueColor: user.accountStatus == 'SUSPENDED'
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF16A34A)),
                ]),
                const SizedBox(height: 14),
                _section('Navigation', [
                  _navTile(context, Icons.edit_outlined, 'Edit Profile', () => context.push('/profile/edit')),
                  _navTile(context, Icons.notifications_outlined, 'Notifications', () => context.push('/notifications')),
                  _navTile(context, Icons.home_outlined, 'Browse Properties', () => context.go('/')),
                  _navTile(context, Icons.search_outlined, 'Search', () => context.go('/search')),
                  _navTile(context, Icons.calendar_today_outlined, 'My Bookings', () => context.go('/bookings')),
                ]),
                const SizedBox(height: 14),
                _section('About', [
                  _tile(Icons.info_outline, 'Version', '1.0.0'),
                  _tile(Icons.location_on_outlined, 'Platform', 'At Locals — Somalia Hotels'),
                ]),
                const SizedBox(height: 14),
                // Sign out
                GestureDetector(
                  onTap: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        title: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold)),
                        content: const Text('Are you sure you want to sign out?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
                            child: const Text('Sign Out'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true && context.mounted) {
                      await context.read<AuthProvider>().logout();
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
                    ),
                    child: const Row(children: [
                      Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 22),
                      SizedBox(width: 14),
                      Text('Sign Out', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold, fontSize: 15)),
                      Spacer(),
                      Icon(Icons.chevron_right, color: Color(0xFFDC2626)),
                    ]),
                  ),
                ),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> tiles) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(title.toUpperCase(),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), letterSpacing: 1)),
      ),
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
        ),
        child: Column(children: [
          for (int i = 0; i < tiles.length; i++) ...[
            tiles[i],
            if (i < tiles.length - 1) const Divider(height: 1, indent: 52),
          ],
        ]),
      ),
    ],
  );

  Widget _tile(IconData icon, String label, String value, {Color? valueColor}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Row(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 18, color: const Color(0xFF2563EB)),
      ),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: valueColor ?? const Color(0xFF0F172A))),
      ])),
    ]),
  );

  Widget _navTile(BuildContext ctx, IconData icon, String label, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 18, color: const Color(0xFF2563EB)),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
            const Icon(Icons.chevron_right, color: Color(0xFF94A3B8), size: 20),
          ]),
        ),
      );

  Color _roleColor(String role) {
    switch (role) {
      case 'SUPER_ADMIN': return const Color(0xFF7C3AED);
      case 'ADMIN':       return const Color(0xFF7C3AED);
      case 'STAFF':       return const Color(0xFF0891B2);
      case 'HOST':        return const Color(0xFF2563EB);
      case 'BROKER':      return const Color(0xFF4F46E5);
      default:            return const Color(0xFF16A34A);
    }
  }
}

Widget _avatarFallback(String name) => Container(
  color: const Color(0xFF1D4ED8),
  child: Center(
    child: Text(
      name.isNotEmpty ? name[0].toUpperCase() : 'G',
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 32),
    ),
  ),
);
