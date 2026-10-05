-- 1. Add audio_url column to blog_posts if it doesn't exist
ALTER TABLE public.blog_posts ADD COLUMN IF NOT EXISTS audio_url text;

-- 2. Enable Row Level Security (RLS)
ALTER TABLE public.blog_posts ENABLE ROW LEVEL SECURITY;

-- 3. Create policies
-- Allow public to read published posts
CREATE POLICY "Public can view published blog posts"
ON public.blog_posts
FOR SELECT
USING (published = true);

-- Allow authenticated users (admin) to read all posts
CREATE POLICY "Authenticated users can view all blog posts"
ON public.blog_posts
FOR SELECT
TO authenticated
USING (true);

-- Allow authenticated users (admin) to insert posts
CREATE POLICY "Authenticated users can insert blog posts"
ON public.blog_posts
FOR INSERT
TO authenticated
WITH CHECK (true);

-- Allow authenticated users (admin) to update posts
CREATE POLICY "Authenticated users can update blog posts"
ON public.blog_posts
FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);

-- Allow authenticated users (admin) to delete posts
CREATE POLICY "Authenticated users can delete blog posts"
ON public.blog_posts
FOR DELETE
TO authenticated
USING (true);
