import 'api_client.dart';

class CustomerService {
  Future<List<Map<String, dynamic>>> listCustomers({String search = ''}) async {
    try {
      final response = await ApiClient.dio.get('/admin/customers', queryParameters: {
        'search': search,
      });
      if (response.data is List) {
        return List<Map<String, dynamic>>.from(response.data);
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getCustomerById(int id) async {
    try {
      final response = await ApiClient.dio.get('/admin/customers/$id');
      return response.data as Map<String, dynamic>?;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createCustomer({
    required String fullName,
    String? phone,
    String? email,
    String? note,
  }) async {
    final response = await ApiClient.dio.post('/admin/customers', data: {
      'full_name': fullName,
      'phone': phone,
      'email': email,
      'note': note,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateCustomer(int id, Map<String, dynamic> data) async {
    final response = await ApiClient.dio.patch('/admin/customers/$id', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<void> deleteCustomer(int id) async {
    await ApiClient.dio.delete('/admin/customers/$id');
  }

  Future<Map<String, dynamic>> addTransaction({
    required int customerId,
    int? orderId,
    required String type, // 'DEBIT' or 'CREDIT'
    required double amount,
    String? note,
  }) async {
    final response = await ApiClient.dio.post('/admin/customers/transactions', data: {
      'customer_id': customerId,
      'order_id': orderId,
      'type': type,
      'amount': amount,
      'note': note,
    });
    return response.data as Map<String, dynamic>;
  }
}
