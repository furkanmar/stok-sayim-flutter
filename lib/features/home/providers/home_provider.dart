import 'package:flutter/material.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/utils/logger.dart';
import '../models/branch.dart';

class HomeProvider extends ChangeNotifier {
  String? _activeBranchId;
  String? _activeBranchName;
  String _role = '';
  String _username = '';
  String _companyId = '';
  List<Branch> _branches = [];

  String? get activeBranchId => _activeBranchId;
  String? get activeBranchName => _activeBranchName;
  String get role => _role;
  String get username => _username;
  String get companyId => _companyId;
  List<Branch> get branches => _branches;

  void init(String role, String username, String companyId) {
    _role = role;
    _username = username;
    _companyId = companyId;
    final savedBranchId = StorageService.getActiveBranch();
    if (savedBranchId != null && _branches.isNotEmpty) {
      final branch = _branches.firstWhere(
        (b) => b.id == savedBranchId,
        orElse: () => _branches.first,
      );
      _activeBranchId = branch.id;
      _activeBranchName = branch.name;
    }
    logger.i('HomeProvider initialized — role: $role, username: $username, companyId: $companyId');
    notifyListeners();
  }

  void setBranches(List<Branch> branches) {
    _branches = branches;
    final savedBranchId = StorageService.getActiveBranch();
    if (savedBranchId != null && _activeBranchId == null) {
      final matching = branches.where((b) => b.id == savedBranchId);
      if (matching.isNotEmpty) {
        _activeBranchId = matching.first.id;
        _activeBranchName = matching.first.name;
      }
    }
    logger.i('Branches loaded: ${branches.length}');
    notifyListeners();
  }

  Future<void> setActiveBranch(Branch branch) async {
    _activeBranchId = branch.id;
    _activeBranchName = branch.name;
    await StorageService.setActiveBranch(branch.id);
    logger.i('Active branch changed: ${branch.name}');
    notifyListeners();
  }
}