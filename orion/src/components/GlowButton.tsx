import React, { useEffect } from 'react';
import { Pressable, StyleSheet, Text, ViewStyle } from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import Animated, {
  useAnimatedStyle,
  useSharedValue,
  withRepeat,
  withTiming,
} from 'react-native-reanimated';
import { colors } from '../theme';

type Props = {
  label: string;
  onPress: () => void;
  icon?: React.ReactNode;
  style?: ViewStyle;
  variant?: 'primary' | 'ghost';
};

export function GlowButton({
  label,
  onPress,
  icon,
  style,
  variant = 'primary',
}: Props) {
  const glow = useSharedValue(0.45);
  useEffect(() => {
    glow.value = withRepeat(withTiming(0.95, { duration: 1600 }), -1, true);
  }, [glow]);
  const aura = useAnimatedStyle(() => ({
    shadowOpacity: glow.value,
  }));

  if (variant === 'ghost') {
    return (
      <Pressable onPress={onPress} style={[styles.ghost, style]}>
        <Text style={styles.ghostText}>{label}</Text>
      </Pressable>
    );
  }

  return (
    <Animated.View style={[styles.aura, aura, style]}>
      <Pressable onPress={onPress}>
        <LinearGradient
          colors={['#0090E0', '#00C2FF', '#4DE2FF']}
          start={{ x: 0, y: 0.5 }}
          end={{ x: 1, y: 0.5 }}
          style={styles.btn}
        >
          {icon}
          <Text style={styles.label}>{label}</Text>
        </LinearGradient>
      </Pressable>
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  aura: {
    borderRadius: 28,
    shadowColor: colors.cyanBright,
    shadowRadius: 16,
    shadowOffset: { width: 0, height: 0 },
  },
  btn: {
    minHeight: 54,
    borderRadius: 28,
    paddingHorizontal: 22,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 10,
  },
  label: {
    color: colors.white,
    fontSize: 17,
    fontWeight: '700',
    letterSpacing: 0.3,
  },
  ghost: {
    minHeight: 48,
    borderRadius: 28,
    borderWidth: 1.5,
    borderColor: colors.glassBorder,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: 'rgba(0,0,0,0.25)',
  },
  ghostText: {
    color: colors.whiteMuted,
    fontSize: 16,
    fontWeight: '600',
  },
});
