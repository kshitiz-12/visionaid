import React, { useMemo } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { NativeStackScreenProps } from '@react-navigation/native-stack';
import { BlackHole } from '../components/BlackHole';
import { GlowButton } from '../components/GlowButton';
import { Starfield } from '../components/Starfield';
import { Waveform } from '../components/Waveform';
import { RootStackParamList } from '../navigation/types';
import { colors } from '../theme';

type Props = NativeStackScreenProps<RootStackParamList, 'Home'>;

const APPS = [
  { icon: '💬', label: 'AI Chat' },
  { icon: '🟢', label: 'WhatsApp' },
  { icon: '📞', label: 'Call' },
  { icon: '▦', label: 'Apps' },
  { icon: '🎵', label: 'Music' },
  { icon: '🔍', label: 'Search' },
];

const QUICK = [
  'Send a WhatsApp message',
  'What is the last mail',
  'Who messaged me',
];

export function HomeScreen({ navigation }: Props) {
  const greet = useMemo(() => {
    const h = new Date().getHours();
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }, []);

  return (
    <View style={styles.root}>
      <Starfield planet />
      <View style={styles.topBar}>
        <Text style={styles.menu}>☰</Text>
        <Text style={styles.logo}>O R I O N</Text>
        <Text style={styles.bell}>🔔</Text>
      </View>

      <ScrollView contentContainerStyle={styles.scroll} showsVerticalScrollIndicator={false}>
        <Text style={styles.hello}>
          {greet} 👋
        </Text>
        <Text style={styles.ask}>How can I assist you today?</Text>

        <View style={styles.hero}>
          <BlackHole size={200} intensity="hero" />
          <Waveform bars={24} height={28} active />
        </View>

        <GlowButton
          label="Tap to Talk"
          icon={<Text style={{ fontSize: 18 }}>🎙</Text>}
          onPress={() => navigation.navigate('Listening')}
          style={{ marginHorizontal: 36, marginTop: 12 }}
        />

        <View style={styles.grid}>
          {APPS.map((a) => (
            <Pressable
              key={a.label}
              style={styles.tile}
              onPress={() => {
                if (a.label === 'WhatsApp') {
                  navigation.navigate('Processing', {
                    spoken: 'open whatsapp',
                  });
                } else if (a.label === 'AI Chat') {
                  navigation.navigate('Listening');
                } else if (a.label === 'Search') {
                  navigation.navigate('Processing', {
                    spoken: 'what is the time',
                  });
                } else {
                  navigation.navigate('Listening');
                }
              }}
            >
              <Text style={styles.tileIcon}>{a.icon}</Text>
              <Text style={styles.tileLabel}>{a.label}</Text>
            </Pressable>
          ))}
        </View>

        <View style={styles.quickCard}>
          <Text style={styles.quickTitle}>⚡ Quick Commands</Text>
          {QUICK.map((q, i) => (
            <Pressable
              key={q}
              style={[styles.quickRow, i < QUICK.length - 1 && styles.quickBorder]}
              onPress={() => navigation.navigate('Processing', { spoken: q })}
            >
              <Text style={styles.quickText}>{q}</Text>
              <Text style={styles.chev}>›</Text>
            </Pressable>
          ))}
        </View>
      </ScrollView>

      <View style={styles.tab}>
        <View style={[styles.tabItem, styles.tabOn]}>
          <Text style={styles.tabIcon}>⌂</Text>
        </View>
        <Pressable style={styles.tabItem} onPress={() => navigation.navigate('Listening')}>
          <Text style={styles.tabIcon}>💬</Text>
        </Pressable>
        <Pressable style={styles.tabItem} onPress={() => navigation.navigate('Settings')}>
          <Text style={styles.tabIcon}>⏱</Text>
        </Pressable>
        <Pressable style={styles.tabItem} onPress={() => navigation.navigate('Settings')}>
          <Text style={styles.tabIcon}>⚙</Text>
        </Pressable>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: colors.bgDeep },
  topBar: {
    paddingTop: 52,
    paddingHorizontal: 18,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  menu: { color: colors.white, fontSize: 22, width: 36 },
  logo: { color: colors.white, letterSpacing: 8, fontWeight: '600' },
  bell: { fontSize: 18, width: 36, textAlign: 'right' },
  scroll: { paddingBottom: 110 },
  hello: {
    marginTop: 14,
    marginHorizontal: 20,
    color: colors.white,
    fontSize: 28,
    fontWeight: '700',
  },
  ask: {
    marginHorizontal: 20,
    marginTop: 4,
    color: colors.whiteMuted,
    fontSize: 15,
  },
  hero: { alignItems: 'center', marginTop: 6, gap: 8 },
  grid: {
    marginTop: 22,
    marginHorizontal: 16,
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 10,
  },
  tile: {
    width: '31%',
    flexGrow: 1,
    minWidth: '30%',
    maxWidth: '32%',
    borderRadius: 16,
    borderWidth: 1,
    borderColor: colors.glassBorder,
    backgroundColor: colors.glass,
    paddingVertical: 14,
    alignItems: 'center',
    gap: 6,
  },
  tileIcon: { fontSize: 22 },
  tileLabel: { color: colors.whiteMuted, fontSize: 12 },
  quickCard: {
    marginTop: 16,
    marginHorizontal: 16,
    borderRadius: 20,
    borderWidth: 1,
    borderColor: colors.glassBorder,
    backgroundColor: colors.glass,
    paddingHorizontal: 14,
    paddingTop: 14,
    paddingBottom: 4,
  },
  quickTitle: {
    color: colors.white,
    fontWeight: '700',
    marginBottom: 6,
  },
  quickRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 14,
  },
  quickBorder: {
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: 'rgba(255,255,255,0.12)',
  },
  quickText: { flex: 1, color: colors.whiteMuted },
  chev: { color: colors.cyanBright, fontSize: 22 },
  tab: {
    position: 'absolute',
    left: 16,
    right: 16,
    bottom: 18,
    height: 64,
    borderRadius: 28,
    backgroundColor: 'rgba(6,12,24,0.92)',
    borderWidth: 1,
    borderColor: colors.glassBorder,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-around',
    paddingHorizontal: 8,
  },
  tabItem: {
    width: 48,
    height: 40,
    borderRadius: 20,
    alignItems: 'center',
    justifyContent: 'center',
  },
  tabOn: { backgroundColor: 'rgba(0,180,255,0.2)' },
  tabIcon: { fontSize: 18, color: colors.white },
});
