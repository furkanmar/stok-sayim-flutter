import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/home_provider.dart';
import '../../../core/utils/logger.dart';

class BranchSelectorPopup extends StatelessWidget {
  const BranchSelectorPopup({super.key});

  static void show(BuildContext context) {
    logger.i('Branch selector popup opened');
    final provider = context.read<HomeProvider>();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => ChangeNotifierProvider.value(
        value: provider,
        child: const BranchSelectorPopup(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HomeProvider>();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Şube Seç',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (provider.branches.isEmpty)
            const Center(child: Text('Kayıtlı şube bulunamadı.'))
          else
            ListView.separated(
              shrinkWrap: true,
              itemCount: provider.branches.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final branch = provider.branches[index];
                final isActive = branch.id == provider.activeBranchId;
                return ListTile(
                  title: Text(branch.name),
                  trailing: isActive
                      ? const Icon(Icons.check, color: Colors.blue)
                      : null,
                  onTap: () async {
                    await provider.setActiveBranch(branch);
                    if (context.mounted) Navigator.pop(context);
                  },
                );
              },
            ),
        ],
      ),
    );
  }
}