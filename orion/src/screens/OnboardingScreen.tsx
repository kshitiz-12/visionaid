import React from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { NativeStackScreenProps } from '@react-navigation/native-stack';
import { BlackHole } from '../components/BlackHole';
import { GlowButton } from '../components/GlowButton';
import { Starfield } from '../components/Starfield';
import { RootStackParamList } from '../navigation/types';
import { colors } from '../theme';

type Props = NativeStackScreenProps<RootStackParamList, 'Onboarding'>;

const FEATURES = [
  { icon: '🎙', label: 'Voice\nControl' },
  { icon: '💬', label: 'AI\nChat' },
  { icon: '▦', label: 'App\nControl' },
  { icon: '⚡', label: 'Do\nMore' },
];

export function OnboardingScreen({ navigation }: Props) {
  return (
    <View style={styles.root}>
      <Starfield />
      <Text style={styles.logo}>O R I O N</Text>
      <View style={styles.orbitLine} />
      <View style={styles.hero}>
        <BlackHole size={220} intensity="hero" />
      </View>
      <Text style={styles.meet}>
        Meet <Text style={styles.cyan}>ORION</Text>
      </Text>
      <Text style={styles.sub}>Your intelligent companion</Text>

      <View style={styles.card}>
        {FEATURES.map((f, i) => (
          <React.Fragment key={f.label}>
            {i > 0 ? <View style={styles.divider} /> : null}
            <View style={styles.feat}>
              <Text style={styles.featIcon}>{f.icon}</Text>
              <Text style={styles.featLabel}>{f.label}</Text>
            </View>
          </React.Fragment>
        ))}
      </View>

      <View style={styles.dots}>
        <View style={[styles.dot, styles.dotOn]} />
        <View style={styles.dot} />
        <View style={styles.dot} />
      </View>

      <GlowButton
        label="Get Started  →"
        onPress={() => navigation.replace('Home')}
        style={{ marginHorizontal: 28, marginTop: 18 }}
      />
      <Pressable onPress={() => navigation.replace('Home')} style={styles.skip}>
        <Text style={styles.skipText}>Skip</Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: colors.bgDeep, paddingTop: 54 },
  logo: {
    textAlign: 'center',
    color: colors.white,
    letterSpacing: 10,
    fontSize: 16,
    fontWeight: '600',
  },
  orbitLine: {
    alignSelf: 'center',
    marginTop: 8,
    width: 120,
    height: 18,
    borderRadius: 40,
    borderWidth: 1.5,
    borderColor: colors.cyan,
    opacity: 0.7,
  },
  hero: { alignItems: 'center', marginTop: 8 },
  meet: {
    marginTop: 8,
    textAlign: 'center',
    color: colors.white,
    fontSize: 30,
    fontWeight: '700',
  },
  cyan: { color: colors.cyanBright },
  sub: {
    textAlign: 'center',
    color: colors.whiteMuted,
    marginTop: 6,
    fontSize: 15,
  },
  card: {
    marginTop: 22,
    marginHorizontal: 22,
    borderRadius: 22,
    borderWidth: 1,
    borderColor: colors.glassBorder,
    backgroundColor: colors.glass,
    flexDirection: 'row',
    paddingVertical: 16,
    paddingHorizontal: 8,
  },
  feat: { flex: 1, alignItems: 'center', gap: 6 },
  featIcon: { fontSize: 20, color: colors.cyanBright },
  featLabel: {
    color: colors.whiteMuted,
    fontSize: 11,
    textAlign: 'center',
    lineHeight: 14,
  },
  divider: {
    width: 1,
    backgroundColor: 'rgba(0,180,255,0.2)',
    marginVertical: 4,
  },
  dots: {
    flexDirection: 'row',
    justifyContent: 'center',
    gap: 8,
    marginTop: 18,
  },
  dot: {
    width: 7,
    height: 7,
    borderRadius: 4,
    backgroundColor: 'rgba(255,255,255,0.25)',
  },
  dotOn: { backgroundColor: colors.cyanBright, width: 18 },
  skip: { alignItems: 'center', marginTop: 14 },
  skipText: { color: colors.whiteFaint },
});
