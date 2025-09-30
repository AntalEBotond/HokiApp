<?php
require __DIR__ . '/../bootstrap.php';

use App\Core\Response;
use App\Repositories\UserRepository;
use App\Repositories\TokenRepository;
use App\Services\AuthService;
use App\Core\Database;

$config = require __DIR__ . '/../../config/config.php';
$auth = new AuthService(new UserRepository(), new TokenRepository(), $config['auth']['token_ttl'] ?? (7*24*3600));

$authHeader = $_SERVER['HTTP_AUTHORIZATION'] ?? ($_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '');
if ($authHeader === '' && function_exists('getallheaders')) {
    $headers = getallheaders();
    if (isset($headers['Authorization'])) {
        $authHeader = $headers['Authorization'];
    }
}

$user = $auth->authenticate($authHeader);
if (!$user) {
    Response::json(['error' => 'Unauthorized'], 401);
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    Response::json(['error' => 'Method Not Allowed'], 405);
}

$publicDir = realpath(__DIR__ . '/..');
$uploadsDir = $publicDir . DIRECTORY_SEPARATOR . 'uploads';
$commentsDir = $uploadsDir . DIRECTORY_SEPARATOR . 'comments';
if (!is_dir($uploadsDir)) {
    mkdir($uploadsDir, 0755, true);
}
if (!is_dir($commentsDir)) {
    mkdir($commentsDir, 0755, true);
}

if (!isset($_FILES['file'])) {
    Response::json(['error' => 'No file uploaded'], 400);
}

$file = $_FILES['file'];
if (!is_uploaded_file($file['tmp_name'])) {
    Response::json(['error' => 'Upload failed'], 400);
}

$original = $file['name'] ?: 'attachment';
$ext = strtolower(pathinfo($original, PATHINFO_EXTENSION));
if (!in_array($ext, ['jpg', 'jpeg', 'png', 'gif', 'webp'], true)) {
    Response::json(['error' => 'Unsupported file type'], 400);
}

$safe = preg_replace('/[^a-zA-Z0-9_\.-]/', '_', strtolower($original));
$safe = substr($safe, -80);
$timestamp = time();
$finalName = $timestamp . '_' . $safe;
$targetPath = $commentsDir . DIRECTORY_SEPARATOR . $finalName;

if (!move_uploaded_file($file['tmp_name'], $targetPath)) {
    Response::json(['error' => 'Failed to store file'], 500);
}

$publicUrlBase = $config['app']['public_base_url'] ?? '';
if ($publicUrlBase === '') {
    // Attempt to build from current request
    $scheme = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
    $host = $_SERVER['HTTP_HOST'] ?? 'localhost';
    $path = rtrim(dirname($_SERVER['SCRIPT_NAME']), '/\\');
    $publicUrlBase = $scheme . '://' . $host . $path;
}

$relative = $publicUrlBase . '/uploads/comments/' . $finalName;

Response::json([
    'url' => $relative,
]);
