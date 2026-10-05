create table if not exists public.blog_posts (
  id uuid primary key default gen_random_uuid(),
  slug text unique,
  title text not null,
  excerpt text,
  content text,
  cover_image_url text,
  author text default 'Olimjon Makhmudov',
  tags text[] default '{}',
  published boolean default false,
  published_at timestamptz,
  updated_at timestamptz default now(),
  created_at timestamptz default now(),
  read_minutes integer
);

create unique index if not exists blog_posts_slug_key
  on public.blog_posts (slug)
  where slug is not null;

create or replace function public.set_blog_posts_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists set_blog_posts_updated_at on public.blog_posts;

create trigger set_blog_posts_updated_at
before update on public.blog_posts
for each row
execute function public.set_blog_posts_updated_at();
