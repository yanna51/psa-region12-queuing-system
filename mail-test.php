<?php
declare(strict_types=1);

/**
 * mail-test.php
 *
 * A standalone diagnostic — NOT part of the app's normal flow, not
 * linked from anywhere. Sends one real test email using whatever is
 * currently in config/mail.php and prints the full SMTP conversation
 * on screen, so a failure shows its exact reason (bad auth, blocked
 * port, TLS/certificate problem, etc.) instead of just "FAILED" in the
 * notifications table.
 *
 * Use it when send_otp_email() / send_gmail_email() aren't delivering
 * and you need to know *why*, not just *that*.
 *
 * DELETE THIS FILE once you're done — like any diagnostic script that
 * exercises real credentials and prints internals to the browser, it
 * should never stay live on a real deployment.
 */

require_once __DIR__ . '/vendor/autoload.php';
require_once __DIR__ . '/config/mail.php';

use PHPMailer\PHPMailer\PHPMailer;
use PHPMailer\PHPMailer\Exception as PHPMailerException;

header('Content-Type: text/plain; charset=utf-8');

echo "PSAQ mail diagnostic\n";
echo str_repeat('=', 60) . "\n";
echo "MAIL_HOST:       " . MAIL_HOST . "\n";
echo "MAIL_PORT:       " . MAIL_PORT . "\n";
echo "MAIL_ENCRYPTION: " . MAIL_ENCRYPTION . "\n";
echo "MAIL_USERNAME:   " . MAIL_USERNAME . "\n";
echo "MAIL_PASSWORD:   " . (MAIL_PASSWORD === 'your-app-password' ? '(still the placeholder!)' : str_repeat('*', strlen(MAIL_PASSWORD))) . "\n";
echo "MAIL_FROM:       " . MAIL_FROM . "\n";
echo str_repeat('=', 60) . "\n\n";

if (MAIL_USERNAME === 'your-email@gmail.com' || MAIL_PASSWORD === 'your-app-password') {
    echo "STOP: config/mail.php still has placeholder credentials.\n";
    echo "Fill in a real Gmail address and App Password first — see README.md's\n";
    echo "\"Email — read this before a live demo\" section or DEPLOY_INFINITYFREE.md.\n";
    exit;
}

echo "Attempting a real SMTP connection and test send to " . MAIL_USERNAME . " ...\n\n";
echo "--- SMTP conversation ---\n";

$mail = new PHPMailer(true);
try {
    $mail->SMTPDebug   = 2; // client -> server and server -> client lines
    $mail->Debugoutput = function (string $str, int $level): void {
        echo $str . "\n";
    };
    $mail->isSMTP();
    $mail->Host       = MAIL_HOST;
    $mail->SMTPAuth   = true;
    $mail->Username   = MAIL_USERNAME;
    $mail->Password   = MAIL_PASSWORD;
    $mail->SMTPSecure = MAIL_ENCRYPTION;
    $mail->Port       = MAIL_PORT;
    $mail->Timeout    = 15;
    $mail->setFrom(MAIL_FROM, MAIL_FROM_NAME);
    $mail->addAddress(MAIL_USERNAME); // sends to yourself — safe to run repeatedly
    $mail->Subject = 'PSAQ mail-test.php diagnostic';
    $mail->Body    = 'If you received this, real Gmail SMTP delivery is working correctly.';

    $mail->send();

    echo "\n--- RESULT ---\n";
    echo "SUCCESS — check the inbox at " . MAIL_USERNAME . " (and Spam, on a first send).\n";
    echo "If this succeeded but OTP/booking emails still don't arrive, the mail config\n";
    echo "itself is fine — the problem is elsewhere (delete this file and let me know).\n";
} catch (PHPMailerException | Throwable $e) {
    echo "\n--- RESULT ---\n";
    echo "FAILED: " . $e->getMessage() . "\n\n";
    echo "Common causes for this exact message:\n";
    echo "- \"SMTP Error: Could not authenticate\" -> wrong App Password, or\n";
    echo "  2-Step Verification isn't actually turned on for this Gmail account\n";
    echo "  (Google won't accept App Password auth without it, even if the\n";
    echo "  password itself was generated successfully).\n";
    echo "- \"Could not connect to SMTP host\" / \"Connection timed out\" -> something\n";
    echo "  between this server and smtp.gmail.com:587 is blocking it — a Windows\n";
    echo "  Firewall or antivirus rule on php.exe/httpd.exe, a router/ISP block, or\n";
    echo "  (on a shared host) that host blocking outbound SMTP entirely.\n";
    echo "- \"SSL certificate problem\" / \"certificate verify failed\" -> XAMPP's\n";
    echo "  bundled CA certificate list is outdated. Fix: download a current\n";
    echo "  cacert.pem from https://curl.se/ca/cacert.pem, save it somewhere under\n";
    echo "  your XAMPP folder, then set in php.ini: openssl.cafile=\"<that path>\"\n";
    echo "  and curl.cainfo=\"<that path>\", then restart Apache.\n";
}
