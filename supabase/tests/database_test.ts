import pg from "pg";
import { assert, equal, rejects } from "./assert.ts";

const url = Deno.env.get("BACKEND_TEST_DATABASE_URL");
if (!url || !/^postgresql:\/\/[^@]+@127\.0\.0\.1:\d+\/bmc_test$/.test(url)) {
  throw new Error("Use run_db_tests.py: tests require its disposable loopback database");
}

async function connect() {
  const client = new pg.Client({ connectionString: url });
  await client.connect();
  return client;
}

const admin = new pg.Client({ connectionString: url.replace(/\/bmc_test$/, "/postgres") });
await admin.connect();
try {
  await admin.query("create database bmc_test");
} finally {
  await admin.end();
}
const bootstrap = await connect();
try {
  // Minimal local Auth contract for vanilla PostgreSQL, NOT a replacement for GoTrue.
  await bootstrap.query(`
    create role anon nologin;
    create role authenticated nologin;
    create role service_role nologin bypassrls;
    create schema auth;
    create table auth.users (id uuid primary key);
    create function auth.uid() returns uuid language sql stable as $$
      select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
    $$;
    grant usage on schema auth to anon, authenticated, service_role;
    grant execute on function auth.uid() to anon, authenticated, service_role;
    -- Reproduce permissive hosted defaults, so missing REVOKEs are caught.
    alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
    alter default privileges in schema public grant all on sequences to anon, authenticated, service_role;
    insert into auth.users values ('11111111-1111-4111-8111-111111111111'), ('22222222-2222-4222-8222-222222222222');
  `);
  const migrations: string[] = [];
  try {
    for await (const entry of Deno.readDir("migrations")) {
      if (entry.name.endsWith(".sql")) migrations.push(entry.name);
    }
  } catch (error) {
    if (!(error instanceof Deno.errors.NotFound)) throw error;
  }
  for (const migration of migrations.sort()) {
    await bootstrap.query(await Deno.readTextFile(`migrations/${migration}`));
  }
  try {
    await bootstrap.query(await Deno.readTextFile("seed.sql"));
  } catch (error) {
    if (!(error instanceof Deno.errors.NotFound)) throw error;
  }
} finally {
  await bootstrap.end();
}

Deno.test("schema: catalog and order tables exist with the three assignment products", async () => {
  const db = await connect();
  try {
    const tables = await db.query(
      "select to_regclass('public.products') as products, to_regclass('public.orders') as orders",
    );
    assert(tables.rows[0].products, "Missing products table");
    assert(tables.rows[0].orders, "Missing orders table");
    const products = await db.query(
      "select id::int, name, price::int from public.products order by id",
    );
    equal(products.rows, [
      { id: 1, name: "Mechanical Gaming Keyboard", price: 1500 },
      { id: 2, name: "Wireless Ergonomic Mouse", price: 850 },
      { id: 3, name: "USB-C Hub Multiport Adapter", price: 600 },
    ]);
  } finally {
    await db.end();
  }
});

Deno.test("catalog seed: original image URLs survive repeatable seeding", async () => {
  const db = await connect();
  try {
    await db.query(await Deno.readTextFile("seed.sql"));
    equal(
      (await db.query("select image_url from products order by id")).rows.map((
        r: { image_url: string },
      ) => r.image_url),
      [
        "https://images.unsplash.com/photo-1595225476474-87563907a212?w=300",
        "https://images.unsplash.com/photo-1527864550417-7fd91fc51a46?w=300",
        "https://images.unsplash.com/photo-1625842268584-8f3296236761?w=300",
      ],
    );
  } finally {
    await db.end();
  }
});

const USER = "11111111-1111-4111-8111-111111111111";
Deno.test("orders: service reservation snapshots database price, rejects unknown products, is not client-callable", async () => {
  const db = await connect();
  try {
    await db.query("set role service_role");
    const result = await db.query(
      "select * from public.create_checkout_order($1,1,'reserve-test')",
      [USER],
    );
    const order = result.rows[0];
    equal([
      order.user_id,
      order.product_id,
      order.product_name,
      order.amount,
      order.currency,
      order.status,
    ], [USER, "1", "Mechanical Gaming Keyboard", "1500.00", "PHP", "PENDING"]);
    equal([order.xendit_invoice_id, order.invoice_url, order.paid_at], [null, null, null]);
    await rejects(
      () => db.query("select * from public.create_checkout_order($1,999,'unknown-test')", [USER]),
      /PRODUCT_NOT_FOUND/,
    );
    await rejects(
      () => db.query("select * from public.create_checkout_order($1,1,'reserve-test')", [USER]),
      /duplicate key/,
    );
  } finally {
    await db.end();
  }
  for (const role of ["anon", "authenticated"] as const) {
    await rejects(
      () => asRole(role, USER, `select * from public.create_checkout_order('${USER}',1,'forged')`),
      /permission denied/,
    );
  }
});

const OTHER = "22222222-2222-4222-8222-222222222222";

Deno.test("webhook: validates invoice, amount, and currency atomically; PAID is idempotent", async () => {
  const db = await connect();
  try {
    await db.query("set role service_role");
    await db.query("select * from public.create_checkout_order($1,1,'webhook-test')", [USER]);
    await db.query(
      "update public.orders set xendit_invoice_id='inv-webhook-test', invoice_url='https://checkout.xendit.co/web/test' where external_id='webhook-test'",
    );
    const mismatchResults = await db.query(`
      select public.apply_xendit_invoice_event('webhook-test','wrong-invoice','PAID',1500,'PHP') as result
      union all select public.apply_xendit_invoice_event('webhook-test','inv-webhook-test','PAID',1,'PHP')
      union all select public.apply_xendit_invoice_event('webhook-test','inv-webhook-test','PAID',1500,'USD')
    `);
    equal(mismatchResults.rows.map((r: { result: string }) => r.result), [
      "invoice_mismatch",
      "amount_mismatch",
      "currency_mismatch",
    ]);
    equal(
      (await db.query("select status, paid_at from public.orders where external_id='webhook-test'"))
        .rows,
      [{ status: "PENDING", paid_at: null }],
    );
    const paid = await db.query(
      "select public.apply_xendit_invoice_event('webhook-test','inv-webhook-test','PAID',1500,'PHP') as result",
    );
    equal(paid.rows[0].result, "updated");
    const duplicatePaid = await db.query(
      "select public.apply_xendit_invoice_event('webhook-test','inv-webhook-test','PAID',1500,'PHP') as result",
    );
    equal(duplicatePaid.rows[0].result, "already_applied");
    const lateExpired = await db.query(
      "select public.apply_xendit_invoice_event('webhook-test','inv-webhook-test','EXPIRED',1500,'PHP') as result",
    );
    equal(lateExpired.rows[0].result, "already_applied");
    const final = await db.query(
      "select status, paid_at is not null as has_paid_at from public.orders where external_id='webhook-test'",
    );
    equal(final.rows, [{ status: "PAID", has_paid_at: true }]);
  } finally {
    await db.end();
  }
  for (const role of ["anon", "authenticated"] as const) {
    await rejects(
      () =>
        asRole(
          role,
          USER,
          `select public.apply_xendit_invoice_event('webhook-test','inv-webhook-test','PAID',1500,'PHP')`,
        ),
      /permission denied/,
    );
  }
});

async function asRole(role: "anon" | "authenticated" | "service_role", user: string, sql: string) {
  const db = await connect();
  try {
    await db.query("begin");
    await db.query(`set local role ${role}`);
    await db.query("select set_config('request.jwt.claim.sub', $1, true)", [user]);
    return await db.query(sql);
  } finally {
    await db.query("rollback");
    await db.end();
  }
}

Deno.test("RLS: only public catalog reads and owner order reads are available to clients", async () => {
  const db = await connect();
  try {
    await db.query(
      `insert into public.orders(user_id,product_id,product_name,amount,external_id)
      values ($1,1,'Keyboard',1500,'rls-own'),($2,2,'Mouse',850,'rls-other')`,
      [USER, OTHER],
    );
  } finally {
    await db.end();
  }
  equal((await asRole("anon", "", "select id from products")).rowCount, 3);
  equal(
    (await asRole(
      "authenticated",
      USER,
      "select external_id from orders where external_id like 'rls-%'",
    )).rows,
    [{ external_id: "rls-own" }],
  );
  equal((await asRole("authenticated", "", "select id from orders")).rowCount, 0);
  await rejects(() => asRole("anon", "", "select * from orders"), /permission denied/);
  for (const role of ["anon", "authenticated"] as const) {
    for (
      const sql of [
        "insert into products(id,name,price) values(900,'Injected',1)",
        "update products set price=1 where id=1",
        "delete from products where id=3",
        `insert into orders(user_id,product_id,product_name,amount,external_id) values('${USER}',1,'Injected',1,'injected')`,
        "update orders set amount=1 where external_id='rls-own'",
        "delete from orders where external_id='rls-own'",
      ]
    ) await rejects(() => asRole(role, USER, sql), /permission denied/);
  }
  equal(
    (await asRole("service_role", "", "select id from orders where external_id like 'rls-%'"))
      .rowCount,
    2,
  );
});
