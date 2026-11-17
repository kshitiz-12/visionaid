import React, { useEffect, useState } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import Animated, {
  Easing,
  useAnimatedStyle,
  useSharedValue,
  withRepeat,
  withTiming,
} from 'react-native-reanimated';
import { NativeStackScreenProps } from '@react-navigation/native-stack';
import { BlackHole } from '../components/BlackHole';
import { Starfield } from '../components/Starfield';
import { sendCommand } from '../api';
import { speak } from '../voice';
import { RootStackParamList } from '../navigation/types';
import { colors } from '../theme';

type Props = NativeStackScreenProps<RootStackParamList, 'Processing'>;

const STEPS = [
  { label: 'Understanding command...', icon: '↻' },
  { label: 'Analyzing intent...', icon: '🛡' },
  { label: 'Preparing action...', icon: '▦' },
];

export function ProcessingScreen({ navigation, route }: Props) {
  const { spoken } = route.params;
  const [done, setDone] = useState([false, false, false]);
  const spin = useSharedValue(0);

  useEffect(() => {
    spin.value = withRepeat(
      withTiming(360, { duration: 900, easing: Easing.linear }),
      -1,
      false,
    );
  }, [spin]);

  const spinStyle = useAnimatedStyle(() => ({
    transform: [{ rotate: `${spin.value}deg` }],
  }));

  useEffect(() => {
    let cancelled = false;
    (async () => {
      setDone([true, false, false]);
      await new Promise((r) => setTimeout(r, 450));
      if (cancelled) return;
      setDone([true, true, false]);
      await new Promise((r) => setTimeout(r, 450));
      if (cancelled) return;

      try {
        const result = await sendCommand(spoken);
        if (cancelled) return;
        setDone([true, true, true]);
        await speak(result.spoken);
        if (cancelled) return;
        if (result.pending) {
          navigation.replace('Action', {
            spoken,
            reply: result.spoken,
            pending: result.pending,
            intentType: result.intentType,
          });
        } else {
          navigation.replace('Action', {
            spoken,
            reply: result.spoken,
            pending: null,
            intentType: result.intentType,
          });
        }
      } catch (e) {
        if (cancelled) return;
        navigation.replace('Action', {
          spoken,
          reply: `Backend unreachable. Check Settings API URL. ${String(e)}`,
          pending: null,
        });
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [navigation, spoken]);

  return (
    <View style={styles.root}>
      <Starfield planet />
      <Text style={styles.logo}>O R I O N</Text>
      <View style={styles.hero}>
        <BlackHole size={240} intensity="process" />
      </View>
      <Text style={styles.status}>Processing your request...</Text>

      <View style={styles.card}>
        {STEPS.map((s, i) => (
          <View key={s.label}>
            <View style={styles.row}>
              <Text style={styles.icon}>{s.icon}</Text>
              <Text style={styles.label}>{s.label}</Text>
              {done[i] ? (
                <View style={styles.check}>
                  <Text style={styles.checkMark}>✓</Text>
                </View>
              ) : i === done.filter(Boolean).length ? (
                <Animated.View style={[styles.spinner, spinStyle]} />
              ) : (
                <View style={styles.pending} />
              )}
            </View>
            {i < STEPS.length - 1 ? <View style={styles.line} /> : null}
          </View>
        ))}
      </View>
      <Text style={styles.cmd}>“{spoken}”</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: colors.bgDeep, paddingTop: 54 },
  logo: {
    textAlign: 'center',
    color: colors.white,
    letterSpacing: 8,
    fontWeight: '600',
  },
  hero: { alignItems: 'center', marginTop: 20 },
  status: {
    textAlign: 'center',
    color: colors.white,
    fontSize: 22,
    fontWeight: '600',
    marginTop: 8,
    marginHorizontal: 24,
  },
  card: {
    marginTop: 28,
    marginHorizontal: 22,
    borderRadius: 22,
    borderWidth: 1,
    borderColor: colors.glassBorder,
    backgroundColor: colors.glass,
    paddingHorizontal: 16,
    paddingVertical: 8,
  },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 14,
    gap: 12,
  },
  icon: { width: 28, textAlign: 'center', fontSize: 16 },
  label: { flex: 1, color: colors.white, fontSize: 15 },
  check: {
    width: 26,
    height: 26,
    borderRadius: 13,
    backgroundColor: colors.cyan,
    alignItems: 'center',
    justifyContent: 'center',
  },
  checkMark: { color: colors.white, fontWeight: '700' },
  spinner: {
    width: 22,
    height: 22,
    borderRadius: 11,
    borderWidth: 2,
    borderColor: colors.cyanBright,
    borderTopColor: 'transparent',
  },
  pending: {
    width: 22,
    height: 22,
    borderRadius: 11,
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.2)',
  },
  line: {
    height: StyleSheet.hairlineWidth,
    backgroundColor: 'rgba(255,255,255,0.12)',
    marginLeft: 40,
  },
  cmd: {
    marginTop: 20,
    textAlign: 'center',
    color: colors.whiteFaint,
    paddingHorizontal: 28,
  },
});
