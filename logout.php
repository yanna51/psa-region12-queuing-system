<?php
declare(strict_types=1);

/**
 * logout.php
 *
 * Full logout per §6. Phase 3 wires in the real activity log write
 * (previously just a comment, now that activity_logs exists and
 * log_activity() is implemented in includes/functions.php).
 *
 * Expects ?role=admin|staff (includes/navbar.php's Logout link always
 * sends it) — this file lives at the site root, not under /admin/ or
 * /staff/, so config/config.php's psaq_session_name() reads that query
 * param to pick which of the two role-scoped session cookies to start
 * (and this file then destroys) before $_SESSION is even touched below.
 * Without it, this would fall back to the neutral default cookie —
 * empty, since real logins never use it — and silently no-op instead
 * of logging anyone out. Visiting this URL with no role param at all
 * (an old bookmark, a manual guess) hits exactly that harmless no-op:
 * $role/$userId end up null, nothing is logged, and the redirect below
 * falls through to its own `default` case.
 */
require_once __DIR__ . '/includes/auth.php';
require_once __DIR__ . '/includes/functions.php';

$role   = $_SESSION['role'] ?? null;
$userId = $_SESSION['user_id'] ?? null;

if ($userId) {
    log_activity((int) $userId, 'Logout', ucfirst((string) $role) . ' logged out.');
}

// Wipe all session data, then destroy the session cookie itself —
// unset($_SESSION['user_id']) alone is not enough.
$_SESSION = [];

if (ini_get('session.use_cookies')) {
    $params = session_get_cookie_params();
    setcookie(
        session_name(),
        '',
        time() - 42000,
        $params['path'],
        $params['domain'],
        $params['secure'],
        $params['httponly']
    );
}

session_destroy();

$redirect = match ($role) {
    'admin' => BASE_URL . '/admin/login.php',
    'staff' => BASE_URL . '/staff/login.php',
    default => BASE_URL . '/index.php',
};

header('Location: ' . $redirect);
exit;
