import '../../../core/services/api_service.dart';
import '../../../core/utils/logger.dart';
import '../models/product.dart';

class ProductService {
  // ─── Barkod ile ürün getir ────────────────────────────────────────────────

  static Future<Product?> getByBarcode(String barcode) async {
    try {
      logger.i('Fetching product by barcode: $barcode');
      final response = await ApiService.dio.get('/api/products/$barcode');
      final product = Product.fromJson(response.data);
      logger.i('Product found: ${product.productName} (${product.barcodeGroups.length} groups)');
      return product;
    } catch (e) {
      logger.w('Product not found for barcode: $barcode');
      return null;
    }
  }

  // ─── ProductId ile ürün getir ─────────────────────────────────────────────

  static Future<Product?> getByProductId(int productId) async {
    try {
      final response = await ApiService.dio.get('/api/products/id/$productId');
      return Product.fromJson(response.data);
    } catch (e) {
      logger.w('Product not found for productId: $productId');
      return null;
    }
  }

  // ─── Ad ile ürün arama ────────────────────────────────────────────────────

  static Future<List<SearchProduct>> searchProducts(String query,
      {String? marka}) async {
    try {
      final params = <String, dynamic>{'q': query};
      if (marka != null && marka.isNotEmpty) params['marka'] = marka;
      final response = await ApiService.dio.get(
        '/api/products/search',
        queryParameters: params,
      );
      return (response.data as List)
          .map((e) => SearchProduct.fromJson(e))
          .toList();
    } catch (e) {
      logger.e('Failed to search products: $e');
      return [];
    }
  }

  // ─── Marka listesi ────────────────────────────────────────────────────────

  static Future<List<String>> getMarkas() async {
    try {
      final response = await ApiService.dio.get('/api/products/markas');
      return List<String>.from(response.data);
    } catch (e) {
      logger.e('Failed to fetch markas: $e');
      return [];
    }
  }

  // ─── Manuel ürün oluştur ──────────────────────────────────────────────────

  static Future<int?> createProduct({
    required String productName,
    required String unit,
    String? content,
    int kdvOrani = 20,
    String? kategori,
    String? altKategori,
    String? marka,
  }) async {
    try {
      final response = await ApiService.dio.post('/api/products', data: {
        'productName': productName,
        'unit': unit,
        'content': content,
        'kdvOrani': kdvOrani,
        'kategori': kategori,
        'altKategori': altKategori,
        'marka': marka,
      });
      return response.data['productId'] as int?;
    } catch (e) {
      logger.e('Failed to create product: $e');
      return null;
    }
  }

  // ─── Ürüne barkod ekle ────────────────────────────────────────────────────

  static Future<bool> addBarcode(
    int productId,
    String barcode,
    String unitType, {
    double? unitQuantity,
  }) async {
    try {
      await ApiService.dio.post(
        '/api/products/$productId/barcodes',
        data: {
          'barcode': barcode,
          'unitType': unitType,
          'unitQuantity': unitQuantity,
        },
      );
      logger.i('Barcode $barcode ($unitType) added to productId $productId');
      return true;
    } catch (e) {
      logger.e('Failed to add barcode: $e');
      return false;
    }
  }

  // ─── Ürün bilgisini güncelle ──────────────────────────────────────────────

  static Future<bool> updateProduct({
    required int productId,
    required String productName,
    required String unit,
    String? content,
    int kdvOrani = 20,
    String? kategori,
    String? altKategori,
    String? marka,
  }) async {
    try {
      await ApiService.dio.put('/api/products/$productId', data: {
        'productName': productName,
        'unit': unit,
        'content': content,
        'kdvOrani': kdvOrani,
        'kategori': kategori,
        'altKategori': altKategori,
        'marka': marka,
      });
      logger.i('Product updated: $productId');
      return true;
    } catch (e) {
      logger.e('Failed to update product: $e');
      return false;
    }
  }

  // ─── Ürün listesi (sayfalı, filtrelenebilir) ──────────────────────────────

  static Future<Map<String, dynamic>?> getProductList({
    String? q,
    String? marka,
    String? kategori,
    bool? hasFiyat,
    int page = 1,
    int pageSize = 30,
  }) async {
    try {
      final params = <String, dynamic>{'page': page, 'pageSize': pageSize};
      if (q != null && q.isNotEmpty) params['q'] = q;
      if (marka != null && marka.isNotEmpty) params['marka'] = marka;
      if (kategori != null && kategori.isNotEmpty) params['kategori'] = kategori;
      if (hasFiyat != null) params['hasPrice'] = hasFiyat;
      final response = await ApiService.dio.get(
        '/api/products/list',
        queryParameters: params,
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      logger.e('Failed to get product list: $e');
      return null;
    }
  }

  // ─── Kategori listesi ─────────────────────────────────────────────────────

  static Future<List<String>> getKategoriler() async {
    try {
      final response = await ApiService.dio.get('/api/products/kategoriler');
      return List<String>.from(response.data);
    } catch (e) {
      logger.e('Failed to fetch kategoriler: $e');
      return [];
    }
  }

  // ─── Barkod sil ───────────────────────────────────────────────────────────

  static Future<bool> deleteBarcode(int productId, String barcode) async {
    try {
      final encoded = Uri.encodeComponent(barcode);
      await ApiService.dio.delete('/api/products/$productId/barcodes/$encoded');
      logger.i('Barcode deleted: $barcode from productId $productId');
      return true;
    } catch (e) {
      logger.e('Failed to delete barcode $barcode: $e');
      return false;
    }
  }

  // ─── Fiyat geçmişi ────────────────────────────────────────────────────────

  static Future<List<ProductPriceEntry>> getPriceHistory(int productId) async {
    try {
      final response =
          await ApiService.dio.get('/api/products/$productId/prices');
      return (response.data as List)
          .map((e) => ProductPriceEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      logger.e('Failed to fetch price history for $productId: $e');
      return [];
    }
  }

  // ─── Toplu fiyat kaydet ───────────────────────────────────────────────────

  static Future<bool> savePrices(
    int productId,
    List<Map<String, dynamic>> prices,
  ) async {
    try {
      await ApiService.dio.post('/api/products/prices', data: {
        'productId': productId,
        'prices': prices,
      });
      logger.i('Prices saved for productId $productId (${prices.length} unit types)');
      return true;
    } catch (e) {
      logger.e('Failed to save prices: $e');
      return false;
    }
  }
}
