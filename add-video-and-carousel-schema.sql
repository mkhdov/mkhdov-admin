-- 1. Add video_url and image_urls columns to blog_posts if they don't exist
ALTER TABLE public.blog_posts ADD COLUMN IF NOT EXISTS video_url text;
ALTER TABLE public.blog_posts ADD COLUMN IF NOT EXISTS image_urls text[] DEFAULT '{}';

-- 2. Backfill existing cover_image_url into image_urls for existing posts
UPDATE public.blog_posts
SET image_urls = ARRAY[cover_image_url]
WHERE (image_urls IS NULL OR cardinality(image_urls) = 0)
  AND cover_image_url IS NOT NULL
  AND cover_image_url != '';
