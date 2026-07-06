<?php

namespace Buzz;

use PDO;
use PDOException;

class Db
{
    private static ?PDO $pdo = null;
    private static array $cfg = [];

    public static function init(array $cfg): void
    {
        self::$cfg = $cfg;
        self::connect();
        self::migrate();
    }

    private static function connect(): void
    {
        $cfg = self::$cfg;
        $dsn = sprintf(
            'mysql:host=%s;port=%d;dbname=%s;charset=%s',
            $cfg['host'], $cfg['port'], $cfg['name'], $cfg['charset']
        );
        self::$pdo = new PDO($dsn, $cfg['user'], $cfg['password'], [
            PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES   => false,
        ]);
    }

    public static function pdo(): PDO
    {
        try {
            self::$pdo->query('SELECT 1');
        } catch (PDOException $e) {
            self::connect();
        }
        return self::$pdo;
    }

    private static function migrate(): void
    {
        self::$pdo->exec("
            CREATE TABLE IF NOT EXISTS users (
                id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
                username VARCHAR(64) NOT NULL UNIQUE,
                password_hash VARCHAR(255) NOT NULL,
                created_at BIGINT NOT NULL
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ");
        self::$pdo->exec("
            CREATE TABLE IF NOT EXISTS devices (
                id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
                user_id INT UNSIGNED NOT NULL,
                device_id VARCHAR(64) NOT NULL,
                device_name VARCHAR(128) DEFAULT NULL,
                last_seen BIGINT NOT NULL,
                UNIQUE KEY uniq_user_device (user_id, device_id),
                KEY idx_user (user_id)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ");
    }

    public static function createUser(string $username, string $hash): int
    {
        $stmt = self::pdo()->prepare(
            'INSERT INTO users (username, password_hash, created_at) VALUES (?, ?, ?)'
        );
        $stmt->execute([$username, $hash, (int)(microtime(true) * 1000)]);
        return (int)self::pdo()->lastInsertId();
    }

    public static function findUser(string $username): ?array
    {
        $stmt = self::pdo()->prepare('SELECT * FROM users WHERE username = ?');
        $stmt->execute([$username]);
        $row = $stmt->fetch();
        return $row ?: null;
    }

    public static function upsertDevice(int $userId, string $deviceId, string $deviceName): void
    {
        $stmt = self::pdo()->prepare(
            'INSERT INTO devices (user_id, device_id, device_name, last_seen)
             VALUES (?, ?, ?, ?)
             ON DUPLICATE KEY UPDATE device_name = VALUES(device_name), last_seen = VALUES(last_seen)'
        );
        $stmt->execute([$userId, $deviceId, $deviceName, (int)(microtime(true) * 1000)]);
    }
}
