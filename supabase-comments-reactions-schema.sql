-- ==============================================================================
-- Schema for Comments, Reviews, Replies & Reactions for Blogs and Articles
-- ==============================================================================

-- 1. Comments & Reviews Table
create table if not exists public.post_comments (
  id uuid primary key default gen_random_uuid(),
  post_type text not null check (post_type in ('blog', 'article')),
  post_id uuid not null,
  parent_id uuid references public.post_comments(id) on delete cascade,
  author_name text not null,
  author_email text,
  content text not null,
  rating integer check (rating is null or (rating >= 1 and rating <= 5)),
  is_admin boolean not null default false,
  status text not null default 'approved' check (status in ('approved', 'pending', 'spam')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Indexes for post_comments performance
create index if not exists post_comments_lookup_idx
  on public.post_comments (post_type, post_id, created_at desc);

create index if not exists post_comments_parent_idx
  on public.post_comments (parent_id);

-- 2. Reactions Table
create table if not exists public.post_reactions (
  id uuid primary key default gen_random_uuid(),
  post_type text not null check (post_type in ('blog', 'article')),
  post_id uuid not null,
  reaction_type text not null check (reaction_type in ('like', 'love', 'clap', 'fire', 'insightful')),
  visitor_id text not null,
  created_at timestamptz not null default now(),
  unique (post_type, post_id, visitor_id, reaction_type)
);

-- Indexes for post_reactions performance
create index if not exists post_reactions_lookup_idx
  on public.post_reactions (post_type, post_id);

create index if not exists post_reactions_visitor_idx
  on public.post_reactions (visitor_id);

-- 3. Automatic updated_at trigger for post_comments
create or replace function public.set_post_comments_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists set_post_comments_updated_at on public.post_comments;
create trigger set_post_comments_updated_at
before update on public.post_comments
for each row
execute function public.set_post_comments_updated_at();

-- 4. Enable Row Level Security (RLS)
alter table public.post_comments enable row level security;
alter table public.post_reactions enable row level security;

-- 5. Policies for post_comments
drop policy if exists "Anyone can read approved comments" on public.post_comments;
create policy "Anyone can read approved comments"
  on public.post_comments for select
  using (status = 'approved' or auth.role() = 'authenticated');

drop policy if exists "Anyone can insert comments" on public.post_comments;
create policy "Anyone can insert comments"
  on public.post_comments for insert
  with check (
    (auth.role() = 'authenticated') or (is_admin = false or is_admin is null)
  );

drop policy if exists "Authenticated users can update comments" on public.post_comments;
create policy "Authenticated users can update comments"
  on public.post_comments for update
  using (auth.role() = 'authenticated');

drop policy if exists "Authenticated users can delete comments" on public.post_comments;
create policy "Authenticated users can delete comments"
  on public.post_comments for delete
  using (auth.role() = 'authenticated');

-- 6. Policies for post_reactions
drop policy if exists "Anyone can view reactions" on public.post_reactions;
create policy "Anyone can view reactions"
  on public.post_reactions for select
  using (true);

drop policy if exists "Anyone can insert reactions" on public.post_reactions;
create policy "Anyone can insert reactions"
  on public.post_reactions for insert
  with check (true);

drop policy if exists "Anyone can delete reactions" on public.post_reactions;
create policy "Anyone can delete reactions"
  on public.post_reactions for delete
  using (true);

-- 7. Realtime Support
-- Add tables to realtime publication if not already present
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'post_comments'
  ) then
    alter publication supabase_realtime add table public.post_comments;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'post_reactions'
  ) then
    alter publication supabase_realtime add table public.post_reactions;
  end if;
end;
$$;
