import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/order_model.dart';

class OrderRepository {
  OrderRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _orders =>
      _firestore.collection('orders');

  Future<OrderModel?> getOrderById(String orderId) async {
    final snapshot = await _orders.doc(orderId.trim()).get();
    if (!snapshot.exists) {
      return null;
    }

    return _orderFromSnapshot(snapshot);
  }

  Stream<OrderModel?> watchOrderById(String orderId) {
    return _orders.doc(orderId.trim()).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return null;
      }

      return _orderFromSnapshot(snapshot);
    });
  }

  OrderModel _orderFromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = Map<String, dynamic>.from(snapshot.data() ?? {});
    data['id'] ??= snapshot.id;
    data['totalAmount'] ??= data['totalPrice'] ?? data['amount'] ?? 0;
    data['orderStatus'] ??= data['status'];
    data['paymentStatus'] ??= data['paymentStatus'] ?? data['status'];
    return OrderModel.fromJson(data);
  }
}
