import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/logger.dart';

/// Seç Market senkronizasyon ekranı.
/// secmarket.db dosyasını seçip API'ye yükler.
class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  bool _isLoading = false;
  String? _resultMessage;
  bool _isError = false;

  Future<void> _pickAndSync() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;

    if (file.path == null) {
      setState(() {
        _resultMessage = 'Dosya yolu okunamadı.';
        _isError = true;
      });
      return;
    }

    if (!file.name.endsWith('.db')) {
      setState(() {
        _resultMessage = 'Lütfen .db uzantılı SQLite dosyası seçin.';
        _isError = true;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _resultMessage = null;
      _isError = false;
    });

    try {
      logger.i('Syncing secmarket.db: ${file.name} (${file.size} bytes)');

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path!, filename: file.name),
      });

      final response = await ApiService.dio.post(
        '/api/sync/secmarket',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          sendTimeout: const Duration(minutes: 5),
          receiveTimeout: const Duration(minutes: 5),
        ),
      );

      final data = response.data as Map<String, dynamic>;
      setState(() {
        _resultMessage = '✓ Sync tamamlandı!\n'
            'Yeni ürün: ${data['productsAdded']}\n'
            'Yeni barkod: ${data['barcodesAdded']}\n'
            'Atlanan barkod: ${data['barcodesSkipped']}';
        _isError = false;
      });

      logger.i('Sync result: $data');
    } catch (e) {
      setState(() {
        _resultMessage = 'Sync başarısız: $e';
        _isError = true;
      });
      logger.e('Sync failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.dio.get('/api/sync/history');
      final list = response.data as List;
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Sync Geçmişi'),
          content: SizedBox(
            width: double.maxFinite,
            child: list.isEmpty
                ? const Text('Henüz sync yapılmamış.')
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final h = list[i] as Map<String, dynamic>;
                      return ListTile(
                        dense: true,
                        title: Text(h['sourceFile'] ?? '-',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          '${h['syncedAt']?.toString().substring(0, 16)}\n'
                          '+${h['productsAdded']} ürün  '
                          '+${h['barcodesAdded']} barkod  '
                          '~${h['barcodesSkipped']} atlandı',
                        ),
                        isThreeLine: true,
                        trailing: Icon(
                          h['status'] == 'success'
                              ? Icons.check_circle
                              : Icons.error,
                          color: h['status'] == 'success'
                              ? Colors.green
                              : Colors.red,
                          size: 20,
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Kapat'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Geçmiş yüklenemedi: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seç Market Sync'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Sync Geçmişi',
            onPressed: _isLoading ? null : _loadHistory,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Senkronizasyon devam ediyor...'),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.sync, size: 64, color: Colors.blueGrey),
                  const SizedBox(height: 16),
                  const Text(
                    'Seç Market Senkronizasyonu',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'secmarket.db dosyasını seçerek yeni ürün ve barkodları sisteme aktarın.\n'
                    'İşlem tekrarlanabilir — zaten var olanlar atlanır.',
                    style:
                        TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  ElevatedButton.icon(
                    onPressed: _pickAndSync,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Dosya Seç ve Senkronize Et'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      textStyle: const TextStyle(fontSize: 15),
                    ),
                  ),

                  if (_resultMessage != null) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _isError
                            ? Colors.red.shade50
                            : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _isError
                              ? Colors.red.shade200
                              : Colors.green.shade200,
                        ),
                      ),
                      child: Text(
                        _resultMessage!,
                        style: TextStyle(
                          color: _isError
                              ? Colors.red.shade800
                              : Colors.green.shade800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
