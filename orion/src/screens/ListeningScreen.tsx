import React, { useEffect, useState } from 'react';
import {
  KeyboardAvoidingView,
  Platform,
  Pressable,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import { NativeStackScreenProps } from '@react-navigation/native-stack';
import { BlackHole } from '../components/BlackHole';
import { Starfield } from '../components/Starfield';
import { Waveform } from '../components/Waveform';
import { RootStackParamList } from '../navigation/types';
import { colors } from '../theme';

type Props = NativeStackScreenProps<RootStackParamList, 'Listening'>;

export function ListeningScreen({ navigation }: Props) {
  const [text, setText] = useState('');
  const [showKeyboard, setShowKeyboard] = useState(false);

  useEffect(() => {
    // Demo auto-prompt if user waits — keeps flow moving without native STT in Expo Go
    const t = setTimeout(() => setShowKeyboard(true), 1200);
    return () => clearTimeout(t);
  }, []);

  const submit = (spoken: string) => {
    const s = spoken.trim();
    if (!s) return;
    navigation.replace('Processing', { spoken: s });
  };

  return (
    <KeyboardAvoidingView
      style={styles.root}
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
    >
      <Starfield planet />
      <View style={styles.top}>
        <Pressable onPress={() => navigation.goBack()}>
          <Text style={styles.back}>‹</Text>
        </Pressable>
        <Text style={styles.logo}>O R I O N</Text>
        <View style={{ width: 28 }} />
      </View>

      <Waveform bars={18} height={22} active />
      <Text style={styles.listening}>I’m Listening...</Text>

      <View style={styles.hero}>
        <BlackHole size={260} intensity="listen" />
      </View>

      <Waveform bars={36} height={42} active />

      {showKeyboard ? (
        <View style={styles.inputWrap}>
          <TextInput
            value={text}
            onChangeText={setText}
            placeholder="Type or speak a command…"
            placeholderTextColor={colors.whiteFaint}
            style={styles.input}
            autoFocus
            onSubmitEditing={() => submit(text)}
            returnKeyType="send"
          />
        </View>
      ) : null}

      <View style={styles.controls}>
        <Pressable style={styles.sideBtn} onPress={() => navigation.goBack()}>
          <Text style={styles.sideIcon}>✕</Text>
        </Pressable>
        <Pressable
          style={styles.mainBtn}
          onPress={() => submit(text || 'what is the last mail')}
        >
          <Text style={styles.mainIcon}>■</Text>
        </Pressable>
        <Pressable
          style={styles.sideBtn}
          onPress={() => setShowKeyboard((v) => !v)}
        >
          <Text style={styles.sideIcon}>⌨</Text>
        </Pressable>
      </View>
      <Text style={styles.hint}>
        Expo Go: type your command, then tap stop. Native STT comes with a
        dev build.
      </Text>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: colors.bgDeep },
  top: {
    paddingTop: 52,
    paddingHorizontal: 16,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  back: { color: colors.white, fontSize: 34, width: 28 },
  logo: { color: colors.white, letterSpacing: 8, fontWeight: '600' },
  listening: {
    textAlign: 'center',
    color: colors.white,
    fontSize: 28,
    fontWeight: '700',
    marginTop: 10,
  },
  hero: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  inputWrap: { paddingHorizontal: 20, marginBottom: 10 },
  input: {
    borderRadius: 16,
    borderWidth: 1,
    borderColor: colors.glassBorder,
    backgroundColor: colors.glass,
    color: colors.white,
    paddingHorizontal: 14,
    paddingVertical: 12,
    fontSize: 15,
  },
  controls: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 28,
    paddingBottom: 18,
  },
  sideBtn: {
    width: 52,
    height: 52,
    borderRadius: 26,
    borderWidth: 1,
    borderColor: colors.glassBorder,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: colors.glass,
  },
  sideIcon: { color: colors.white, fontSize: 18 },
  mainBtn: {
    width: 78,
    height: 78,
    borderRadius: 39,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: colors.cyan,
    shadowColor: colors.cyanBright,
    shadowOpacity: 0.9,
    shadowRadius: 18,
  },
  mainIcon: { color: colors.white, fontSize: 22 },
  hint: {
    textAlign: 'center',
    color: colors.whiteFaint,
    fontSize: 11,
    paddingHorizontal: 28,
    paddingBottom: 20,
  },
});
