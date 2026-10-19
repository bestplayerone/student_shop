-- Repeatable seed matching the assignment catalog and original image URLs.
insert into public.products (id, name, price, image_url) values
  (1, 'Mechanical Gaming Keyboard', 1500.00, 'https://images.unsplash.com/photo-1595225476474-87563907a212?w=300'),
  (2, 'Wireless Ergonomic Mouse', 850.00, 'https://images.unsplash.com/photo-1527864550417-7fd91fc51a46?w=300'),
  (3, 'USB-C Hub Multiport Adapter', 600.00, 'https://images.unsplash.com/photo-1625842268584-8f3296236761?w=300')
on conflict (id) do update set
  name = excluded.name,
  price = excluded.price,
  image_url = excluded.image_url;

select setval(pg_get_serial_sequence('public.products', 'id'),
  greatest((select coalesce(max(id), 1) from public.products), 1), true);
