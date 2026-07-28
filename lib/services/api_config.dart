/// Single place the QuickChat host is configured. Swap this to
/// https://wms-uat.worldlink.com.np to point the SDK at UAT.
const String quickChatBaseUrl = 'https://app.quickconnect.biz';

/// Static API token sent as the `token` POST parameter on the QuickConnect
/// endpoints (`get-unique-id`, `store-firebase-token`). This is a base64 value
/// — the trailing `=` is its padding and MUST be kept, or the server rejects it
/// with `400 {"message":"Invalid token."}`.
const String quickChatStaticToken =
    'UWNmOGYwMjlmYS0yZWE4LTQyNzAtODUwOS1iNDViMzUwZTZlM2Y=';
