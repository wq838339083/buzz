<?php

namespace Buzz;

class Auth
{
    private static array $tokens = [];

    public static function register(string $username, string $password): array
    {
        $username = trim($username);
        if (mb_strlen($username) < 2 || mb_strlen($username) > 32) {
            throw new \RuntimeException('username length invalid');
        }
        if (strlen($password) < 4) {
            throw new \RuntimeException('password too short');
        }
        if (Db::findUser($username)) {
            throw new \RuntimeException('username already exists');
        }
        $hash = password_hash($password, PASSWORD_BCRYPT);
        Db::createUser($username, $hash);
        return self::login($username, $password);
    }

    public static function login(string $username, string $password): array
    {
        $user = Db::findUser($username);
        if (!$user) {
            throw new \RuntimeException('user not found');
        }
        if (!password_verify($password, $user['password_hash'])) {
            throw new \RuntimeException('wrong password');
        }
        $token = bin2hex(random_bytes(24));
        self::$tokens[$token] = [
            'user_id'  => (int)$user['id'],
            'username' => $user['username'],
            'ts'       => time(),
        ];
        return [
            'token'    => $token,
            'userId'   => (int)$user['id'],
            'username' => $user['username'],
        ];
    }

    public static function verify(string $token): ?array
    {
        return self::$tokens[$token] ?? null;
    }

    public static function revoke(string $token): void
    {
        unset(self::$tokens[$token]);
    }
}
