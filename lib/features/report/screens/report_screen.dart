import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/logger.dart';
import '../../home/models/branch.dart';
import '../../home/providers/home_provider.dart';
import '../models/report.dart';
import '../services/report_service.dart';

// ─── Sayım durum filtresi ─────────────────────────────────────────────────────

enum _StatusFilter { all, active, completed }

extension _StatusFilterLabel on _StatusFilter {
  String get label {
    switch (this) {
      case _StatusFilter.all:       return 'Tümü';
      case _StatusFilter.active:    return 'Aktif';
      case _StatusFilter.completed: return 'Tamamlandı';
    }
  }
}

// ─── Ekran ────────────────────────────────────────────────────────────────────

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  // Yüklenen raporlar (seçili şubelere göre)
  List<BranchReport> _reports = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Şube seçimi — null = aktif şube, dolu liste = seçilmiş şubeler
  late List<Branch> _allBranches;
  final Set<String> _selectedBranchIds = {};

  // Filtreler
  _StatusFilter _statusFilter    = _StatusFilter.all;
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<HomeProvider>();
      _allBranches = List.from(provider.branches);

      // Başlangıçta aktif şube seçili
      if (provider.activeBranchId != null) {
        _selectedBranchIds.add(provider.activeBranchId!);
      } else if (_allBranches.isNotEmpty) {
        _selectedBranchIds.add(_allBranches.first.id);
      }

      _loadReports();
    });
  }

  Future<void> _loadReports() async {
    if (_selectedBranchIds.isEmpty) {
      setState(() {
        _reports      = [];
        _errorMessage = 'Lütfen en az bir şube seçin.';
      });
      return;
    }

    setState(() {
      _isLoading    = true;
      _errorMessage = null;
    });

    try {
      logger.i('Loading reports for branches: $_selectedBranchIds');
      final reports = await ReportService.getMultiBranchReports(
          _selectedBranchIds.toList());
      setState(() => _reports = reports);
    } catch (e) {
      logger.e('Report screen error: $e');
      setState(() => _errorMessage = 'Rapor yüklenirken hata oluştu.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ─── Filtre uygula ─────────────────────────────────────────────────────────

  List<StockCountReport> _applyFilters(List<StockCountReport> counts) {
    return counts.where((sc) {
      // Durum filtresi
      if (_statusFilter == _StatusFilter.active && sc.status != 'active') return false;
      if (_statusFilter == _StatusFilter.completed && sc.status != 'completed') return false;

      // Tarih aralığı filtresi
      if (_dateRange != null) {
        final start = _dateRange!.start;
        final end   = _dateRange!.end.add(const Duration(days: 1));
        if (sc.createdAt.isBefore(start) || sc.createdAt.isAfter(end)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  // ─── Tarih aralığı seçici ──────────────────────────────────────────────────

  Future<void> _pickDateRange() async {
    final now   = DateTime.now();
    final range = await showDateRangePicker(
      context:        context,
      firstDate:      DateTime(2020),
      lastDate:       now,
      initialDateRange: _dateRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 30)),
            end:   now,
          ),
      locale: const Locale('tr', 'TR'),
      helpText:       'Tarih Aralığı Seçin',
      cancelText:     'İptal',
      confirmText:    'Uygula',
      saveText:       'Uygula',
    );
    if (range != null) setState(() => _dateRange = range);
  }

  // ─── Şube seçici dialog ───────────────────────────────────────────────────

  Future<void> _showBranchSelector() async {
    final tempSelected = Set<String>.from(_selectedBranchIds);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Şube Seçimi'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: _allBranches.map((branch) {
                final selected = tempSelected.contains(branch.id);
                return CheckboxListTile(
                  title:   Text(branch.name),
                  value:   selected,
                  onChanged: (v) {
                    setDlgState(() {
                      if (v == true) {
                        tempSelected.add(branch.id);
                      } else {
                        tempSelected.remove(branch.id);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: tempSelected.isEmpty
                  ? null
                  : () {
                      Navigator.pop(ctx);
                      setState(() {
                        _selectedBranchIds
                          ..clear()
                          ..addAll(tempSelected);
                      });
                      _loadReports();
                    },
              child: const Text('Uygula'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Raporlama'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Yenile',
            onPressed: _loadReports,
          ),
        ],
      ),
      body: Column(
        children: [
          _FilterBar(
            allBranches:       _allBranches,
            selectedBranchIds: _selectedBranchIds,
            statusFilter:      _statusFilter,
            dateRange:         _dateRange,
            onBranchTap:       _showBranchSelector,
            onStatusChanged:   (v) => setState(() => _statusFilter = v),
            onDateRangeTap:    _pickDateRange,
            onClearDate:       () => setState(() => _dateRange = null),
          ),
          const Divider(height: 1),
          Expanded(child: _buildBody()),
        ],
      ),
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
            ElevatedButton(onPressed: _loadReports, child: const Text('Tekrar Dene')),
          ],
        ),
      );
    }

    // Filtrelenmiş veriler
    final filteredReports = _reports.map((br) {
      final filtered = _applyFilters(br.stockCounts);
      return _FilteredReport(branchReport: br, counts: filtered);
    }).where((fr) => fr.counts.isNotEmpty).toList();

    if (filteredReports.isEmpty) {
      return const Center(
        child: Text(
          'Seçili filtrelerle eşleşen sayım bulunamadı.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: filteredReports.length,
      itemBuilder: (context, branchIdx) {
        final fr = filteredReports[branchIdx];
        final showBranchHeader = filteredReports.length > 1;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showBranchHeader) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.store, size: 16, color: Colors.blue),
                    const SizedBox(width: 6),
                    Text(
                      fr.branchReport.branchName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            ...fr.counts.map((sc) => _StockCountCard(stockCount: sc)),
          ],
        );
      },
    );
  }
}

// ─── Filtre Bar ───────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final List<Branch>  allBranches;
  final Set<String>   selectedBranchIds;
  final _StatusFilter statusFilter;
  final DateTimeRange? dateRange;
  final VoidCallback  onBranchTap;
  final ValueChanged<_StatusFilter> onStatusChanged;
  final VoidCallback  onDateRangeTap;
  final VoidCallback  onClearDate;

  const _FilterBar({
    required this.allBranches,
    required this.selectedBranchIds,
    required this.statusFilter,
    required this.dateRange,
    required this.onBranchTap,
    required this.onStatusChanged,
    required this.onDateRangeTap,
    required this.onClearDate,
  });

  String get _branchLabel {
    if (selectedBranchIds.isEmpty) return 'Şube Seç';
    if (selectedBranchIds.length == 1) {
      final branch = allBranches.where((b) => b.id == selectedBranchIds.first);
      return branch.isNotEmpty ? branch.first.name : 'Şube Seç';
    }
    return '${selectedBranchIds.length} Şube';
  }

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Şube seçici
            ActionChip(
              avatar: const Icon(Icons.store, size: 16),
              label: Text(_branchLabel, style: const TextStyle(fontSize: 12)),
              onPressed: onBranchTap,
              backgroundColor: selectedBranchIds.length > 1
                  ? Colors.blue.shade100
                  : null,
            ),
            const SizedBox(width: 8),

            // Durum filtresi
            ..._StatusFilter.values.map((f) => Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                label: Text(f.label, style: const TextStyle(fontSize: 12)),
                selected: statusFilter == f,
                onSelected: (_) => onStatusChanged(f),
                selectedColor: Colors.blue.shade100,
              ),
            )),

            // Tarih aralığı
            ActionChip(
              avatar: Icon(
                Icons.date_range,
                size: 16,
                color: dateRange != null ? Colors.blue : null,
              ),
              label: Text(
                dateRange != null
                    ? '${_formatDate(dateRange!.start)} – ${_formatDate(dateRange!.end)}'
                    : 'Tarih',
                style: TextStyle(
                  fontSize: 12,
                  color: dateRange != null ? Colors.blue : null,
                ),
              ),
              backgroundColor: dateRange != null ? Colors.blue.shade50 : null,
              onPressed: onDateRangeTap,
            ),
            if (dateRange != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onClearDate,
                child: const CircleAvatar(
                  radius: 10,
                  backgroundColor: Colors.grey,
                  child: Icon(Icons.close, size: 12, color: Colors.white),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Sayım Kartı ──────────────────────────────────────────────────────────────

class _StockCountCard extends StatelessWidget {
  final StockCountReport stockCount;

  const _StockCountCard({required this.stockCount});

  @override
  Widget build(BuildContext context) {
    final isCompleted = stockCount.status == 'completed';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(
          stockCount.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Row(
          children: [
            _StatusBadge(isCompleted: isCompleted),
            const SizedBox(width: 8),
            Text(
              _formatDate(stockCount.createdAt),
              style: const TextStyle(fontSize: 12),
            ),
            if (stockCount.completedAt != null) ...[
              const Text(' → ', style: TextStyle(fontSize: 12)),
              Text(
                _formatDate(stockCount.completedAt!),
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ],
        ),
        children: [
          // Kategori breakdown
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: stockCount.categories.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final cat = stockCount.categories[i];
              return ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                title: Text(cat.category, style: const TextStyle(fontSize: 14)),
                subtitle: _AlisatisSummary(
                    alis: cat.totalAlis, satis: cat.totalSatis),
                children: cat.subCategories.map((sub) => ListTile(
                  contentPadding:
                      const EdgeInsets.only(left: 32, right: 16),
                  dense: true,
                  title: Text(sub.subCategory,
                      style: const TextStyle(fontSize: 13)),
                  subtitle: _AlisatisSummary(
                      alis: sub.totalAlis, satis: sub.totalSatis),
                )).toList(),
              );
            },
          ),

          // Genel Toplam
          const Divider(thickness: 1.5),
          _GrandTotalTile(
            grandTotalAlis:  stockCount.grandTotalAlis,
            grandTotalSatis: stockCount.grandTotalSatis,
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
}

// ─── Küçük widget'lar ─────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final bool isCompleted;
  const _StatusBadge({required this.isCompleted});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isCompleted ? Colors.green : Colors.orange,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isCompleted ? 'Tamamlandı' : 'Aktif',
        style: const TextStyle(color: Colors.white, fontSize: 11),
      ),
    );
  }
}

class _AlisatisSummary extends StatelessWidget {
  final double alis;
  final double satis;
  const _AlisatisSummary({required this.alis, required this.satis});

  @override
  Widget build(BuildContext context) {
    return Text(
      'Alış: ${alis.toStringAsFixed(2)} ₺  |  Satış: ${satis.toStringAsFixed(2)} ₺',
      style: const TextStyle(fontSize: 11, color: Colors.grey),
    );
  }
}

class _GrandTotalTile extends StatelessWidget {
  final double grandTotalAlis;
  final double grandTotalSatis;
  const _GrandTotalTile({
    required this.grandTotalAlis,
    required this.grandTotalSatis,
  });

  @override
  Widget build(BuildContext context) {
    final kar = grandTotalSatis - grandTotalAlis;
    return ListTile(
      title: const Text('Genel Toplam',
          style: TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Alış: ${grandTotalAlis.toStringAsFixed(2)} ₺'),
          Text('Satış: ${grandTotalSatis.toStringAsFixed(2)} ₺'),
          Text(
            'Kâr: ${kar.toStringAsFixed(2)} ₺',
            style: TextStyle(
              color: kar >= 0 ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Yardımcı model (sadece bu dosyada) ──────────────────────────────────────

class _FilteredReport {
  final BranchReport         branchReport;
  final List<StockCountReport> counts;
  _FilteredReport({required this.branchReport, required this.counts});
}
