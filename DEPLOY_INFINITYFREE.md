# Deploying PSAQ to InfinityFree

This is a step-by-step walkthrough for putting this project on
[InfinityFree](https://infinityfree.com/) (or another shared host with
similar constraints — cPanel-less, FastCGI/CGI PHP, no cron, MySQL via
a control panel). It assumes you already have the `psaq/` project
folder from this delivery and have run it locally at least once.

Three files need **real values only you can fill in** — your actual
domain, your actual database credentials, and a real Gmail account.
Nobody else can fill these in for you; the placeholders are there on
purpose so the app fails safely (never fatally) until you do.

---

## 1. Create your InfinityFree account and site

1. Sign up at infinityfree.com and create a new hosting account. You'll
   get a free subdomain like `yoursite.infinityfreeapp.com`, or you can
   attach a domain you already own.
2. Wait for the account to finish provisioning (usually a few minutes),
   then open its **Control Panel** (an app called Vista Panel / HFM).

## 2. Create the MySQL database

1. In the control panel, open **MySQL Databases**.
2. Create a new database — pick a short name, e.g. `psaq`. InfinityFree
   will prefix it automatically, producing something like
   `epiz_12345678_psaq` (older accounts) or `if0_12345678_psaq` (newer
   accounts). The database user is created with the same prefix, no
   suffix (e.g. `epiz_12345678`).
3. Set a password for that database user and **write down** all four
   values shown on that page:
   - **Hostname**, e.g. `sql200.infinityfree.com` (never `localhost`
     on InfinityFree — that's a XAMPP-only default).
   - **Database name**, e.g. `epiz_12345678_psaq`.
   - **Username**, e.g. `epiz_12345678`.
   - **Password** — whatever you set.
4. Open **phpMyAdmin** from the control panel (it links you in already
   authenticated to that database). Select your new database, click
   **Import**, choose `database.sql` from this project, and click
   **Go**. You should end up with 20 tables and demo rows in `roles`,
   `users`, `queue_types`, `service_counters`, `capacity_settings`,
   `queue_settings`, and `business_schedule` — same as a local install.

## 3. Set the PHP version

InfinityFree lets you pick a PHP version per account (control panel →
**PHP Version** / **Select PHP Version**). Pick **8.1 or newer** — this
app was developed and tested on 8.4, and InfinityFree has supported
8.3 since an April 2025 bulk upgrade. Don't leave it on an old default;
some accounts start on an older version until you explicitly change it.

## 4. Upload the files

Use the control panel's **File Manager**, or an FTP client (FileZilla
etc. — credentials are on the control panel's FTP Accounts page).

**If you're using the web File Manager to upload and extract the zip**,
you must be **inside the `htdocs` folder** before you upload it —
InfinityFree's File Manager refuses to extract a zip anywhere outside
`htdocs`, and its landing screen when you first open it is the account
root, one level *above* `htdocs`, not `htdocs` itself. If you extract
from that landing screen you'll get an error like "Extract path must
be within an htdocs folder for security reasons." To avoid it:

1. Open **File Manager**, then double-click into **`htdocs`** — check
   the path bar at the top now ends in `.../htdocs`.
2. Upload `psaq.zip` while you're inside that folder (not before).
3. Right-click the zip (still inside `htdocs`) and choose **Extract**.
   It should succeed now that both the zip and the extraction target
   are within `htdocs`.

(This restriction is specific to their web File Manager's Extract
button — an FTP client has no such restriction, since you upload
already-extracted files there and there's no separate extract step.)

This leaves you with `htdocs/psaq/...`. Two layouts from here, both
fine — just be consistent with the `BASE_URL` you set in step 5:

- **Keep it as `htdocs/psaq/`** if you're okay with the site living at
  `https://yoursite.infinityfreeapp.com/psaq/`. Nothing further to
  move.
- **Move it to the domain root** if you'd rather have
  `https://yoursite.infinityfreeapp.com/` with no `/psaq` in the URL:
  select everything *inside* `htdocs/psaq/`, cut, paste directly into
  `htdocs/`, then delete the now-empty `psaq` folder.

## 5. Edit the three config files

Edit these **after** uploading, directly in the File Manager's editor
(or edit locally and re-upload just these three files). All three live
in `config/`.

### `config/config.php` — your real URL

```php
define('BASE_URL', 'https://yoursite.infinityfreeapp.com');
// or, if you uploaded into a subfolder:
define('BASE_URL', 'https://yoursite.infinityfreeapp.com/psaq');
```

No trailing slash either way. This one line also fixes your session
cookie automatically — nothing else to change for that.

Also set:

```php
define('DEV_MODE', false);
```

before any real use — `DEV_MODE` echoes OTP codes directly on screen,
which is only meant for local testing with no mail server configured.

### `config/database.php` — your real DB credentials

Replace the four placeholder values with exactly what step 2 gave you:

```php
$host    = 'sql200.infinityfree.com';   // your real hostname
$dbName  = 'epiz_12345678_psaq';        // your real database name
$user    = 'epiz_12345678';             // your real username
$pass    = 'the password you set';      // your real password
```

Copy these **verbatim** from the control panel — don't guess the
numeric prefix, it's account-specific.

### `config/mail.php` — a real Gmail account

1. Turn on 2-Step Verification on a Gmail account (a dedicated one for
   the app is a good idea, not your personal inbox).
2. Generate an App Password: https://myaccount.google.com/apppasswords
   (this only appears once 2-Step Verification is on). Copy the
   16-character password it gives you.
3. Edit:

```php
define('MAIL_USERNAME', 'your-real-address@gmail.com');
define('MAIL_PASSWORD', 'the 16-character app password');
```

Leave `MAIL_HOST`, `MAIL_PORT` (587), and `MAIL_ENCRYPTION` (`'tls'`)
exactly as they are — InfinityFree blocks outbound SMTP on ports 465
and 25 but allows 587, which is also Gmail's own recommended port for
STARTTLS. `MAIL_FROM` doesn't need editing — it's defined from
`MAIL_USERNAME` automatically.

Until you fill in a real address and App Password, every outbound
email (OTP, queue notifications, booking confirmations) fails closed —
logged as `FAILED` in the `notifications` table, never a fatal error —
so the rest of the app keeps working, it just won't actually deliver
mail. See the README's "Email — read this before a live demo" section
for the ~10 second hang this causes on each attempt with placeholder
credentials still in place, and why.

## 6. Verify the GD extension

This app generates QR codes server-side with GD
(`vendor/qrcode-php/`). GD is enabled by default on InfinityFree, but
occasional accounts have reported missing PNG/JPEG support. To check,
create a throwaway file `gdcheck.php` in your document root with:

```php
<?php phpinfo();
```

Visit it in a browser, search the page for "GD Support", and confirm
PNG and JPEG both show as supported. **Delete this file immediately
after checking** — `phpinfo()` exposes server internals and must never
stay live. If GD or PNG support is missing, InfinityFree's support
channels can usually re-enable it per-account; QR generation is the
only feature that depends on it.

## 7. Visit the site and log in

Go to your `BASE_URL`. You should see the PSAQ homepage. Log in at
`/admin/login.php` with the demo admin (`admin@psaq.local` /
`Admin@123`) and `/staff/login.php` with the demo staff
(`staff@psaq.local` / `Staff@123`) — **change both passwords** (or
create new admin/staff users and remove the demo ones) before sharing
the link with anyone, since these credentials are public in
`database.sql`.

Do a full test booking end to end: book a slot, receive the OTP by
email (check spam on first send — new sending addresses sometimes land
there initially), verify it, and confirm the booking-confirmation
email with the embedded check-in QR arrives.

## Things that do NOT need to change

- **No cron setup.** InfinityFree's free tier has had cron disabled
  since August 2023. Nothing in this app needs it — auto-NO_SHOW
  timeouts and queue advancement are all "read-triggered": they run
  opportunistically whenever a relevant page or API endpoint is next
  hit, not on a schedule.
- **No `session.save_path` changes.** Custom session storage paths are
  often broken on shared hosting; this app never sets one, so it uses
  PHP's default session handling, which works fine on InfinityFree.
- **`.htaccess` / `mod_rewrite`** is enabled by default on InfinityFree
  — nothing to turn on.

## If something doesn't work

- **"Extract path must be within an htdocs folder for security
  reasons."** You tried to extract `psaq.zip` from the File Manager's
  account-root landing screen instead of from inside `htdocs`. See
  step 4 above — go into `htdocs` first, upload the zip there, then
  extract it.
- **Every page 500s immediately.** Check for a stray `php_flag` or
  `php_value` line in any `.htaccess` file — those cause a full parse
  error under InfinityFree's FastCGI/CGI PHP (unlike XAMPP's
  `mod_php`, where they're silently fine). This project's own
  `uploads/priority/.htaccess` was already fixed for this; check any
  `.htaccess` you've added yourself.
- **Login doesn't stick / immediately logs you out.** Almost always a
  `BASE_URL` mismatch — it must exactly match the URL you're actually
  visiting the site at (same scheme, same host, same path prefix if
  any). Re-check step 5.
- **Emails never arrive, and the notifications table shows FAILED.**
  Re-check `config/mail.php` for typos, confirm you generated an *App*
  Password (not your normal Gmail password), and confirm 2-Step
  Verification is actually on for that Google account — Gmail rejects
  SMTP auth without it. For the exact reason instead of a generic
  `FAILED`, run `mail-test.php` at your site's root — it sends one real
  test email and prints the full SMTP conversation on screen. Delete
  it once you're done, like the `gdcheck.php` file in step 6.
- **A page hangs for ~10 seconds on OTP verification or booking.**
  Expected if `config/mail.php` still has placeholder credentials —
  see the README's Email section. Fill in real credentials to remove
  the delay.
- **QR codes don't render (broken image / blank).** Check GD/PNG
  support per step 6.
