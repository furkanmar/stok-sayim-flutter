import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/logger.dart';
import '../../home/models/branch.dart';
import '../../home/providers/home_provider.dart';
import '../models/app_user.dart';
import '../services/user_service.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  List<AppUser> _users = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final provider = context.read<HomeProvider>();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final users = await UserService.getUsers(provider.username);
      setState(() => _users = users);
    } catch (e) {
      logger.e('User management screen error: $e');
      setState(() => _errorMessage = 'Kullanıcılar yüklenirken hata oluştu.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _openUserForm({AppUser? user}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => ChangeNotifierProvider.value(
        value: context.read<HomeProvider>(),
        child: _UserForm(
          user: user,
          onSaved: _loadUsers,
        ),
      ),
    );
  }

  Future<void> _deleteUser(AppUser user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Kullanıcı Sil'),
        content: Text('${user.username} silinecek. Emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await UserService.deleteUser(user.id!);
      _loadUsers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Silme işlemi başarısız.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kullanıcı Yönetimi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUsers,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openUserForm(),
        child: const Icon(Icons.add),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadUsers,
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      );
    }

    if (_users.isEmpty) {
      return const Center(child: Text('Kayıtlı kullanıcı bulunamadı.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _users.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, index) {
        final user = _users[index];
        return ListTile(
          leading: const Icon(Icons.person),
          title: Text(user.username),
          subtitle: Text(user.role),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.blue),
                onPressed: () => _openUserForm(user: user),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _deleteUser(user),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _UserForm extends StatefulWidget {
  final AppUser? user;
  final VoidCallback onSaved;

  const _UserForm({this.user, required this.onSaved});

  @override
  State<_UserForm> createState() => _UserFormState();
}

class _UserFormState extends State<_UserForm> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedRole = 'counter';
  List<String> _selectedBranchIds = [];
  bool _isLoading = false;

  List<String> get _roles {
    final role = context.read<HomeProvider>().role;
    if (role == 'superadmin') return ['counter', 'admin', 'superadmin'];
    return ['counter'];
  }

  @override
  void initState() {
    super.initState();
    if (widget.user != null) {
      _usernameController.text = widget.user!.username;
      _selectedRole = widget.user!.role;
      _selectedBranchIds = List.from(widget.user!.branchIds);
    }
    logger.i('UserForm opened — editing: ${widget.user?.username ?? 'new'}');
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_usernameController.text.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final provider = context.read<HomeProvider>();
      final user = AppUser(
        id: widget.user?.id,
        username: _usernameController.text.trim(),
        password: _passwordController.text.trim(),
        role: _selectedRole,
        companyId: provider.companyId,
        branchIds: _selectedBranchIds,
      );

      await UserService.saveUser(user);
      widget.onSaved();

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kayıt sırasında hata oluştu.')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final branches = context.watch<HomeProvider>().branches;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.user == null ? 'Yeni Kullanıcı' : 'Kullanıcı Düzenle',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _usernameController,
            decoration: const InputDecoration(
              labelText: 'Kullanıcı Adı',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: widget.user == null ? 'Şifre' : 'Yeni Şifre (boş bırakılabilir)',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedRole,
            decoration: const InputDecoration(
              labelText: 'Rol',
              border: OutlineInputBorder(),
            ),
            items: _roles.map((role) => DropdownMenuItem(
              value: role,
              child: Text(role),
            )).toList(),
            onChanged: (value) {
              setState(() => _selectedRole = value!);
              logger.d('Role selected: $value');
            },
          ),
          const SizedBox(height: 16),
          const Text(
            'Şubeler',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ...branches.map((branch) => CheckboxListTile(
            title: Text(branch.name),
            value: _selectedBranchIds.contains(branch.id),
            onChanged: (checked) {
              setState(() {
                if (checked == true) {
                  _selectedBranchIds.add(branch.id);
                } else {
                  _selectedBranchIds.remove(branch.id);
                }
              });
            },
          )),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _save,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Kaydet'),
            ),
          ),
        ],
      ),
    );
  }
}