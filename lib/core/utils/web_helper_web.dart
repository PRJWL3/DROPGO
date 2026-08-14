import 'dart:js' as js;

bool isGoogleMapsInitialized() {
  try {
    if (js.context.hasProperty('google')) {
      final google = js.context['google'];
      if (google != null && google is js.JsObject && google.hasProperty('maps')) {
        return true;
      }
    }
  } catch (e) {
    // Return false if JS context fails to read properties
  }
  return false;
}
