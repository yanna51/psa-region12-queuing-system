<?php
declare(strict_types=1);

require_once __DIR__ . '/includes/functions.php';
require_once __DIR__ . '/includes/i18n-functions.php';

// "Email Us" / "Scan QR Code" contact feature (§1 of the feature
// request) — admin-configurable address only (admin/settings.php's
// Contact group), never an SMTP credential: this builds a plain
// mailto: link the client's own device/mail app opens, so no message
// is ever sent server-side and no password is anywhere near the
// browser. The QR code (assets/vendor/qrcode.js, the same vendored
// dependency-free encoder client/confirmation.php already uses)
// encodes that identical mailto: link, so scanning it with a phone
// camera opens the exact same pre-filled email a click on the button
// would — one link, two ways to trigger it.
$contactEmail = get_setting('contact_email', 'psaqhelpdesk@gmail.com');
$mailSubject  = 'Appointment / Queue Inquiry';
$mailBody     = "Hello PSA PhilSys Registration Center,\n\n"
              . "I have a question regarding my appointment or queue status.\n\n"
              . "Appointment Reference (if any): \n"
              . "Full Name: \n\n"
              . "Message:\n\n\n"
              . "Thank you.";
$mailtoUrl    = 'mailto:' . $contactEmail . '?subject=' . rawurlencode($mailSubject) . '&body=' . rawurlencode($mailBody);

$pageTitle = 'Home';
require_once __DIR__ . '/includes/header.php';
require_once __DIR__ . '/includes/navbar.php';
?>
<main>
  <section class="psaq-hero text-center">
    <div class="container py-5">
      <div class="psaq-hero-seals">
        <img src="<?= BASE_URL ?>/assets/images/psa-logo.png" alt="Philippine Statistics Authority seal">
        <img src="<?= BASE_URL ?>/assets/images/bagong-pilipinas-logo.png" alt="Bagong Pilipinas emblem">
      </div>
      <p class="text-uppercase small fw-semibold text-white-50 mb-2">
        <?= e(t('home_agency_line')) ?>
      </p>
      <h1 class="display-5 fw-bold text-white mb-1">PSAQ</h1>
      <p class="lead text-white-75 mb-4"><?= e(t('home_tagline')) ?></p>

      <div class="d-flex flex-wrap justify-content-center gap-2">
        <a href="<?= BASE_URL ?>/client/booking.php" class="btn btn-light btn-lg">
          <i class="bi bi-calendar-plus"></i> <?= e(t('home_book_btn')) ?>
        </a>
        <a href="<?= BASE_URL ?>/client/check-status.php" class="btn btn-outline-light btn-lg">
          <i class="bi bi-search"></i> <?= e(t('home_check_btn')) ?>
        </a>
        <a href="<?= BASE_URL ?>/queue-display.php" class="btn btn-outline-light btn-lg">
          <i class="bi bi-display"></i> <?= e(t('home_queue_btn')) ?>
        </a>
      </div>
  </section>

  <section class="container py-5">
    <h2 class="h4 text-center mb-4"><?= e(t('home_how_it_works')) ?></h2>
    <div class="row g-3">
      <?php
      $steps = [
          ['1', t('home_step1_title'), t('home_step1_desc')],
          ['2', t('home_step2_title'), t('home_step2_desc')],
          ['3', t('home_step3_title'), t('home_step3_desc')],
          ['4', t('home_step4_title'), t('home_step4_desc')],
          ['5', t('home_step5_title'), t('home_step5_desc')],
          ['6', t('home_step6_title'), t('home_step6_desc')],
          ['7', t('home_step7_title'), t('home_step7_desc')],
      ];
      foreach ($steps as [$n, $title, $desc]):
      ?>
        <div class="col-6 col-md-4 col-lg-3">
          <div class="card h-100 text-center border-0 shadow-sm psaq-step-card">
            <div class="card-body">
              <div class="psaq-step-number mb-2"><?= e($n) ?></div>
              <h3 class="h6 mb-1"><?= e($title) ?></h3>
              <p class="small text-muted mb-0"><?= e($desc) ?></p>
            </div>
          </div>
        </div>
      <?php endforeach; ?>
    </div>
  </section>

  <section class="container pb-5">
    <div class="card border-0 shadow-sm">
      <div class="card-body text-center py-4">
        <h2 class="h5 mb-1"><i class="bi bi-envelope-paper text-muted"></i> <?= e(t('home_need_help')) ?></h2>
        <p class="text-muted small mb-3">
          <?= e(t('home_need_help_desc')) ?>
        </p>
        <div class="d-flex flex-wrap justify-content-center gap-2">
          <a href="<?= e($mailtoUrl) ?>" class="btn btn-primary">
            <i class="bi bi-envelope"></i> <?= e(t('home_email_us')) ?>
          </a>
          <button type="button" class="btn btn-outline-secondary" id="psaqContactQrToggle" aria-expanded="false" aria-controls="psaqContactQrPanel">
            <i class="bi bi-qr-code"></i> <?= e(t('home_scan_qr')) ?>
          </button>
        </div>

        <div id="psaqContactQrPanel" class="mt-3 d-none">
          <div id="psaq-contact-qr-holder" class="d-flex justify-content-center mb-2"></div>
          <p class="text-muted small mb-0">
            <?= e(t('home_scan_qr_note')) ?>
            <strong><?= e($contactEmail) ?></strong> <?= e(t('home_own_device')) ?>
          </p>
        </div>
      </div>
    </div>
  </section>
</main>
<script src="<?= BASE_URL ?>/assets/vendor/qrcode.js"></script>
<script>
  (function () {
    var toggle = document.getElementById('psaqContactQrToggle');
    var panel  = document.getElementById('psaqContactQrPanel');
    var holder = document.getElementById('psaq-contact-qr-holder');
    if (!toggle || !panel || !holder) return;

    var rendered = false;
    toggle.addEventListener('click', function () {
      var showing = !panel.classList.contains('d-none');
      panel.classList.toggle('d-none', showing);
      toggle.setAttribute('aria-expanded', String(!showing));

      if (!rendered && !showing) {
        // Rendered once, lazily — only when the client actually asks to
        // see it, same reasoning as everywhere else in this app that
        // avoids doing work nobody asked for on first paint.
        var qr = qrcode(0, 'M');
        qr.addData(<?= json_encode($mailtoUrl, JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT) ?>);
        qr.make();
        holder.innerHTML = qr.createSvgTag(5, 8);
        rendered = true;
      }
    });
  })();
</script>
<?php require_once __DIR__ . '/includes/footer.php'; ?>
