export type RootStackParamList = {
  Splash: undefined;
  Onboarding: undefined;
  Home: undefined;
  Listening: undefined;
  Processing: { spoken: string };
  Action: {
    spoken: string;
    reply: string;
    pending?: Record<string, unknown> | null;
    intentType?: string;
  };
  Settings: undefined;
};
