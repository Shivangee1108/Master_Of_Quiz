-- Run this in your Supabase SQL Editor to set up the database schema

-- 1. Create a table for User Profiles
CREATE TABLE public.profiles (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT NOT NULL,
  role TEXT DEFAULT 'user'::text NOT NULL,
  profile_picture TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS for profiles
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Profiles Policies
CREATE POLICY "Public profiles are viewable by everyone." ON public.profiles FOR SELECT USING (true);
CREATE POLICY "Users can insert their own profile." ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "Users can update own profile." ON public.profiles FOR UPDATE USING (auth.uid() = id);


-- 2. Create a table for Quiz History
CREATE TABLE public.quiz_history (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  topic TEXT NOT NULL,
  difficulty TEXT NOT NULL,
  score INTEGER NOT NULL,
  total_questions INTEGER NOT NULL,
  correct_answers INTEGER NOT NULL,
  wrong_answers INTEGER NOT NULL,
  skipped INTEGER NOT NULL,
  time_taken INTEGER NOT NULL,
  date TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  questions JSONB NOT NULL,
  user_answers JSONB NOT NULL
);

-- Enable RLS for quiz history
ALTER TABLE public.quiz_history ENABLE ROW LEVEL SECURITY;

-- Quiz History Policies
CREATE POLICY "Users can view their own quiz history." ON public.quiz_history FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Admins can view all quiz history." ON public.quiz_history FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin')
);
CREATE POLICY "Users can insert their own quiz history." ON public.quiz_history FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete their own quiz history." ON public.quiz_history FOR DELETE USING (auth.uid() = user_id);


-- 3. Create a Storage Bucket for Avatars
INSERT INTO storage.buckets (id, name, public) VALUES ('avatars', 'avatars', true) ON CONFLICT DO NOTHING;

-- Storage Policies
CREATE POLICY "Avatar images are publicly accessible." ON storage.objects FOR SELECT USING (bucket_id = 'avatars');
CREATE POLICY "Users can upload their own avatars." ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);
CREATE POLICY "Users can update their own avatars." ON storage.objects FOR UPDATE USING (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);
CREATE POLICY "Users can delete their own avatars." ON storage.objects FOR DELETE USING (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);


-- Note: To make a user an admin, run:
-- UPDATE public.profiles SET role = 'admin' WHERE email = 'your_admin_email@example.com';

-- 4. Create an Auth Trigger to automatically create a profile for new users
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (
    id,
    name,
    email,
    role
  )
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'name',''),
    new.email,
    'user'
  );
  return new;
end;
$$;

-- Trigger the function every time a user is created
create trigger on_auth_user_created
after insert on auth.users
for each row
execute function public.handle_new_user();
