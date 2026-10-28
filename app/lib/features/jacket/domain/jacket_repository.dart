import 'jacket_status.dart';

abstract interface class JacketRepository {
  /// Latest snapshot, then a new one every time the jacket reports.
  Stream<JacketStatus> watchStatus();
}
