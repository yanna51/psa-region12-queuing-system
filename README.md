# PSAQ — PSA PhilSys Registration Center Queuing System

A capstone prototype for the Philippine Statistics Authority's PhilSys
Registration Center, City of Koronadal, South Cotabato: clients book a
transaction slot online, verify by email OTP, get a QR code, and are
called through a live queue that staff manage from a counter and the
public can watch on a lobby display (browser board or the Java desktop
client). Admin manages queue types, counters, capacity, daily business
hours, and reporting.

This is an academic demo/prototype — demo data only, not connected to
any real PSA/PhilSys production system.

## Requirements

- PHP 8.1+ (developed/tested on 8.4) with the `pdo_mysql`, `mbstring`,
  and `openssl` extensions (all standard in XAMPP).
- MySQL or MariaDB 10.4+.
- A standard local stack works out of the box — XAMPP, Laragon, MAMP,
  or `php -S` + a separately running MySQL/MariaDB all work; the
  instructions below use XAMPP-style paths since that's the most common
  capstone-defense setup, but nothing here is XAMPP-specific.
- Java 11+ only if you also want to run the desktop display client
  (`java-display/` — see its own README, entirely optional).

## Install

1. Copy this whole `psaq/` folder into your web root (e.g.
   `C:\xampp\htdocs\psaq` or `/opt/lampp/htdocs/psaq`).
2. Start Apache and MySQL/MariaDB.
3. Open phpMyAdmin (`http://localhost/phpmyadmin/`), click **Import**,
   choose `database.sql`, format = SQL, click **Go**. Do not pre-create
   a database — the file does that itself (`psaq_db`). You should end
   up with 20 tables, and demo rows in `roles`, `users`, `queue_types`,
   `service_counters`, `capacity_settings`, `queue_settings`, and
   `business_schedule`.
   - **Upgrading an existing PSAQ install?** Do not re-import the whole
     file — it starts with `DROP TABLE` on every table, which would
     wipe your real clients/appointments/queue data. Instead run only
     the block at the very end of `database.sql` headed
     **"EXISTING-INSTALL MIGRATION"** — select `psaq_db` in phpMyAdmin,
     open the SQL tab, paste from that heading to the end of the file,
     and click Go. It's idempotent (safe to run more than once) and
     never touches an existing `clients`/`appointments`/`queue_entries`
     row — see that block's own comments for exactly what it adds.
4. Check `config/config.php`: `BASE_URL` defaults to
   `http://localhost/psaq` — update it if you renamed or moved the
   project folder, or are deploying somewhere other than localhost.
5. Check `config/database.php` for the DB host/user/password if your
   MySQL root user has a password set (a stock fresh XAMPP install
   doesn't, so the default there usually works unchanged).
6. Visit `http://localhost/psaq/index.php`. You should see the PSAQ
   homepage.

### Default logins

| Role  | URL | Email | Password |
|---|---|---|---|
| Admin | `/admin/login.php` | `admin@psaq.local` | `Admin@123` |
| Staff | `/staff/login.php` | `staff@psaq.local` | `Staff@123` |

Change these before any real defense/demo where the link might be
shared — they're seeded in `database.sql`'s "DEMO ADMIN"/"DEMO STAFF"
sections.

### Email — read this before a live demo

`config/mail.php` ships with placeholder Gmail credentials
(`your-email@gmail.com` / `your-app-password`). **Every** outbound
email in the app — OTP codes, the "you're almost up" queue
notification, and the booking-confirmation + check-in QR email — goes
through `includes/mail-functions.php`'s real Gmail SMTP connection
(`send_gmail_email()` / `send_booking_confirmation_email()`, both via
PHPMailer). Nothing in this app uses PHP's `mail()` function anymore —
see the note below on why.

- **OTP codes** are additionally gated by `DEV_MODE` in
  `config/config.php` (`true` by default): in dev mode the OTP is also
  echoed directly on the verification page, so booking is fully
  testable even with the placeholder mail credentials still in place.
- With the placeholder credentials left in `config/mail.php`, every
  send call **fails closed**: it never throws, it just logs a `FAILED`
  row to the `notifications` table and returns `false` — but it also
  blocks on the SMTP connection attempt for its full timeout first
  (~10 seconds) before giving up. That means OTP verification and any
  other action that triggers one of these emails will visibly hang for
  about 10 seconds — this is expected, pre-existing behavior, not a
  bug, and disappears the moment you put real Gmail App Password
  credentials (https://myaccount.google.com/apppasswords) into
  `config/mail.php`.
- **Why not PHP's `mail()`?** It depends on the host having a
  configured local mail transfer agent. A stock XAMPP install doesn't
  have one (mail silently never arrives), and most shared hosts either
  disable it outright or throttle it hard enough that a real message
  can't be relied on — InfinityFree's own docs describe `mail()` as
  "severely restricted" with most messages rejected. Real SMTP through
  a Gmail account behaves identically everywhere this app runs, local
  or deployed, which is why every send in this app was unified onto
  that one path.
- **Real credentials in place but still nothing arrives?** Run
  `mail-test.php` at your site's root (e.g.
  `http://localhost/psaq/mail-test.php`) — it sends one real test email
  to your own `MAIL_USERNAME` and prints the full SMTP conversation on
  screen, so a failure shows its exact cause (bad auth, blocked
  connection, TLS/certificate problem) instead of just a generic
  `FAILED` row in the `notifications` table. **Delete it once you're
  done** — like any script exercising real credentials, it shouldn't
  stay live.

## Deploying to InfinityFree (or another shared host)

See **`DEPLOY_INFINITYFREE.md`** for a full step-by-step walkthrough
(account setup, database creation, file upload, and exactly which
three files need real values filled in). The short version of what
changed in this codebase to make that possible:

- **Session cookie path** (`config/config.php`) is now derived
  automatically from `BASE_URL` instead of being hardcoded to
  `/psaq/` — deploying at a host's document root (the common
  InfinityFree case) needs a `/` cookie path, and a hardcoded
  `/psaq/` would silently break every login with no visible error.
  Changing `BASE_URL` is the only thing needed; the cookie path
  follows automatically.
- **All outbound email** (OTP included, see above) now goes through
  real Gmail SMTP on **port 587 with STARTTLS** — InfinityFree (and
  many free hosts) block outbound ports 465 and 25 but allow 587.
- **`uploads/priority/.htaccess`** no longer uses `php_flag` — that
  directive only works under Apache's `mod_php`; most shared hosts,
  InfinityFree included, run PHP via FastCGI/CGI, where a `php_flag`
  line in `.htaccess` causes Apache to reject the whole file with a
  500 error. `Require all denied` alone already blocks all direct
  access to that folder regardless of PHP handler.
- No feature in this app relies on cron — every background-feeling
  behavior (auto-NO_SHOW timeouts, queue advancement) is
  "read-triggered": it runs opportunistically whenever a relevant page
  or API endpoint is next hit, not on a schedule. That matters because
  InfinityFree's free tier has had cron jobs disabled since August
  2023 — nothing here needed to change for that.

## What's in this delivery

Beyond the core booking/queue/admin system, this delivery adds:

- **HOLD status + per-day business schedule** — staff can put a WAITING
  client on hold and release them later without losing their place;
  admin sets each day of the week open/closed, its hours, and an
  optional break window and per-day appointment cap, from
  **Admin → Business Schedule**. This layers on top of the existing
  hourly capacity settings, it doesn't replace them — closing a day (or
  narrowing its hours) is enforced both when a client picks a time slot
  and again, server-side, at the moment they submit a booking.
  **Saturday and Sunday are closed by default** (`database.sql`'s
  seed data — a PSA registration center office isn't open weekends);
  admin can flip either back open any time from that same page, nothing
  else in the app hardcodes a 5-day week.
- **Call Timeout can be turned off** — **Admin → Settings → Grace
  Period → Call Timeout (seconds)** can now be left blank for "no
  limit," and ships that way by default: a CALLED client is never
  auto-marked NO_SHOW by this fast (seconds-scale) timer just for
  taking a while to reach the counter, and the on-screen countdown on
  staff/admin's queue pages shows "No limit" instead of ticking down.
  Grace Period (the slower, minutes-scale backstop) is unaffected and
  still applies either way; admin can put a number back in Call Timeout
  any time to re-enable the fast auto-advance.
- **Skip** (staff/service.php) — like "no-show" but re-queues the client
  as WAITING instead of ending their appointment, for "please step aside
  a moment, I'll call you again shortly."
- **English/Tagalog language switcher** — a session-wide switcher (top
  right of the public nav) for most client-facing pages, plus a
  separate, page-local switcher on the booking form itself that never
  reloads the page (so nothing typed so far is lost when switching).
- **Readability / senior-citizen-friendly pass, app-wide** — a larger
  default text size, thicker/more visible focus outlines, darker
  secondary/help text for stronger contrast, and roomier buttons and
  form fields (44px+ touch targets) on every page — public, the
  booking wizard, staff, and admin all share the same header/stylesheet,
  so this isn't a client-only skin. On top of that new default, an
  **A− / A+ text size control** next to the EN/FIL switcher (top right
  of every page) lets a client step the text up further still, in two
  steps, with the choice remembered for their next visit
  (`assets/js/app.js`, `includes/header.php`, `includes/navbar.php`).
- **Plain-language descriptions on the booking form's first step** — a
  short sentence under each of the four transaction cards (Regular
  Registration, Priority, Update, Claim) explaining what it's actually
  for, plus a line describing the rest of the booking flow, so a
  first-time client can tell which option matches what they came in to
  do without already knowing PhilSys terminology. Translated in both
  EN/FIL, same as the rest of that page.
- **Contact email + "Email Us" / QR** on the homepage — set the public
  contact address from **Admin → Settings**; the homepage shows a
  mailto: button and a scannable QR code encoding the same, so a client
  can reach the office with zero typing.
- **No QR of any kind on screen, ever** — the confirmation page shows
  a Print button for a clean paper record (masthead/nav/footer/buttons
  hidden), but no QR is rendered client-side anymore. A client's one
  real check-in QR only ever reaches them one way: emailed
  automatically, below.
- **Real booking-confirmation email, with the actual check-in QR
  embedded** — sent automatically the moment OTP verification succeeds
  (the appointment is "done"/CONFIRMED), by
  `includes/mail-functions.php`'s `send_booking_confirmation_email()`.
  This is now the *only* place the client's real check-in QR is ever
  sent — the confirmation page used to render it on screen (with a
  "Generate QR Code" fallback if the browser session was lost), and
  that whole card was removed, by request, in favor of always emailing
  it. The QR is generated **server-side**, entirely in PHP (no browser
  involved — see `vendor/qrcode-php/`, a small vendored,
  dependency-free QR encoder, since Composer/Packagist isn't reachable
  from this sandbox either), and embedded inline in an HTML email headed
  "Appointment Approved" with the ID/transaction/date/time/status laid
  out in a table. If that email never arrives (see the placeholder-Gmail
  caveat above), the client isn't stuck: their plain appointment code
  still shows as text on the confirmation page, and `staff/checkin.php`
  accepts a manually-typed appointment code just as well as a QR scan —
  check-in was never QR-only.
- **A public JSON API** (`api/queue-display.php`) with a stable,
  documented contract, extended so a completely separate desktop
  client can share the exact same live-queue data as the browser board
  with no risk of disagreeing.
- **A Java Swing desktop "Now Serving" display** — `java-display/`, a
  single-file, zero-dependency Java 11+ app for a lobby TV/monitor.
  See `java-display/README.md` for the full API contract it consumes
  and build/run instructions (`javac` + `java`, no Maven/Gradle).

## Project layout

```
psaq/
  admin/            Admin-only pages (require_login('admin'))
  staff/             Staff-only pages (require_login('staff'))
  client/           Public client-facing pages (booking, OTP, status, etc.)
  api/              JSON endpoints (public + authenticated)
  includes/          Shared PHP: auth, DB helpers, business logic, i18n
  includes/lang/     en.php / fil.php translation dictionaries
  assets/           CSS, JS, images, sounds, vendored client libraries
  assets/vendor/    Vendored client-side QR encoder (qrcode.js) — no CDN dependency
  vendor/phpmailer/  Vendored PHPMailer — no Composer required
  vendor/qrcode-php/ Vendored server-side QR encoder — no Composer required
  config/           config.php (app constants), database.php (PDO), mail.php
  uploads/priority/  Priority-eligibility proof uploads (access-controlled)
  java-display/      Standalone Java desktop display client (optional)
  database.sql       Full schema + demo seed data + upgrade migration block
```

No build step, no Composer, no npm — everything needed to run is
already vendored or is plain PHP/JS. `java-display/` is the one
sub-project with its own build step (`javac`), and it's entirely
optional — the browser-based `queue-display.php` needs nothing extra.
