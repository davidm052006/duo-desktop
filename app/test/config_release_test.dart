import 'package:duo_desktop/src/auth/config_supabase.dart';
import 'package:duo_desktop/src/config_cloud.dart';
import 'package:flutter_test/flutter_test.dart';

const _releaseConfigCheck = bool.fromEnvironment('RELEASE_CONFIG_CHECK');

void main() {
  test('la configuración compilada de release habilita Cloud y Supabase', () {
    if (!_releaseConfigCheck) return;

    expect(ConfigCloud.configurado, isTrue);
    expect(ConfigSupabase.configurado, isTrue);
    expect(ConfigCloud.url, startsWith('https://'));
    expect(ConfigSupabase.url, startsWith('https://'));
    expect(ConfigSupabase.publishableKey, isNotEmpty);
    expect(ConfigCloud.endpoint('/api/projects').toString(),
        '${ConfigCloud.url}/api/projects');
  });
}
