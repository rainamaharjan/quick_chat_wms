import 'dart:io';
import 'package:flutter/material.dart';
import 'package:quick_chat_wms/services/notification_service.dart';
import 'package:quick_chat_wms/services/permission_service.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

class QuickChatWebViewService {
  late final WebViewController controller;

  void init({
    required String url,
    required String userName,
    required String email,
    required String fcmToken,
    required BuildContext context,
    required VoidCallback onPageLoaded,
    required Function(bool) onFileSelectorToggled,
  }) {
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'FlutterWebView',
        onMessageReceived: (JavaScriptMessage message) {
          String uniqueId = message.message;
          if (uniqueId.isEmpty) {
            uniqueId = _generateUniqueId();
          }
          _postTokenToApi(userName, email, fcmToken, uniqueId);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            if (!request.url.contains(url)) {
              _launchURL(request.url);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onPageFinished: (String pageUrl) async {
            await _injectViewportAndFetchId();
            onPageLoaded();
          },
        ),
      );

    if (Platform.isAndroid) {
      final androidController = controller.platform as AndroidWebViewController;
      androidController.setOnShowFileSelector(
        (params) => _androidFilePicker(params, context, onFileSelectorToggled),
      );
    }

    controller.loadRequest(Uri.parse(url));
  }

  Future<void> _injectViewportAndFetchId() async {
    await Future.delayed(const Duration(milliseconds: 500));
    await controller.runJavaScript("""
      (function() {
        if(document.querySelector('meta[name="viewport"]')) {
          document.querySelector('meta[name="viewport"]').setAttribute('content', 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no');
        } else {
          var meta = document.createElement('meta');
          meta.name = 'viewport';
          meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
          document.head.appendChild(meta);
        }

        if(window.localStorage) {
          var uniqueId = localStorage.getItem('uniqueId');
          if (uniqueId) {
            FlutterWebView.postMessage(uniqueId);
          }
        }
      })();
    """);
  }

  Future<List<String>> _androidFilePicker(
    FileSelectorParams params,
    BuildContext context,
    Function(bool) onFileSelectorToggled,
  ) async {
    onFileSelectorToggled(true);

    try {
      // Show the upload options first so the user always sees Camera / Gallery /
      // Video. Permission is requested per-choice below — only when needed and
      // only after the user taps the file-upload button in the web view.
      final String? choice = await showModalBottomSheet<String>(
        context: context,
        useRootNavigator: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
        ),
        builder: (BuildContext context) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Text(
                      'Upload File',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.photo_library),
                    title: const Text('Gallery / Files'),
                    onTap: () => Navigator.of(context).pop('gallery'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.camera_alt),
                    title: const Text('Take Photo'),
                    onTap: () => Navigator.of(context).pop('camera'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.videocam),
                    title: const Text('Record Video'),
                    onTap: () => Navigator.of(context).pop('video'),
                  ),
                ],
              ),
            ),
          );
        },
      );

      // Camera capture needs the camera permission, requested only when the
      // user picks a camera option. Gallery / Files goes through the system
      // file picker (SAF), which needs no runtime permission.
      if (choice == 'camera' || choice == 'video') {
        final permissionService = PermissionService();
        final cameraGranted = await permissionService.requestCameraPermission();
        if (!cameraGranted) {
          // When it's permanently denied the OS won't prompt anymore, so ask
          // the user (via a dialog) whether to open app settings to enable it.
          if (await permissionService.isCameraPermanentlyDenied() &&
              context.mounted) {
            final goToSettings = await _showCameraSettingsDialog(context);
            if (goToSettings == true) {
              await permissionService.openSettings();
            }
          }
          return [];
        }
      }

      if (choice == 'camera') {
        final photo = await ImagePicker().pickImage(
          source: ImageSource.camera,
          imageQuality: 70,
          maxWidth: 1920,
          maxHeight: 1080,
        );
        if (photo != null) return [Uri.file(photo.path).toString()];
      } else if (choice == 'video') {
        final video = await ImagePicker().pickVideo(source: ImageSource.camera);
        if (video != null) return [Uri.file(video.path).toString()];
      } else if (choice == 'gallery') {
        final result = await FilePicker.platform.pickFiles(
          allowMultiple: false,
          type: FileType.any,
        );
        if (result != null && result.files.isNotEmpty) {
          return result.files
              .where((file) => file.path != null)
              .map((file) => Uri.file(file.path!).toString())
              .toList();
        }
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
    } finally {
      onFileSelectorToggled(false);
    }

    return [];
  }

  /// Asks the user whether to open app settings to enable the camera permission
  /// (shown only when the permission is permanently denied). Returns true if the
  /// user chose to open settings.
  Future<bool?> _showCameraSettingsDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Camera permission required'),
          content: const Text(
            'Camera access is turned off for this app. To take a photo, enable '
            'the Camera permission in Settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  void _launchURL(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      debugPrint("❌ Could not launch $url");
    }
  }

  Future<void> _postTokenToApi(
    String username,
    String email,
    String fcmToken,
    String uniqueId,
  ) async {
    await NotificationHandlerService.updateFirebaseToken(
      username,
      email,
      fcmToken,
      uniqueId,
    );
  }

  String _generateUniqueId() {
    DateTime now = DateTime.now();
    return "${now.year}${now.month.toString().padLeft(2, '0')}"
        "${now.day.toString().padLeft(2, '0')}${now.hour.toString().padLeft(2, '0')}"
        "${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}"
        "${now.millisecond.toString().padLeft(3, '0')}";
  }
}
