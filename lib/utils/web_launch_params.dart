// Conditional import to read launch parameters from web sessionStorage when running on web.
// On non-web platforms, these functions return null/no-op.
export 'src/web_launch_params_stub.dart'
    if (dart.library.html) 'src/web_launch_params_web.dart';
