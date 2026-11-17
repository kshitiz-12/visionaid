import React, { useEffect } from 'react';
import { StyleSheet, View } from 'react-native';
import Animated, {
  Easing,
  useAnimatedStyle,
  useSharedValue,
  withRepeat,
  withTiming,
} from 'react-native-reanimated';
import Svg, { Circle, Defs, RadialGradient, Stop, G, Ellipse } from 'react-native-svg';
import { colors } from '../theme';

type Props = {
  size?: number;
  intensity?: 'splash' | 'hero' | 'listen' | 'process' | 'mini';
};

export function BlackHole({ size = 260, intensity = 'hero' }: Props) {
  const spin = useSharedValue(0);
  const spinSlow = useSharedValue(0);
  const pulse = useSharedValue(1);

  useEffect(() => {
    spin.value = withRepeat(
      withTiming(360, { duration: 14000, easing: Easing.linear }),
      -1,
      false,
    );
    spinSlow.value = withRepeat(
      withTiming(-360, { duration: 22000, easing: Easing.linear }),
      -1,
      false,
    );
    pulse.value = withRepeat(
      withTiming(1.08, { duration: 2200, easing: Easing.inOut(Easing.sin) }),
      -1,
      true,
    );
  }, [pulse, spin, spinSlow]);

  const ringStyle = useAnimatedStyle(() => ({
    transform: [{ rotate: `${spin.value}deg` }, { scale: pulse.value }],
  }));
  const reverseStyle = useAnimatedStyle(() => ({
    transform: [{ rotate: `${spinSlow.value}deg` }],
  }));

  const core = size * 0.28;
  const showOrbit = intensity === 'listen' || intensity === 'process';

  return (
    <View style={[styles.wrap, { width: size, height: size }]}>
      <View
        style={[
          styles.glow,
          {
            width: size * 1.15,
            height: size * 1.15,
            borderRadius: size,
            backgroundColor:
              intensity === 'splash' ? 'rgba(0,120,255,0.22)' : 'rgba(0,160,255,0.18)',
          },
        ]}
      />
      <Animated.View style={[styles.layer, ringStyle]}>
        <Svg width={size} height={size}>
          <Defs>
            <RadialGradient id="disk" cx="50%" cy="50%" r="50%">
              <Stop offset="0%" stopColor="#000" stopOpacity="1" />
              <Stop offset="35%" stopColor="#001428" stopOpacity="1" />
              <Stop offset="55%" stopColor={colors.cyan} stopOpacity="0.95" />
              <Stop offset="78%" stopColor={colors.cyanBright} stopOpacity="0.55" />
              <Stop offset="100%" stopColor="#000" stopOpacity="0" />
            </RadialGradient>
          </Defs>
          <Ellipse
            cx={size / 2}
            cy={size / 2}
            rx={size * 0.46}
            ry={size * 0.32}
            fill="url(#disk)"
          />
          <Ellipse
            cx={size / 2}
            cy={size / 2}
            rx={size * 0.42}
            ry={size * 0.18}
            fill="none"
            stroke={colors.cyanBright}
            strokeWidth={2}
            strokeOpacity={0.85}
          />
          <Ellipse
            cx={size / 2}
            cy={size / 2}
            rx={size * 0.36}
            ry={size * 0.12}
            fill="none"
            stroke={colors.cyan}
            strokeWidth={1.5}
            strokeOpacity={0.5}
          />
        </Svg>
      </Animated.View>
      <Animated.View style={[styles.layer, reverseStyle]}>
        <Svg width={size} height={size}>
          <G>
            {Array.from({ length: 28 }).map((_, i) => {
              const a = (i / 28) * Math.PI * 2;
              const rx = size * 0.4;
              const ry = size * 0.22;
              const x = size / 2 + Math.cos(a) * rx;
              const y = size / 2 + Math.sin(a) * ry;
              return (
                <Circle
                  key={i}
                  cx={x}
                  cy={y}
                  r={i % 3 === 0 ? 1.8 : 1}
                  fill={colors.cyanBright}
                  opacity={0.35 + (i % 5) * 0.1}
                />
              );
            })}
          </G>
        </Svg>
      </Animated.View>
      {showOrbit ? (
        <Animated.View style={[styles.layer, reverseStyle]}>
          <Svg width={size} height={size}>
            <Circle
              cx={size / 2}
              cy={size / 2}
              r={size * 0.48}
              fill="none"
              stroke={colors.cyan}
              strokeWidth={1.5}
              strokeDasharray="4 8"
              strokeOpacity={0.7}
            />
          </Svg>
        </Animated.View>
      ) : null}
      <View
        style={[
          styles.core,
          {
            width: core,
            height: core,
            borderRadius: core / 2,
          },
        ]}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: {
    alignItems: 'center',
    justifyContent: 'center',
  },
  glow: {
    position: 'absolute',
  },
  layer: {
    ...StyleSheet.absoluteFill,
    alignItems: 'center',
    justifyContent: 'center',
  },
  core: {
    backgroundColor: '#000',
    borderWidth: 2,
    borderColor: 'rgba(0,180,255,0.35)',
    shadowColor: colors.cyan,
    shadowOpacity: 0.9,
    shadowRadius: 18,
  },
});
