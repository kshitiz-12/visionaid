import 'package:flutter_test/flutter_test.dart';
import 'package:visionaid/core/services/scene_policy.dart';
import 'package:visionaid/features/intent/data/intent_engine_impl.dart';

void main() {
  final engine = IntentEngineImpl();

  test('knowledge stays off-camera', () async {
    final potato = await engine.classify('What is potato in English?');
    expect(ScenePolicy.wantsCamera(potato), isFalse);

    final aalu = await engine.classify('aaloo ko English mein kya kehte hain');
    expect(ScenePolicy.wantsCamera(aalu), isFalse);
  });

  test('what is in front uses the camera', () async {
    final front = await engine.classify('What is in front of me?');
    expect(ScenePolicy.wantsCamera(front), isTrue);
  });

  test('repeat is recognised', () {
    expect(ScenePolicy.wantsRepeat('say that again'), isTrue);
    expect(ScenePolicy.wantsRepeat('दोहराओ'), isTrue);
    expect(ScenePolicy.wantsRepeat('what is a chair'), isFalse);
  });
}
