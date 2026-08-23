import 'package:flutter_test/flutter_test.dart';
import 'package:visionaid/features/intent/data/intent_engine_impl.dart';
import 'package:visionaid/features/intent/domain/entities/user_intent.dart';

void main() {
  final engine = IntentEngineImpl();

  test('classifies emergency with high confidence', () async {
    final intent = await engine.classify('Emergency help me');
    expect(intent.type, IntentType.emergency);
    expect(intent.confidence, greaterThan(0.9));
    expect(intent.isActionable, isTrue);
  });

  test('routes read and find commands', () async {
    final read = await engine.classify('Read the sign above the door');
    expect(read.type, IntentType.readText);
    expect(read.target, 'sign');

    final find = await engine.classify('Where is the chair');
    expect(find.type, IntentType.findObject);
    expect(find.target, 'chair');
  });

  test('parses call by name as communication call', () async {
    final intent = await engine.classify('Call Harry');
    expect(intent.type, IntentType.communication);
    expect(intent.commAction, CommAction.call);
    expect(intent.contactName.toLowerCase(), 'harry');
  });

  test('parses WhatsApp and SMS commands', () async {
    final wa = await engine.classify('WhatsApp Harry saying I am late');
    expect(wa.type, IntentType.communication);
    expect(wa.commAction, CommAction.whatsapp);
    expect(wa.contactName.toLowerCase(), 'harry');
    expect(wa.messageBody.toLowerCase(), contains('late'));

    final sms = await engine.classify('Text Mom');
    expect(sms.commAction, CommAction.sms);
    expect(sms.contactName.toLowerCase(), 'mom');
  });

  test('quit closes the assistant', () async {
    final intent = await engine.classify('Quit');
    expect(intent.type, IntentType.quit);
  });

  test('defaults unknown speech to conversation, not vision', () async {
    final intent = await engine.classify('hello there');
    expect(intent.type, IntentType.conversation);
  });

  test('planning questions go to the companion, not emergency', () async {
    final intent = await engine.classify('Can you help me plan my evening');
    expect(intent.type, isNot(IntentType.emergency));
    expect(
      intent.type == IntentType.conversation || intent.type == IntentType.help,
      isTrue,
    );
  });

  test('open questions stay conversation, not camera', () async {
    final weather = await engine.classify('What is the weather like today');
    expect(weather.type, IntentType.conversation);

    final recipe = await engine.classify('How do I make tea');
    expect(recipe.type, IntentType.conversation);

    final feeling = await engine.classify('I feel lonely tonight');
    expect(feeling.type, IntentType.conversation);
  });

  test('stop guiding is cancel', () async {
    final intent = await engine.classify('Stop guiding');
    expect(intent.type, IntentType.cancel);
  });
}

