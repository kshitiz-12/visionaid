import React, { useState } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { NativeStackScreenProps } from '@react-navigation/native-stack';
import { GlowButton } from '../components/GlowButton';
import { Starfield } from '../components/Starfield';
import { Waveform } from '../components/Waveform';
import { sendCommand } from '../api';
import { speak } from '../voice';
import { RootStackParamList } from '../navigation/types';
import { colors } from '../theme';

type Props = NativeStackScreenProps<RootStackParamList, 'Action'>;

export function ActionScreen({ navigation, route }: Props) {
  const { spoken, reply, pending, intentType } = route.params;
  const [busy, setBusy] = useState(false);
  const [status, setStatus] = useState(reply);

  const isWa =
    intentType?.includes('whatsapp') ||
    String(pending?.kind || '').includes('whatsapp') ||
    /whatsapp/i.test(spoken);

  const contact = String(
    (pending as { contact?: string; to?: string } | null)?.contact ||
      (pending as { to?: string } | null)?.to ||
      'Contact',
  );
  const body = String((pending as { body?: string } | null)?.body || '');

  const run = async (cmd: string) => {
    setBusy(true);
    try {
      const r = await sendCommand(cmd);
      setStatus(r.spoken);
      await speak(r.spoken);
      if (!r.pending) {
        // stay on screen with result
      }
    } finally {
      setBusy(false);
    }
  };

  return (
    <View style={styles.root}>
      <Starfield planet />
      <View style={styles.top}>
        <Pressable onPress={() => navigation.replace('Home')}>
          <Text style={styles.back}>‹</Text>
        </Pressable>
        <Text style={styles.logo}>O R I O N</Text>
        <View style={{ width: 28 }} />
      </View>

      <ScrollView contentContainerStyle={styles.scroll}>
        <View style={styles.userBubble}>
          <Text style={styles.mic}>🎙</Text>
          <Text style={styles.userText}>{spoken}</Text>
        </View>

        <View style={styles.aiRow}>
          <View style={styles.avatar} />
          <Text style={styles.aiText}>
            {pending ? 'Sure! Here’s your action:' : status}
          </Text>
        </View>

        {pending ? (
          <View style={styles.card}>
            <View style={styles.cardHead}>
              <Text style={styles.wa}>{isWa ? '🟢' : '✉️'}</Text>
              <View style={styles.avatarSm} />
              <Text style={styles.to}>To: {contact}</Text>
            </View>
            {body ? (
              <View style={styles.msgBox}>
                <Text style={styles.msg}>{body}</Text>
                <Text style={styles.edit}>✎</Text>
              </View>
            ) : (
              <Text style={styles.preview}>{status}</Text>
            )}
            <GlowButton
              label={busy ? 'Working…' : isWa ? 'Send Message' : 'Confirm'}
              onPress={() => !busy && run('confirm')}
              style={{ marginTop: 14 }}
            />
            <GlowButton
              label="Cancel"
              variant="ghost"
              onPress={() => !busy && run('cancel')}
              style={{ marginTop: 10 }}
            />
          </View>
        ) : (
          <View style={styles.resultCard}>
            <Text style={styles.result}>{status}</Text>
          </View>
        )}

        <Text style={styles.more}>Would you like to do anything else?</Text>
      </ScrollView>

      <Waveform bars={22} height={26} active={!busy} />
      <View style={styles.controls}>
        <Pressable style={styles.side} onPress={() => navigation.navigate('Listening')}>
          <Text>⌨</Text>
        </Pressable>
        <Pressable
          style={styles.main}
          onPress={() => navigation.navigate('Listening')}
        >
          <Text style={{ fontSize: 22 }}>🎙</Text>
        </Pressable>
        <Pressable style={styles.side} onPress={() => speak(status)}>
          <Text>🔊</Text>
        </Pressable>
      </View>
    </View>
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
  back: { color: colors.white, fontSize: 34 },
  logo: { color: colors.white, letterSpacing: 8, fontWeight: '600' },
  scroll: { padding: 16, paddingBottom: 20 },
  userBubble: {
    alignSelf: 'stretch',
    flexDirection: 'row',
    gap: 8,
    borderRadius: 22,
    backgroundColor: 'rgba(0,140,255,0.22)',
    borderWidth: 1,
    borderColor: colors.glassBorder,
    padding: 12,
  },
  mic: { fontSize: 16 },
  userText: { flex: 1, color: colors.white, fontSize: 14, lineHeight: 20 },
  aiRow: { flexDirection: 'row', gap: 10, marginTop: 16, alignItems: 'center' },
  avatar: {
    width: 34,
    height: 34,
    borderRadius: 17,
    backgroundColor: colors.cyanDim,
    borderWidth: 1,
    borderColor: colors.cyan,
  },
  aiText: { flex: 1, color: colors.white, fontSize: 15 },
  card: {
    marginTop: 14,
    borderRadius: 22,
    borderWidth: 1,
    borderColor: colors.glassBorder,
    backgroundColor: colors.glass,
    padding: 14,
  },
  cardHead: { flexDirection: 'row', alignItems: 'center', gap: 8 },
  wa: { fontSize: 18 },
  avatarSm: {
    width: 28,
    height: 28,
    borderRadius: 14,
    backgroundColor: '#334',
  },
  to: { color: colors.white, fontWeight: '600' },
  msgBox: {
    marginTop: 12,
    borderRadius: 14,
    backgroundColor: 'rgba(0,0,0,0.35)',
    padding: 12,
    flexDirection: 'row',
    alignItems: 'center',
  },
  msg: { flex: 1, color: colors.white },
  edit: { color: colors.whiteFaint },
  preview: { marginTop: 10, color: colors.whiteMuted, lineHeight: 20 },
  resultCard: {
    marginTop: 14,
    borderRadius: 18,
    borderWidth: 1,
    borderColor: colors.glassBorder,
    backgroundColor: colors.glass,
    padding: 14,
  },
  result: { color: colors.white, lineHeight: 22 },
  more: {
    marginTop: 18,
    color: colors.whiteMuted,
    textAlign: 'center',
  },
  controls: {
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
    gap: 28,
    paddingBottom: 28,
    paddingTop: 8,
  },
  side: {
    width: 48,
    height: 48,
    borderRadius: 24,
    borderWidth: 1,
    borderColor: colors.glassBorder,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: colors.glass,
  },
  main: {
    width: 72,
    height: 72,
    borderRadius: 36,
    backgroundColor: colors.cyan,
    alignItems: 'center',
    justifyContent: 'center',
    shadowColor: colors.cyanBright,
    shadowOpacity: 0.85,
    shadowRadius: 16,
  },
});
