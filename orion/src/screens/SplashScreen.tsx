import React, { useEffect } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import Animated, {
  Easing,
  useAnimatedStyle,
  useSharedValue,
  withDelay,
  withTiming,
} from 'react-native-reanimated';
import { NativeStackScreenProps } from '@react-navigation/native-stack';
import { BlackHole } from '../components/BlackHole';
import { Starfield } from '../components/Starfield';
import { RootStackParamList } from '../navigation/types';
import { colors } from '../theme';
import { startBrowser } from '../api';

type Props = NativeStackScreenProps<RootStackParamList, 'Splash'>;

export function SplashScreen({ navigation }: Props) {
  const progress = useSharedValue(0.08);
  const fade = useSharedValue(0);
  const rise = useSharedValue(18);

  useEffect(() => {
    fade.value = withTiming(1, { duration: 900 });
    rise.value = withTiming(0, { duration: 900, easing: Easing.out(Easing.cubic) });
    progress.value = withDelay(
      200,
      withTiming(1, { duration: 2400, easing: Easing.inOut(Easing.quad) }),
    );
    startBrowser().catch(() => {});
    const t = setTimeout(() => navigation.replace('Onboarding'), 2800);
    return () => clearTimeout(t);
  }, [fade, navigation, progress, rise]);

  const textStyle = useAnimatedStyle(() => ({
    opacity: fade.value,
    transform: [{ translateY: rise.value }],
  }));
  const barStyle = useAnimatedStyle(() => ({
    transform: [{ scaleX: progress.value }],
  }));

  return (
    <View style={styles.root}>
      <Starfield />
      <View style={styles.center}>
        <BlackHole size={300} intensity="splash" />
      </View>
      <Animated.View style={[styles.brand, textStyle]}>
        <Text style={styles.title}>
          ORI
          <Text style={styles.oGlow}>O</Text>
          N
        </Text>
        <Text style={styles.tag}>Your Personal AI Assistant</Text>
        <View style={styles.track}>
          <Animated.View style={[styles.fillWrap, barStyle]}>
            <View style={styles.fill} />
          </Animated.View>
        </View>
      </Animated.View>
    </View>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: colors.bgDeep },
  center: { flex: 1.15, alignItems: 'center', justifyContent: 'center' },
  brand: { flex: 0.7, alignItems: 'center', paddingBottom: 48 },
  title: {
    color: colors.white,
    fontSize: 42,
    fontWeight: '700',
    letterSpacing: 8,
  },
  oGlow: {
    color: colors.white,
    textShadowColor: colors.cyanBright,
    textShadowRadius: 16,
    textShadowOffset: { width: 0, height: 0 },
  },
  tag: {
    marginTop: 10,
    color: colors.whiteMuted,
    fontSize: 15,
    letterSpacing: 0.4,
  },
  track: {
    marginTop: 28,
    width: 180,
    height: 5,
    borderRadius: 4,
    backgroundColor: 'rgba(255,255,255,0.12)',
    overflow: 'hidden',
  },
  fillWrap: {
    height: '100%',
    width: '100%',
    alignSelf: 'flex-start',
  },
  fill: {
    height: '100%',
    width: '100%',
    borderRadius: 4,
    backgroundColor: colors.cyanBright,
  },
});
