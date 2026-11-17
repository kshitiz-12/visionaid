import React, { useEffect, useMemo } from 'react';
import { Dimensions, StyleSheet, View } from 'react-native';
import Animated, {
  useAnimatedStyle,
  useSharedValue,
  withDelay,
  withRepeat,
  withTiming,
} from 'react-native-reanimated';
import { LinearGradient } from 'expo-linear-gradient';
import { colors } from '../theme';

const { width, height } = Dimensions.get('window');

function Twinkle({ x, y, s, d }: { x: number; y: number; s: number; d: number }) {
  const o = useSharedValue(0.2);
  useEffect(() => {
    o.value = withDelay(
      d,
      withRepeat(withTiming(1, { duration: 1400 + d }), -1, true),
    );
  }, [d, o]);
  const style = useAnimatedStyle(() => ({ opacity: o.value }));
  return (
    <Animated.View
      style={[
        styles.star,
        { left: x, top: y, width: s, height: s, borderRadius: s },
        style,
      ]}
    />
  );
}

export function Starfield({ planet = false }: { planet?: boolean }) {
  const stars = useMemo(
    () =>
      Array.from({ length: 42 }).map((_, i) => ({
        x: (i * 97) % width,
        y: (i * 53) % (height * 0.75),
        s: 1 + (i % 3),
        d: (i * 90) % 1800,
      })),
    [],
  );

  return (
    <View style={StyleSheet.absoluteFill} pointerEvents="none">
      <LinearGradient
        colors={['#000000', '#020814', '#00060f']}
        style={StyleSheet.absoluteFill}
      />
      {stars.map((st, i) => (
        <Twinkle key={i} {...st} />
      ))}
      {planet ? (
        <View style={styles.planetWrap}>
          <LinearGradient
            colors={['transparent', 'rgba(0,140,255,0.35)', 'rgba(0,80,160,0.55)']}
            style={styles.planet}
          />
        </View>
      ) : (
        <View style={styles.cornerGlow} />
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  star: {
    position: 'absolute',
    backgroundColor: colors.white,
  },
  cornerGlow: {
    position: 'absolute',
    right: -40,
    bottom: 80,
    width: 180,
    height: 180,
    borderRadius: 90,
    backgroundColor: 'rgba(0,140,255,0.12)',
  },
  planetWrap: {
    position: 'absolute',
    left: -width * 0.35,
    bottom: -height * 0.12,
    width: width * 1.4,
    height: height * 0.35,
    overflow: 'hidden',
  },
  planet: {
    flex: 1,
    borderTopLeftRadius: width,
    borderTopRightRadius: width,
  },
});
