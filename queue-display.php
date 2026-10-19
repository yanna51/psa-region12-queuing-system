<?php
declare(strict_types=1);

/**
 * queue-display.php — Phase 10
 *
 * Public "Now Serving" board (§27). Real data via the same
 * get_live_queue() engine staff/admin use — no invented numbers. Shows
 * queue numbers only, never client names: this page is meant to run on
 * a lobby monitor anyone can see, so no PII belongs on it (same
 * principle the QR tokens follow).
 *
 * Phase 11: now auto-refreshes via api/queue-display.php — a
 * deliberately separate, no-login, PII-stripped endpoint (queue number
 * + transaction type only), never api/queue.php, which requires a
 * staff/admin session and includes client names.
 *
 * Phase 12: adds an optional voice announcer (assets/js/queue-voice.js)
 * that speaks "Number R 1, please proceed to Counter 2" the moment a
 * client is called. It starts OFF — an explicit "Enable Voice
 * Announcements" button below is required, because several browsers
 * block SpeechSynthesis output until a real user gesture has occurred
 * on the page, so a lobby monitor can't just assume autoplay works.
 * A manual English/Filipino toggle is also offered — a per-viewer
 * override, kept even now that admin/settings.php (Phase 17) can
 * change the server-side default, since this page's viewer and the
 * admin who set that default are rarely the same person in the room.
 */
require_once __DIR__ . '/includes/functions.php';
require_once __DIR__ . '/includes/queue-functions.php';
require_once __DIR__ . '/includes/i18n-functions.php';

$queue    = get_live_queue();
$serving  = array_values(array_filter($queue['entries'], fn ($e) => in_array($e['status'], ['CALLED', 'SERVING'], true)));
$waiting  = array_values(array_filter($queue['entries'], fn ($e) => $e['status'] === 'WAITING'));
$upNext   = array_slice($waiting, 0, 10);
$moreWait = max(0, count($waiting) - count($upNext));

$pageTitle = 'Queue Status';
require_once __DIR__ . '/includes/header.php';
require_once __DIR__ . '/includes/navbar.php';
?>
<main class="container py-5">
  <div class="d-flex flex-wrap justify-content-between align-items-center mb-4 gap-2">
    <h1 class="h4 mb-0"><i class="bi bi-display"></i> <?= e(t('qd_title')) ?></h1>
    <span class="text-muted small" id="queueDisplayUpdatedAt"><?= e(t('qd_updated')) ?> <?= date('g:i A') ?></span>
  </div>

  <div class="d-flex flex-wrap align-items-center gap-2 mb-4">
    <button type="button" class="btn btn-outline-primary btn-sm" id="voiceEnableBtn">
      <i class="bi bi-volume-up"></i> <?= e(t('qd_voice_enable')) ?>
    </button>
    <span class="text-muted small d-none d-sm-inline" id="voiceStatusNote"><?= e(t('qd_voice_off_note')) ?></span>

    <div class="btn-group btn-group-sm ms-auto" role="group" aria-label="<?= e(t('qd_voice_lang')) ?>">
      <input type="radio" class="btn-check" name="voiceLang" id="voiceLangEn" autocomplete="off" checked>
      <label class="btn btn-outline-secondary" for="voiceLangEn"><?= e(t('qd_voice_en')) ?></label>

      <input type="radio" class="btn-check" name="voiceLang" id="voiceLangFil" autocomplete="off">
      <label class="btn btn-outline-secondary" for="voiceLangFil"><?= e(t('qd_voice_fil')) ?></label>
    </div>
  </div>

  <div class="row g-4">
    <div class="col-lg-6">
      <div class="card border-0 shadow-sm h-100">
        <div class="card-body">
          <h2 class="h6 mb-3"><i class="bi bi-person-check"></i> <?= e(t('qd_serving_title')) ?></h2>
          <p class="text-muted small mb-0" id="servingEmptyNote" <?= $serving ? 'hidden' : '' ?>>
            <?= e(t('qd_serving_empty')) ?>
          </p>
          <ul class="list-unstyled mb-0" id="servingList">
            <?php foreach ($serving as $e): ?>
              <li class="d-flex justify-content-between border-bottom py-2">
                <span class="badge text-bg-success fs-6"><?= e($e['queue_number']) ?></span>
                <span class="text-muted"><?= e($e['queue_type_name']) ?></span>
              </li>
            <?php endforeach; ?>
          </ul>
        </div>
      </div>
    </div>

    <div class="col-lg-6">
      <div class="card border-0 shadow-sm h-100">
        <div class="card-body">
          <h2 class="h6 mb-3"><i class="bi bi-hourglass-split"></i> <?= e(t('qd_upnext_title')) ?></h2>
          <p class="text-muted small mb-0" id="waitingEmptyNote" <?= $waiting ? 'hidden' : '' ?>>
            <?= e(t('qd_waiting_empty')) ?>
          </p>
          <ul class="list-unstyled mb-0" id="waitingList">
            <?php foreach ($upNext as $e): ?>
              <li class="d-flex justify-content-between border-bottom py-2">
                <span class="badge text-bg-primary fs-6"><?= e($e['queue_number']) ?></span>
                <span class="text-muted"><?= e($e['queue_type_name']) ?></span>
              </li>
            <?php endforeach; ?>
          </ul>
          <p class="text-muted small mt-2 mb-0" id="moreWaitNote" <?= $moreWait > 0 ? '' : 'hidden' ?>>
            +<span id="moreWaitCount"><?= $moreWait ?></span> <?= e(t('qd_more_waiting')) ?>
          </p>
        </div>
      </div>
    </div>
  </div>

  <p class="text-muted small mt-4 mb-0">
    <?= e(t('qd_pii_note')) ?>
  </p>
</main>
<script>window.PSAQ_QUEUE_DISPLAY_API_URL = <?= json_encode(BASE_URL . '/api/queue-display.php') ?>;</script>
<script src="<?= BASE_URL ?>/assets/js/queue-voice.js"></script>
<script src="<?= BASE_URL ?>/assets/js/queue-poll.js"></script>
<script src="<?= BASE_URL ?>/assets/js/queue-display.js"></script>
<script>
(function () {
  var enableBtn  = document.getElementById('voiceEnableBtn');
  var statusNote = document.getElementById('voiceStatusNote');
  var langEn     = document.getElementById('voiceLangEn');
  var langFil    = document.getElementById('voiceLangFil');

  if (!enableBtn || !window.PSAQQueueVoice) return;

  enableBtn.addEventListener('click', function () {
    window.PSAQQueueVoice.enable();
    enableBtn.disabled = true;
    enableBtn.innerHTML = '<i class="bi bi-volume-up-fill"></i> ' + <?= json_encode(t('qd_voice_on')) ?>;
    if (statusNote) statusNote.textContent = <?= json_encode(t('qd_voice_on_note')) ?>;
  });

  function applyLanguage() {
    window.PSAQQueueVoice.setLanguage(langFil && langFil.checked ? 'fil' : 'en');
  }
  if (langEn) langEn.addEventListener('change', applyLanguage);
  if (langFil) langFil.addEventListener('change', applyLanguage);
})();
</script>
<?php require_once __DIR__ . '/includes/footer.php'; ?>
