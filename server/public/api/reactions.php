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

        $stmt = $pdo->prepare('SELECT type, COUNT(*) as cnt FROM reactions WHERE post_id = ? GROUP BY type');
        $stmt->execute([$postId]);
        $counts = [];
        foreach ($stmt->fetchAll() ?: [] as $r) {
            $counts[$r['type']] = (int) $r['cnt'];
        }

        $listStmt = $pdo->prepare('SELECT r.type, u.full_name, u.username, u.avatar_url
                                    FROM reactions r
                                    JOIN `user` u ON u.id = r.user_id
                                    WHERE r.post_id = ?
                                    ORDER BY r.id DESC');
        $listStmt->execute([$postId]);
        $people = [];
        foreach ($listStmt->fetchAll() ?: [] as $row) {
            $people[] = [
                'type' => $row['type'],
                'name' => $row['full_name'] ?: ($row['username'] ?: 'User'),
                'username' => $row['username'],
                'avatar_url' => $row['avatar_url'],
            ];
        }

        $authHeader = $_SERVER['HTTP_AUTHORIZATION'] ?? ($_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '');
        $user = $auth->authenticate($authHeader);
        $userReaction = null;
        if ($user) {
            $s = $pdo->prepare('SELECT type FROM reactions WHERE post_id=? AND user_id=? LIMIT 1');
            $s->execute([$postId, $user->id]);
            $row = $s->fetch();
            $userReaction = $row['type'] ?? null;
        }

        Response::json([
            'counts' => $counts,
            'user_reaction' => $userReaction,
            'reactions' => $people,
        ]);
        break;
    case 'POST':
        $authHeader = $_SERVER['HTTP_AUTHORIZATION'] ?? ($_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '');
        if ($authHeader === '' && function_exists('getallheaders')) { $h = getallheaders(); if (isset($h['Authorization'])) $authHeader = $h['Authorization']; }
        $user = $auth->authenticate($authHeader);
        if (!$user) Response::json(['error' => 'Unauthorized'], 401);
        $body = read_json_body();
        $postId = (int)($body['post_id'] ?? 0);
        $type = preg_replace('/[^a-z]/', '', strtolower($body['type'] ?? 'like'));
        if ($postId <= 0) Response::json(['error' => 'post_id required'], 400);
        // toggle: if existing with same type -> delete; if existing other type -> update; else insert
        $s = $pdo->prepare('SELECT id, type FROM reactions WHERE post_id=? AND user_id=? LIMIT 1');
        $s->execute([$postId, $user->id]);
        $row = $s->fetch();
        if ($row) {
            if ($row['type'] === $type) {
                $d = $pdo->prepare('DELETE FROM reactions WHERE id=?');
                $d->execute([(int)$row['id']]);
                Response::json(['reacted' => false]);
            } else {
                $u = $pdo->prepare('UPDATE reactions SET type=? WHERE id=?');
                $u->execute([$type, (int)$row['id']]);
                Response::json(['reacted' => true, 'type' => $type]);
            }
        } else {
            $i = $pdo->prepare('INSERT INTO reactions (post_id, user_id, type) VALUES (?, ?, ?)');
            $i->execute([$postId, $user->id, $type]);
            Response::json(['reacted' => true, 'type' => $type]);
        }
        break;
    default:
        Response::json(['error' => 'Method Not Allowed'], 405);
}

