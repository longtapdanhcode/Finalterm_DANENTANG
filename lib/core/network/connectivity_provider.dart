import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `true` khi thiết bị có ít nhất một kết nối mạng (Wi-Fi, di động, Ethernet...).
///
/// Chỉ phản ánh trạng thái giao diện mạng của hệ điều hành, không đảm bảo
/// máy chủ Supabase truy cập được. Phát giá trị ban đầu rồi cập nhật mỗi khi
/// kết nối thay đổi.
final isOnlineProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  yield _hasNetwork(await connectivity.checkConnectivity());
  yield* connectivity.onConnectivityChanged.map(_hasNetwork);
});

bool _hasNetwork(List<ConnectivityResult> results) =>
    results.any((r) => r != ConnectivityResult.none);
