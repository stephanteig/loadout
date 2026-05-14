insert into storage.buckets (id, name, public)
values ('gear-images', 'gear-images', true);

create policy "members can upload gear images" on storage.objects
  for insert with check (
    bucket_id = 'gear-images' and auth.uid() is not null
  );

create policy "public can view gear images" on storage.objects
  for select using (bucket_id = 'gear-images');

create policy "uploaders can delete own images" on storage.objects
  for delete using (
    bucket_id = 'gear-images' and owner = auth.uid()
  );
