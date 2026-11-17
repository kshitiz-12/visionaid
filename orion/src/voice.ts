import * as Speech from 'expo-speech';

export function speak(text: string) {
  Speech.stop();
  const clean = String(text || '')
    .replace(/\*/g, '')
    .replace(/\s+/g, ' ')
    .trim();
  if (!clean) return Promise.resolve();
  return new Promise<void>((resolve) => {
    Speech.speak(clean, {
      language: 'en-IN',
      rate: 0.96,
      onDone: () => resolve(),
      onStopped: () => resolve(),
      onError: () => resolve(),
    });
  });
}

export function stopSpeaking() {
  Speech.stop();
}
