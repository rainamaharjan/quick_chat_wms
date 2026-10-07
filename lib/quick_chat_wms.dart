import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:quick_chat_wms/models/prefrence_model.dart';
import 'package:quick_chat_wms/services/api_config.dart';
import 'package:quick_chat_wms/services/app_preference_service.dart';
import 'package:quick_chat_wms/services/client_service.dart';
import 'package:quick_chat_wms/services/notification_service.dart';
import 'package:quick_chat_wms/services/secure_storage_service.dart';
import 'package:quick_chat_wms/services/webview_service.dart';
import 'package:quick_chat_wms/widget/quick_chat_widget.dart';

bool isChatScreen = false;

class QuickChatWms {
  static final AppPreferencesService _prefsService = AppPreferencesService(
    secureStorageService: SecureStorageService(),
  );

  /// Optional hook fired when the chat WebView fails to load its page (server
  /// error status or transport failure). Set it during app init to forward the
  /// failure — status code and url, no user content — to crash/analytics
  /// logging, so failures on customer devices are diagnosable in the field.
  static QuickChatLoadErrorCallback? onChatLoadError;

  static final NotificationHandlerService _notificationService =
      NotificationHandlerService(prefsService: _prefsService);

  /// True while an upload picker opened by the chat is on screen.
  ///
  /// The host MUST NOT tear the chat's WebView down while this is set. Putting
  /// up the camera or the photo library drives the app through the same
  /// lifecycle transition as the user leaving, and a host that reacts to that
  /// by dropping the WebView destroys the page the picked file is about to be
  /// handed back to — the upload then completes into a view that is no longer
  /// on screen, so the file silently never arrives and the chat looks like it
  /// closed itself.
  ///
  /// A plain static because the host reads it from its own lifecycle observer,
  /// with no reference to this widget or its controller.
  static bool isFileSelectorActive = false;

  /// The signed-in user's bearer token from the host app, sent as `mobile_token`
  /// on `store-firebase-token` so the server can tell whose device it is.
  ///
  /// Kept in memory only — never written to storage, never logged. The host
  /// sets it on every launch and login, BEFORE [setFcmToken], and it is
  /// cleared on [logout] and [resetUser].
  static String _userToken = '';
  static String get userToken => _userToken;

  static void setUserToken(String? token) {
    _userToken = token ?? '';
  }

  /// The mobile number the user is logged in with, sent as `mobile` on
  /// `store-firebase-token`. Same rules as [userToken]: memory only, set by
  /// the host before [setFcmToken], cleared on [logout] and [resetUser].
  static String _userMobile = '';
  static String get userMobile => _userMobile;

  static void setUserMobile(String? mobile) {
    _userMobile = mobile ?? '';
  }

  /// Points the SDK at another QuickChat host — the chat page and both API
  /// endpoints. Production (https://app.quickconnect.biz) unless called; the
  /// host app calls it before [init], e.g. with https://wms-uat.worldlink.com.np
  /// for a UAT build.
  static void setBaseUrl(String url) {
    if (url.isNotEmpty) {
      quickChatBaseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    }
  }

  // CHANGED: void -> Future<void>
  static Future<void> init(
    BuildContext context, {
    String widgetCode = '',
    Color backgroundColor = Colors.white,
    String appBarTitle = 'Chat With Us',
    Color appBarBackgroundColor = Colors.blueAccent,
    Color appBarTitleColor = Colors.white,
    Color appBarBackButtonColor = Colors.white,
  }) async {
    debugPrint("Quick chat ---------- start chat");

    // The API `token` is derived from it — see quickChatStaticToken.
    quickChatWidgetCode = widgetCode;
    await _prefsService.updatePreferences(
      data: (currentData) => currentData.copyWith(
        widgetCode: widgetCode,
        backgroundColor: backgroundColor,
        appBarTitle: appBarTitle,
        appBarBackgroundColor: appBarBackgroundColor,
        appBarTitleColor: appBarTitleColor,
        appBarBackButtonColor: appBarBackButtonColor,
      ),
    );
  }

  static Widget get screen => const QuickChatWidget();

  static void handleNotificationOnClick(BuildContext context) async {
    debugPrint("Quick chat ---------- handleNotificationOnClick ");
    await _notificationService.handleNotificationClick(context);
  }

  static void initializeNotification(BuildContext context) async {
    await _notificationService.initNotification(context);
  }

  static void showQuickChatNotification(Map<String, dynamic> data) {
    debugPrint("Quick chat ---------- showQuickChatNotification ");
    if (isChatScreen) {
      return;
    }
    _notificationService.showQuickChatNotification(data);
  }

  // CHANGED: void -> Future<void>
  static Future<void> setFcmToken(String? fcmToken) async {
    print('QUICKCHAT:::: FCM Update: $fcmToken');

    await _prefsService.updatePreferences(
      data: (current) => current.copyWith(fcmToken: fcmToken ?? ''),
    );

    // A logged-in user ([userToken] set) is registered by the host through
    // [registerFirebaseToken] — once per login, account switch or token
    // rotation — so storing the token is all that happens here.
    if (_userToken.isNotEmpty) return;

    // Not logged in: unchanged. Re-register directly if this client's uniqueId
    // is known (captured on a prior chat open).
    final String token = fcmToken ?? '';
    if (token.isEmpty) return;
    final String uniqueId =
        await SecureStorageService().read(key: 'qc_client_unique_id') ?? '';
    if (uniqueId.isEmpty) return;
    final prefs = await _prefsService.getPreferences();
    await NotificationHandlerService.updateFirebaseToken(
      prefs.userName,
      prefs.email,
      token,
      uniqueId,
    );
  }

  /// Registers the logged-in user's FCM token with `store-firebase-token`.
  ///
  /// The host calls this when the user lands on the dashboard after login or
  /// an account switch, and when the FCM token rotates — after [setUserName],
  /// [setEmail], [setUserToken] and [setFcmToken]. Sent once: the same user,
  /// token and client id are not registered again on later app starts or chat
  /// opens (see [NotificationHandlerService.updateFirebaseToken]).
  ///
  /// Right after login the client id is not on the device yet (logout deletes
  /// it), so it is looked up with `get-unique-id`. A user with no conversation
  /// yet has none; their first chat registers once when the page mints one.
  static Future<void> registerFirebaseToken() async {
    if (_userToken.isEmpty) return;
    final prefs = await _prefsService.getPreferences();
    if (prefs.fcmToken.isEmpty || prefs.userName.isEmpty) return;
    final SecureStorageService storage = SecureStorageService();
    String uniqueId = await storage.read(key: 'qc_client_unique_id') ?? '';
    if (uniqueId.isEmpty) {
      uniqueId = await ClientService.fetchClientUniqueId(
            widgetCode: prefs.widgetCode,
            userName: prefs.userName,
          ) ??
          '';
      if (uniqueId.isEmpty) {
        if (kDebugMode) {
          debugPrint(
            'QUICKCHAT_STORE_FCM_TOKEN deferred: "${prefs.userName}" has no '
            'client_unique_id yet (registers on their first chat)',
          );
        }
        return;
      }
      await storage.write(key: 'qc_client_unique_id', value: uniqueId);
    }
    await NotificationHandlerService.updateFirebaseToken(
      prefs.userName,
      prefs.email,
      prefs.fcmToken,
      uniqueId,
      skipIfRegistered: true,
    );
  }

  // CHANGED: void -> Future<void>
  static Future<void> setUserName(String? username) async {
    print('QUICKCHAT:::: UserName Update: $username');

    await _prefsService.updatePreferences(
      data: (currentData) => currentData.copyWith(userName: username ?? ''),
    );
  }

  // CHANGED: void -> Future<void>
  static Future<void> setEmail(String? email) async {
    print('QUICKCHAT:::: Email Update: $email');
    await _prefsService.updatePreferences(
      data: (currentData) => currentData.copyWith(email: email ?? ''),
    );
  }

  static bool isQuickChatNotification(Map<String, dynamic> data) {
    debugPrint("Quick chat ----------is quick chat notification");
    String? clickAction = data['click_action'];
    if (clickAction == null || clickAction.isEmpty) {
      return false;
    }

    return clickAction == 'QUICK_CHAT_NOTIFICATION';
  }

  /// Ends the logged-in user's chat session while KEEPING the widget
  /// configuration, so the chat still works for an anonymous (logged-out) user.
  ///
  /// Use this on logout instead of [resetUser]: that one wipes everything —
  /// including the widget code — which leaves the WebView loading a blank
  /// `widgetId=`. That's fine when a fresh [init] follows immediately (a user
  /// switch), but wrong on logout, where the floating chat must keep working.
  ///
  /// The identity is dropped and the WebView's stored client id is marked for
  /// deletion, so the next chat starts as a brand-new conversation with a new
  /// `client_unique_id` — the logged-out user cannot see the previous user's
  /// history. Logging back in re-fetches the real id via `get-unique-id` and
  /// restores that conversation.
  static Future<void> logout() async {
    debugPrint("Quick chat ---------- logout");

    // Deregister push for the user who just logged out.
    await NotificationHandlerService.updateFirebaseToken('', '', '', '');
    _userToken = '';
    _userMobile = '';

    await SecureStorageService().delete(key: 'qc_client_unique_id');
    // Force the next login to re-fetch its history instead of trusting the
    // localStorage we're about to wipe.
    await SecureStorageService().delete(key: kRestoredUserKey);
    await _prefsService.updatePreferences(
      data: (current) => current.copyWith(
        userName: '',
        email: '',
        // Consumed by QuickChatWidget on its next mount: wipes the WebView's
        // localStorage so the page mints a fresh client_unique_id.
        resetLocalStorage: true,
      ),
    );
  }

  // This was already Future<void>, which is correct!
  static Future<void> resetUser() async {


    await _prefsService.clearAllPreferences();
    await _prefsService.updatePreferences(
      data: (currentData) => AppPreferences(),
    );
    await NotificationHandlerService.updateFirebaseToken('', '', '', '');
    _userToken = '';
    _userMobile = '';
    debugPrint("Quick chat ----------reset user");
  }
}
