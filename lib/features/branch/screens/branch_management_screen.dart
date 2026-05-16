import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/logger.dart';
import '../../home/models/branch.dart';
import '../../home/providers/home_provider.dart';
import '../../home/services/branch_service.dart';
import '../services/branch_management_service.dart';

class BranchManagementScreen extends StatefulWidget {
  const BranchManagementScreen({super.key});

  @override
  State<BranchManagementScreen> createState() => _BranchManagementScreenState();
}

class _BranchManagementScreenState extends State<BranchManagementScreen> {
  List<Branch> _branches = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    setState(() => _isLoading = true);
    final branches = await BranchService.getBranches();
    setState(() {
      _branches = branches;
      _isLoading = false;
    });
  }

  void _openBranchForm({Branch? branch}) {
    final nameController = TextEditingController(text: branch?.name ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
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
              branch == null ? 'Yeni Şube' : 'Şube Düzenle',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Şube Adı',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (nameController.text.isEmpty) return;
                  try {
                    if (branch == null) {
                      await BranchManagementService.createBranch(
                        nameController.text.trim(),
                      );
                    } else {
                      await BranchManagementService.updateBranch(
                        int.parse(branch.id),
                        nameController.text.trim(),
                      );
                    }
                    final updatedBranches = await BranchService.getBranches();
                    if (context.mounted) {
                      context.read<HomeProvider>().setBranches(updatedBranches);
                      Navigator.pop(context);
                    }
                    await _loadBranches();
                    logger.i('Branch saved: ${nameController.text}');
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('İşlem başarısız.')),
                      );
                    }
                  }
                },
                child: const Text('Kaydet'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteBranch(Branch branch) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Şube Sil'),
        content: Text('${branch.name} silinecek. Emin misiniz?'),
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
      await BranchManagementService.deleteBranch(int.parse(branch.id));
      setState(() => _branches.removeWhere((b) => b.id == branch.id));
      context.read<HomeProvider>().setBranches(_branches);
      logger.i('Branch deleted: ${branch.name}');
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
        title: const Text('Şube Yönetimi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBranches,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openBranchForm(),
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _branches.isEmpty
              ? const Center(child: Text('Kayıtlı şube bulunamadı.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _branches.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final branch = _branches[index];
                    return ListTile(
                      leading: const Icon(Icons.store),
                      title: Text(branch.name),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _openBranchForm(branch: branch),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteBranch(branch),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}