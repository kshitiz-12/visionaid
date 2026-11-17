import React, { useEffect, useState } from 'react';
import { Pressable, StyleSheet, Text, TextInput, View } from 'react-native';
import { NativeStackScreenProps } from '@react-navigation/native-stack';
import { GlowButton } from '../components/GlowButton';
import { Starfield } from '../components/Starfield';
import { getBaseUrl, health, setBaseUrl } from '../api';
import { RootStackParamList } from '../navigation/types';
import { colors } from '../theme';

type Props = NativeStackScreenProps<RootStackParamList, 'Settings'>;

export function SettingsScreen({ navigation }: Props) {
  const [url, setUrl] = useState('');
  const [status, setStatus] = useState('…');

  useEffect(() => {
    getBaseUrl().then(setUrl);
  }, []);

  const save = async () => {
    await setBaseUrl(url.trim());
    try {
      const h = await health();
      setStatus(h.ok ? 'Backend online ✓' : 'Backend replied but not ok');
    } catch {
      setStatus('Cannot reach backend');
    }
  };

  return (
    <View style={styles.root}>
      <Starfield />
      <View style={styles.top}>
        <Pressable onPress={() => navigation.goBack()}>
          <Text style={styles.back}>‹</Text>
        </Pressable>
        <Text style={styles.logo}>Settings</Text>
        <View style={{ width: 28 }} />
      </View>
      <Text style={styles.label}>Backend API URL</Text>
      <TextInput
        value={url}
        onChangeText={setUrl}
        autoCapitalize="none"
        autoCorrect={false}
        style={styles.input}
        placeholderTextColor={colors.whiteFaint}
        placeholder="http://192.168.x.x:8787"
      />
      <Text style={styles.hint}>
        Phone: use your PC LAN IP. Emulator: http://10.0.2.2:8787
      </Text>
      <GlowButton label="Save & Test" onPress={save} style={{ marginTop: 16 }} />
      <Text style={styles.status}>{status}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: colors.bgDeep, paddingHorizontal: 18 },
  top: {
    paddingTop: 52,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 24,
  },
  back: { color: colors.white, fontSize: 34 },
  logo: { color: colors.white, fontSize: 18, fontWeight: '700' },
  label: { color: colors.whiteMuted, marginBottom: 8 },
  input: {
    borderRadius: 14,
    borderWidth: 1,
    borderColor: colors.glassBorder,
    backgroundColor: colors.glass,
    color: colors.white,
    padding: 14,
  },
  hint: { color: colors.whiteFaint, marginTop: 8, fontSize: 12 },
  status: { color: colors.cyanBright, marginTop: 18, textAlign: 'center' },
});
