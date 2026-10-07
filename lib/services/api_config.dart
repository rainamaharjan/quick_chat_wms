import 'dart:convert';

/// The QuickChat host. Production by default; the host app points the SDK at
/// UAT (https://wms-uat.worldlink.com.np) with `QuickChatWms.setBaseUrl`,
/// before `QuickChatWms.init`.
String quickChatBaseUrl = 'https://app.quickconnect.biz';

/// The widget the SDK was last initialised with (`QuickChatWms.init`).
String quickChatWidgetCode = '';

/// Production value of [quickChatStaticToken], used until `init` has run.
const String _productionStaticToken =
    'UWNmOGYwMjlmYS0yZWE4LTQyNzAtODUwOS1iNDViMzUwZTZlM2Y=';

/// Static API token sent as the `token` POST parameter on the QuickConnect
/// endpoints (`get-unique-id`, `store-firebase-token`): base64 of `Qc` + the
/// widget code. The old fixed value is exactly that for the production widget
/// (f8f029fa-…), so deriving it changes nothing there and lets a UAT widget
/// work too. Base64 — the trailing `=` is padding and MUST be kept, or the
/// server rejects it with `400 {"message":"Invalid token."}`.
String get quickChatStaticToken => quickChatWidgetCode.isEmpty
    ? _productionStaticToken
    : base64.encode(utf8.encode('Qc$quickChatWidgetCode'));

/// Sent as the `X-Auth-Token` header on the same QuickConnect endpoints
/// (`get-unique-id`, `store-firebase-token`).
const String quickChatAuthHeaderToken = 'K7mP2xQ9vL4nR8sT5aW3cD6fH1jN0pZ';
