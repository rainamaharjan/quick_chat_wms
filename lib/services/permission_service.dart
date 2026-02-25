import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  /// Requests necessary permissions and returns true if essential ones are granted.
  Future<bool> checkAndRequestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.storage,
      Permission.photos,
      Permission.camera,
    ].request();

    final storageGranted = statuses[Permission.storage]?.isGranted == true;
    final photosGranted = statuses[Permission.photos]?.isGranted == true;
    final cameraGranted = statuses[Permission.camera]?.isGranted == true;

    // Based on your original logic, we need notifications + (storage OR photos)
    return cameraGranted && storageGranted && photosGranted;
  }
}
