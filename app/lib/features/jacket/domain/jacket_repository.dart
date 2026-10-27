import 'jacket_status.dart';

abstract interface class JacketRepository {
  Future<JacketStatus> fetchStatus();
}
