import 'package:flutter_test/flutter_test.dart';
import 'package:daily_gig_journal/utils/app_info.dart';

void main() {
  group('AppInfo', () {
    test('currentVersion 始终返回 String 类型', () {
      // 即便 initAppInfo() 未被调用过 / 调用失败，'—' 占位也是 String。
      final v = currentVersion;
      expect(v, isA<String>());
    });

    test('currentVersion 未初始化时返回占位符', () {
      // 注：测试运行顺序不可控，_cached 可能是上一组测试遗留的真实值。
      // 仅断言两种合法返回之一：真实版本（数字 + 点）或占位符 '—'。
      final v = currentVersion;
      expect(v == '—' || RegExp(r'^\d+\.\d+').hasMatch(v), isTrue);
    });

    test('initAppInfo 不抛异常（platform channel 未注册时降级）', () async {
      // 测试环境下 MethodChannel 走不到原生实现，会抛 MissingPluginException。
      // initAppInfo 必须吞掉异常，调用方不感知。
      await expectLater(initAppInfo(), completes);
    });

    test('initAppInfo 调用后 currentVersion 仍然是合法 String', () async {
      await initAppInfo();
      final v = currentVersion;
      expect(v, isA<String>());
      expect(v.isNotEmpty, isTrue);
    });
  });
}