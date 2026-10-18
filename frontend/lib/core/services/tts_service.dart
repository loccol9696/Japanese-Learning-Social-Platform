// Web dùng Web Speech API qua dart:js_interop; native/VM (kể cả flutter test)
// dùng bản stub để không phải compile thư viện chỉ có trên web.
export 'tts_service_stub.dart'
    if (dart.library.js_interop) 'tts_service_web.dart';
