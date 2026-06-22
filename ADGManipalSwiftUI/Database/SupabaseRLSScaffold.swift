import Foundation

enum SupabaseRLSScaffold {
    static let sql = """
    -- Run in Supabase SQL editor after creating the project.
    create table if not exists public.announcements (
      id uuid primary key,
      title text not null,
      body text not null,
      poster_url text,
      is_pinned boolean not null default false,
      priority integer not null default 0,
      published_at timestamptz not null default now()
    );

    create table if not exists public.events (
      id uuid primary key,
      title text not null,
      summary text not null,
      venue text not null,
      starts_at timestamptz not null,
      capacity integer not null default 0,
      registered_count integer not null default 0,
      cover_image_url text,
      registration_method text not null check (registration_method in ('external_link', 'native_form')),
      registration_url text,
      registration_enabled boolean not null default true,
      required_fields jsonb not null default '{}'
    );

    create table if not exists public.registrations (
      id uuid primary key default gen_random_uuid(),
      event_id uuid not null references public.events(id) on delete cascade,
      user_id uuid references auth.users(id) on delete cascade,
      student_name text not null,
      email text not null,
      custom_inputs jsonb not null default '{}',
      created_at timestamptz not null default now(),
      unique (event_id, user_id)
    );

    create table if not exists public.board_members (
      id uuid primary key,
      name text not null,
      role text not null,
      domain text not null,
      bio text not null,
      headshot_url text,
      github_url text,
      linkedin_url text,
      sort_order integer not null default 0,
      board_year text not null default extract(year from now())::text,
      is_current boolean not null default true
    );

    create table if not exists public.layout_config (
      id uuid primary key,
      brand_title text not null,
      logo_url text
    );

    create table if not exists public.app_config (
      id text primary key,
      about_text text not null default ''
    );
    
    create table app_feedback (
      id uuid default gen_random_uuid() primary key,
      created_at timestamp with time zone default timezone('utc'::text, now()) not null,
      email text not null,
      message text not null,
      user_id uuid references auth.users(id) on delete set null
    );


    alter table public.announcements enable row level security;
    alter table public.events enable row level security;
    alter table public.registrations enable row level security;
    alter table public.board_members enable row level security;
    alter table public.layout_config enable row level security;
    alter table public.app_config enable row level security;

    create or replace function public.is_adg_admin()
    returns boolean
    language sql
    stable
    as $$
      select coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '') = 'admin'
        or coalesce((auth.jwt() -> 'app_metadata' ->> 'is_admin')::boolean, false)
        or coalesce(auth.jwt() -> 'user_metadata' ->> 'role', '') = 'admin'
        or coalesce((auth.jwt() -> 'user_metadata' ->> 'is_admin')::boolean, false);
    $$;

    create policy "Public read announcements" on public.announcements for select using (true);
    create policy "Public read events" on public.events for select using (true);
    create policy "Public read board members" on public.board_members for select using (true);
    create policy "Public read layout config" on public.layout_config for select using (true);
    create policy "Public read app config" on public.app_config for select using (true);

    create policy "Signed in students can register" on public.registrations
      for insert with check (auth.uid() = user_id);
    create policy "Students read own registrations" on public.registrations
      for select using (auth.uid() = user_id);
    create policy "Admins read registrations" on public.registrations for select using (public.is_adg_admin());

    create policy "Admins write announcements" on public.announcements for all using (public.is_adg_admin()) with check (public.is_adg_admin());
    create policy "Admins write events" on public.events for all using (public.is_adg_admin()) with check (public.is_adg_admin());
    create policy "Admins write board members" on public.board_members for all using (public.is_adg_admin()) with check (public.is_adg_admin());
    create policy "Admins write layout config" on public.layout_config for all using (public.is_adg_admin()) with check (public.is_adg_admin());
    create policy "Admins write app config" on public.app_config for all using (public.is_adg_admin()) with check (public.is_adg_admin());

    insert into public.app_config (id, about_text)
    values (
      'about_us',
      'Apple Developers Group is a student community at MIT Manipal focused on building thoughtful products, learning Apple technologies, and growing together through events, workshops, and projects.'
    )
    on conflict (id) do nothing;

    create or replace function public.sync_event_registered_count()
    returns trigger
    language plpgsql
    security definer
    set search_path = public
    as $$
    begin
      update public.events
      set registered_count = (
        select count(*)
        from public.registrations
        where event_id = coalesce(new.event_id, old.event_id)
      )
      where id = coalesce(new.event_id, old.event_id);

      return coalesce(new, old);
    end;
    $$;

    drop trigger if exists registrations_sync_event_count on public.registrations;
    create trigger registrations_sync_event_count
    after insert or delete on public.registrations
    for each row execute function public.sync_event_registered_count();

    insert into storage.buckets (id, name, public)
    values ('adg-assets', 'adg-assets', true)
    on conflict (id) do update set public = true;

    create policy "Public asset reads" on storage.objects for select
      using (bucket_id = 'adg-assets');

    create policy "Admins upload assets" on storage.objects for insert
      with check (bucket_id = 'adg-assets' and public.is_adg_admin());

    create policy "Admins update assets" on storage.objects for update
      using (bucket_id = 'adg-assets' and public.is_adg_admin())
      with check (bucket_id = 'adg-assets' and public.is_adg_admin());
    """
}
