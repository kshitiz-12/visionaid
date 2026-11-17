import React, { useEffect } from 'react';
import { StyleSheet, View } from 'react-native';
import Animated, {
  Easing,
  useAnimatedStyle,
  useSharedValue,
  withDelay,
  withRepeat,
  withTiming,
} from 'react-native-reanimated';
import { colors } from '../theme';

type Props = {
  bars?: number;
  height?: number;
  active?: boolean;
  width?: number;
};

function Bar({
  delay,
  maxH,
  active,
}: {
  delay: number;
  maxH: number;
  active: boolean;
}) {
  const h = useSharedValue(6);
  useEffect(() => {
    if (!active) {
      h.value = withTiming(6, { duration: 200 });
      return;
    }
    h.value = withDelay(
      delay,
      withRepeat(
        withTiming(maxH, {
          duration: 320 + (delay % 180),
          easing: Easing.inOut(Easing.quad),
        }),
        -1,
        true,
      ),
    );
  }, [active, delay, h, maxH]);

  const style = useAnimatedStyle(() => ({
    height: h.value,
  }));

  return <Animated.View style={[styles.bar, style]} />;
}

export function Waveform({ bars = 28, height = 36, active = true, width }: Props) {
  return (
    <View style={[styles.row, { height, width }]}>
      {Array.from({ length: bars }).map((_, i) => (
        <Bar
          key={i}
          delay={i * 28}
          maxH={8 + ((i * 17) % (height - 4))}
          active={active}
        />
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 3,
  },
  bar: {
    width: 3,
    borderRadius: 2,
    backgroundColor: colors.cyanBright,
    shadowColor: colors.cyan,
    shadowOpacity: 0.8,
    shadowRadius: 4,
  },
});
