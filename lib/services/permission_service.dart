import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  /// Requests the camera permission and returns true if granted. Used when the
  /// user chooses to capture a photo/video from the file-upload sheet.
  Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.status;
    if (status.isGranted) {
      return true;
    }
    final result = await Permission.camera.request();
    return result.isGranted;
  }

  /// True when the camera permission was denied with "don't ask again", so the
  /// OS won't prompt anymore and the user must enable it from app settings.
  Future<bool> isCameraPermanentlyDenied() async {
    return (await Permission.camera.status).isPermanentlyDenied;
  }

  /// Whether the camera is usable right now, without prompting.
  Future<bool> isCameraGranted() async {
    return (await Permission.camera.status).isGranted;
  }

  /// True when the user has never answered the camera prompt, so requesting it
  /// will actually surface the system dialog.
  ///
  /// iOS reports the undecided state as `denied` and only ever moves to
  /// `permanentlyDenied` once the user has said no, so "can the OS still ask?"
  /// is `denied && !permanentlyDenied` rather than [PermissionStatus.denied]
  /// on its own — which is true in BOTH cases and would make the caller keep
  /// requesting a dialog that can never appear again.
  Future<bool> isCameraUndecided() async {
    if (Platform.isIOS) {
      final PermissionStatus status = await Permission.camera.status;
      return status.isDenied && !status.isPermanentlyDenied;
    }
    return (await Permission.camera.status).isDenied;
  }

  /// Opens the OS app-settings page for this app.
  Future<void> openSettings() => openAppSettings();

  /// Requests necessary permissions and returns true if essential ones are granted.
  Future<bool> checkAndRequestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      // Permission.notification,
      Permission.storage,
      Permission.photos,
      Permission.camera,
    ].request();

    // final notificationsGranted =
    //     statuses[Permission.notification]?.isGranted == true;
    final storageGranted = statuses[Permission.storage]?.isGranted == true;
    final photosGranted = statuses[Permission.photos]?.isGranted == true;
    final cameraGranted = statuses[Permission.camera]?.isGranted == true;

    // Based on your original logic, we need notifications + (storage OR photos)
    // return notificationsGranted && (storageGranted || photosGranted);
    if (Platform.isAndroid) {
      return cameraGranted && (storageGranted || photosGranted);
    } else {
      return cameraGranted && storageGranted && photosGranted;
    }
  }
}
