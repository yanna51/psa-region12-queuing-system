<?php
declare(strict_types=1);

/**
 * login.php
 *
 * There's no single shared login form — admin and staff each have
 * their own authentication surface (§7–§8). This page is just a
 * chooser so a visitor who lands on /psaq/login.php by guessing the
 * URL still ends up somewhere sensible.
 */
require_once __DIR__ . '/includes/functions.php';

$pageTitle = 'Login';
require_once __DIR__ . '/includes/header.php';
require_once __DIR__ . '/includes/navbar.php';
?>
<main class="container py-5" style="max-width:440px;">
  <h1 class="h4 text-center mb-4">Sign In</h1>
  <div class="d-grid gap-2">
    <a href="<?= BASE_URL ?>/admin/login.php" class="btn btn-primary btn-lg">
      <i class="bi bi-shield-lock"></i> Admin Login
    </a>
    <a href="<?= BASE_URL ?>/staff/login.php" class="btn btn-outline-primary btn-lg">
      <i class="bi bi-person-badge"></i> Staff Login
    </a>
  </div>
  <p class="text-center text-muted small mt-4">
    Booking an appointment? You don't need an account —
    <a href="<?= BASE_URL ?>/client/booking.php">start here</a> instead.
  </p>
</main>
<?php require_once __DIR__ . '/includes/footer.php'; ?>
