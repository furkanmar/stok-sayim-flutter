import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/home_provider.dart';
import '../../../core/utils/logger.dart';
import '../../settings/screens/settings_screen.dart';
import '../widgets/branch_selector_popup.dart';
import '../../product/screens/product_screen.dart';
import '../../stock/screens/stock_screen.dart';
import '../../report/screens/report_screen.dart';
import '../../user_management/screens/user_management_screen.dart';
import '../../auth/screens/login_screen.dart';
import '../../auth/services/auth_service.dart';
import '../../home/services/branch_service.dart';
import '../../../core/utils/logger.dart';
import '../../branch/screens/branch_management_screen.dart';
import '../../product/screens/import_screen.dart';
import '../../product/screens/product_list_screen.dart';

class HomeScreen extends StatefulWidget {
  final String initialRole;
  final String initialUsername;
  final String initialCompanyId;

  const HomeScreen({
    super.key,
    this.initialRole = '',
    this.initialUsername = '',
    this.initialCompanyId = '',
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<HomeProvider>();

      if (widget.initialRole.isNotEmpty) {
        provider.init(
          widget.initialRole,
          widget.initialUsername,
          widget.initialCompanyId,
        );
      }

      final branches = await BranchService.getBranches();
      provider.setBranches(branches);
      logger.i('Branches loaded on home screen init: ${branches.length}');
    });
  }


  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HomeProvider>();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Üst bar — şube seçici
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: Colors.blue,
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        logger.i('Branch selector tapped');
                        BranchSelectorPopup.show(context);
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            provider.activeBranchName ?? 'Şube Seçilmedi',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_drop_down, color: Colors.white),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.white),
                    onPressed: () async {
                      logger.i('Logout tapped');
                      await AuthService.logout();
                      if (context.mounted) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
            // Butonlar alanı
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  children: [
                    _buildMenuButton(
                      context,
                      icon: Icons.qr_code_scanner,
                      label: 'Ürün Ekle / Değiştir',
                      onTap: () {
                        logger.i('Ürün Ekle tapped');
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ProductScreen()),
                        );
                      },
                    ),
                    _buildMenuButton(
                      context,
                      icon: Icons.list_alt,
                      label: 'Ürün Listesi',
                      onTap: () {
                        logger.i('Ürün Listesi tapped');
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ProductListScreen()),
                        );
                      },
                    ),
                    _buildMenuButton(
                      context,
                      icon: Icons.inventory,
                      label: 'Stok Gir',
                      onTap: () {
                        logger.i('Stok Gir tapped');
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const StockScreen()),
                        );
                      },
                    ),
                    _buildMenuButton(
                      context,
                      icon: Icons.settings,
                      label: 'Ayarlar',
                      onTap: () {
                          logger.i('Ayarlar tapped');
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SettingsScreen()),
                          );
                        },
                    ),
                    if (provider.role == 'admin' || provider.role == 'superadmin')
                      _buildMenuButton(
                        context,
                        icon: Icons.bar_chart,
                        label: 'Raporlama',
                        onTap: () {
                          logger.i('Raporlama tapped');
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ReportScreen()),
                          );
                        },
                      )
                    else
                      _buildMenuButton(
                        context,
                        icon: Icons.more_horiz,
                        label: '',
                        onTap: () {},
                      ),
                    if (provider.role == 'superadmin') ...[
                      _buildMenuButton(
                        context,
                        icon: Icons.people,
                        label: 'Kullanıcı Yönetimi',
                        onTap: () {
                          logger.i('Kullanıcı Yönetimi tapped');
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const UserManagementScreen()),
                          );
                        },
                      ),
                      _buildMenuButton(
                        context,
                        icon: Icons.store,
                        label: 'Şube Yönetimi',
                        onTap: () {
                          logger.i('Şube Yönetimi tapped');
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const BranchManagementScreen()),
                          );
                        },
                      ),
                      _buildMenuButton(
                        context,
                        icon: Icons.upload_file,
                        label: 'Ürün İçe Aktar',
                        onTap: () {
                          logger.i('Import tapped');
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ImportScreen()),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: Colors.blue),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}