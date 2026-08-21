-- Force Row Level Security so table owners (including privileged DB roles)
-- cannot bypass RLS unless using service_role intentionally via API.

ALTER TABLE public.profiles FORCE ROW LEVEL SECURITY;
ALTER TABLE public.emergency_contacts FORCE ROW LEVEL SECURITY;
ALTER TABLE public.favorite_objects FORCE ROW LEVEL SECURITY;
ALTER TABLE public.detection_history FORCE ROW LEVEL SECURITY;
ALTER TABLE public.voice_history FORCE ROW LEVEL SECURITY;
ALTER TABLE public.locations FORCE ROW LEVEL SECURITY;
ALTER TABLE public.settings FORCE ROW LEVEL SECURITY;
ALTER TABLE public.orders FORCE ROW LEVEL SECURITY;

-- Allow users to delete their own settings row if needed
CREATE POLICY "Users can delete own settings"
  ON public.settings FOR DELETE
  USING (auth.uid() = user_id);
