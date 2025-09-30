<?php
require __DIR__ . '/../bootstrap.php';

use App\Core\Response;
use App\Repositories\UserRepository;
use App\Repositories\TokenRepository;
use App\Services\AuthService;
use App\Core\Database;

$config = require __DIR__ . '/../../config/config.php';
$auth = new AuthService(new UserRepository(), new TokenRepository(), $config['auth']['token_ttl'] ?? (7*24*3600));
$pdo = Database::pdo();

switch ($_SERVER['REQUEST_METHOD']) {
    case 'GET':
        $postId = isset($_GET['post_id']) ? (int)$_GET['post_id'] : 0;
        if ($postId <= 0) Response::json(['error' => 'post_id required'], 400);
        $sql = 'SELECT c.id, c.post_id, c.user_id, c.parent_id, c.content, c.created_at, u.full_name AS user_name, u.avatar_url AS user_avatar
                FROM comments c
                JOIN `user` u ON u.id = c.user_id
                WHERE c.post_id = ?
                ORDER BY c.id ASC';
        $st = $pdo->prepare($sql);
        $st->execute([$postId]);
        $rows = $st->fetchAll() ?: [];
        Response::json(['comments' => $rows]);
        break;
    case 'POST':
        $authHeader = $_SERVER['HTTP_AUTHORIZATION'] ?? ($_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '');
        if ($authHeader === '' && function_exists('getallheaders')) { $h = getallheaders(); if (isset($h['Authorization'])) $authHeader = $h['Authorization']; }
        $user = $auth->authenticate($authHeader);
        if (!$user) Response::json(['error' => 'Unauthorized'], 401);
        $body = read_json_body();
        $postId = (int)($body['post_id'] ?? 0);
        $parentId = isset($body['parent_id']) ? (int)$body['parent_id'] : null;
        $content = trim((string)($body['content'] ?? ''));
        if ($postId <= 0 || $content === '') Response::json(['error' => 'post_id and content required'], 400);
        if ($parentId !== null && $parentId > 0) {
            // Validate parent belongs to same post
            $chk = $pdo->prepare('SELECT post_id FROM comments WHERE id=? LIMIT 1');
            $chk->execute([$parentId]);
            $row = $chk->fetch();
            if (!$row || (int)$row['post_id'] !== $postId) {
                Response::json(['error' => 'Invalid parent_id'], 400);
            }
        } else {
            $parentId = null;
        }
        $ins = $pdo->prepare('INSERT INTO comments (post_id, user_id, parent_id, content) VALUES (?, ?, ?, ?)');
        $ins->execute([$postId, $user->id, $parentId, $content]);
        $id = (int)$pdo->lastInsertId();
        $sel = $pdo->prepare('SELECT c.id, c.post_id, c.user_id, c.parent_id, c.content, c.created_at, u.full_name AS user_name, u.avatar_url AS user_avatar
                              FROM comments c JOIN `user` u ON u.id = c.user_id WHERE c.id = ?');
        $sel->execute([$id]);
        $row = $sel->fetch();
        Response::json(['comment' => $row], 201);
        break;
    case 'DELETE':
        $authHeader = $_SERVER['HTTP_AUTHORIZATION'] ?? ($_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '');
        if ($authHeader === '' && function_exists('getallheaders')) { $h = getallheaders(); if (isset($h['Authorization'])) $authHeader = $h['Authorization']; }
        $user = $auth->authenticate($authHeader);
        if (!$user) Response::json(['error' => 'Unauthorized'], 401);
        $commentId = isset($_GET['id']) ? (int)$_GET['id'] : 0;
        if ($commentId <= 0) Response::json(['error' => 'id required'], 400);
        // Allow delete if owner of comment
        $s = $pdo->prepare('SELECT user_id FROM comments WHERE id=? LIMIT 1');
        $s->execute([$commentId]);
        $row = $s->fetch();
        if (!$row) Response::json(['error' => 'Not found'], 404);
        if ((int)$row['user_id'] !== (int)$user->id) {
            Response::json(['error' => 'Forbidden'], 403);
        }
        $d = $pdo->prepare('DELETE FROM comments WHERE id=?');
        $d->execute([$commentId]);
        Response::json(['deleted' => true]);
        break;
    case 'PATCH':
        $authHeader = $_SERVER['HTTP_AUTHORIZATION'] ?? ($_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '');
        if ($authHeader === '' && function_exists('getallheaders')) { $h = getallheaders(); if (isset($h['Authorization'])) $authHeader = $h['Authorization']; }
        $user = $auth->authenticate($authHeader);
        if (!$user) Response::json(['error' => 'Unauthorized'], 401);
        $body = read_json_body();
        $commentId = (int)($body['id'] ?? 0);
        $content = trim((string)($body['content'] ?? ''));
        if ($commentId <= 0 || $content === '') Response::json(['error' => 'id and content required'], 400);
        $sel = $pdo->prepare('SELECT user_id FROM comments WHERE id=? LIMIT 1');
        $sel->execute([$commentId]);
        $row = $sel->fetch();
        if (!$row) Response::json(['error' => 'Not found'], 404);
        if ((int)$row['user_id'] !== (int)$user->id) Response::json(['error' => 'Forbidden'], 403);
        $upd = $pdo->prepare('UPDATE comments SET content=?, updated_at=CURRENT_TIMESTAMP WHERE id=?');
        $upd->execute([$content, $commentId]);
        $out = $pdo->prepare('SELECT c.id, c.post_id, c.user_id, c.parent_id, c.content, c.created_at, c.updated_at, u.full_name AS user_name, u.avatar_url AS user_avatar
                              FROM comments c JOIN `user` u ON u.id = c.user_id WHERE c.id = ?');
        $out->execute([$commentId]);
        $comment = $out->fetch();
        Response::json(['comment' => $comment]);
        break;
    default:
        Response::json(['error' => 'Method Not Allowed'], 405);
}
