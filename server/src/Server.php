<?php

namespace Buzz;

use Workerman\Worker;
use Workerman\Connection\TcpConnection;
use Workerman\Protocols\Http\Request;
use Workerman\Protocols\Http\Response;
use Workerman\Timer;

class Server
{
    private array $cfg;
    private Worker $wsWorker;
    private Worker $httpWorker;

    /** @var array<int, array<string, TcpConnection>>  userId => [deviceId => conn] */
    private array $clients = [];

    public function __construct(array $cfg)
    {
        $this->cfg = $cfg;
    }

    public function run(): void
    {
        Db::init($this->cfg['db']);

        $host = $this->cfg['host'];
        $wsPort = $this->cfg['port'];
        $httpPort = $this->cfg['http_port'];

        $this->wsWorker = new Worker("websocket://$host:$wsPort");
        $this->wsWorker->name = 'buzz-ws';
        $this->wsWorker->count = 1;
        $this->wsWorker->onWorkerStart = function () {
            Db::init($this->cfg['db']);
            echo "[Buzz] WebSocket listening on {$this->cfg['host']}:{$this->cfg['port']}\n";
        };
        $this->wsWorker->onWebSocketConnect = function (TcpConnection $conn, $header) {
            $this->onWsConnect($conn, $header);
        };
        $this->wsWorker->onMessage = function (TcpConnection $conn, $data) {
            $this->onMessage($conn, $data);
        };
        $this->wsWorker->onClose = function (TcpConnection $conn) {
            $this->onClose($conn);
        };

        $this->httpWorker = new Worker("http://$host:$httpPort");
        $this->httpWorker->name = 'buzz-http';
        $this->httpWorker->count = 1;
        $this->httpWorker->onWorkerStart = function () {
            Db::init($this->cfg['db']);
            echo "[Buzz] HTTP listening on {$this->cfg['host']}:{$this->cfg['http_port']}\n";
        };
        $this->httpWorker->onMessage = function (TcpConnection $conn, Request $req) {
            $this->onHttp($conn, $req);
        };

        Worker::runAll();
    }

    private function onHttp(TcpConnection $conn, Request $req): void
    {
        $method = $req->method();
        $path = $req->path();

        $baseHeaders = [
            'Access-Control-Allow-Origin'  => '*',
            'Access-Control-Allow-Methods' => 'POST, GET, OPTIONS',
            'Access-Control-Allow-Headers' => 'Content-Type, Authorization',
        ];

        if ($method === 'OPTIONS') {
            $conn->send(new Response(204, $baseHeaders, ''));
            return;
        }

        try {
            if ($method === 'GET' && $path === '/health') {
                $online = 0;
                foreach ($this->clients as $set) $online += count($set);
                $this->json($conn, 200, $baseHeaders, [
                    'ok' => true,
                    'ts' => (int)(microtime(true) * 1000),
                    'online' => $online,
                ]);
                return;
            }

            if ($method === 'POST' && $path === '/api/register') {
                $body = json_decode($req->rawBody(), true) ?: [];
                $res = Auth::register((string)($body['username'] ?? ''), (string)($body['password'] ?? ''));
                $this->json($conn, 200, $baseHeaders, array_merge(['ok' => true], $res));
                return;
            }

            if ($method === 'POST' && $path === '/api/login') {
                $body = json_decode($req->rawBody(), true) ?: [];
                $res = Auth::login((string)($body['username'] ?? ''), (string)($body['password'] ?? ''));
                $this->json($conn, 200, $baseHeaders, array_merge(['ok' => true], $res));
                return;
            }

            $this->json($conn, 404, $baseHeaders, ['ok' => false, 'error' => 'not found']);
        } catch (\Throwable $e) {
            $this->json($conn, 400, $baseHeaders, ['ok' => false, 'error' => $e->getMessage()]);
        }
    }

    private function json(TcpConnection $conn, int $status, array $headers, array $body): void
    {
        $headers['Content-Type'] = 'application/json; charset=utf-8';
        $conn->send(new Response($status, $headers, json_encode($body, JSON_UNESCAPED_UNICODE)));
    }

    private function onWsConnect(TcpConnection $conn, string $header): void
    {
        if (!preg_match("#GET (.*?) HTTP/#", $header, $m)) {
            $conn->close();
            return;
        }
        $parts = parse_url($m[1]);
        $query = [];
        if (isset($parts['query'])) parse_str($parts['query'], $query);

        $token = $query['token'] ?? '';
        $deviceId = $query['device_id'] ?? '';
        $deviceName = $query['device_name'] ?? 'unknown';

        $session = $token ? Auth::verify($token) : null;
        if (!$session || !$deviceId) {
            $conn->close();
            return;
        }

        $conn->userId = $session['user_id'];
        $conn->username = $session['username'];
        $conn->deviceId = (string)$deviceId;
        $conn->deviceName = (string)$deviceName;

        try {
            Db::upsertDevice($conn->userId, $conn->deviceId, $conn->deviceName);
        } catch (\Throwable $e) {
            echo "[Buzz] DB upsertDevice failed: " . $e->getMessage() . "\n";
        }

        $this->clients[$conn->userId][$conn->deviceId] = $conn;

        $this->safeSend($conn, ['type' => 'hello', 'device_id' => $conn->deviceId]);
        $this->broadcastDeviceList($conn->userId);
        echo "[Buzz] WS connected user={$conn->username} device={$conn->deviceId}\n";
    }

    private function onMessage(TcpConnection $conn, $data): void
    {
        if (!isset($conn->userId)) {
            $conn->close();
            return;
        }
        $msg = json_decode($data, true);
        if (!is_array($msg)) return;
        $type = $msg['type'] ?? '';

        switch ($type) {
            case 'ping':
                $this->safeSend($conn, ['type' => 'pong', 'ts' => (int)(microtime(true) * 1000)]);
                break;
            case 'buzz':
                $this->handleBuzz($conn, $msg);
                break;
            case 'buzz_ack':
                $this->handleBuzzAck($conn, $msg);
                break;
        }
    }

    private function handleBuzz(TcpConnection $conn, array $msg): void
    {
        $set = $this->clients[$conn->userId] ?? [];
        $pattern = is_array($msg['pattern'] ?? null) ? $msg['pattern'] : [0, 500];
        $buzzId = isset($msg['buzz_id']) ? (string)$msg['buzz_id'] : (string)((int)(microtime(true) * 1000));
        $targets = $msg['targets'] ?? null;
        $intensity = (int)($msg['intensity'] ?? 255);

        $delivered = 0;
        foreach ($set as $target) {
            if ($target === $conn) continue;
            if (is_array($targets) && !in_array($target->deviceId, $targets, true)) continue;
            $ok = $this->safeSend($target, [
                'type'        => 'buzz',
                'buzz_id'     => $buzzId,
                'from_device' => $conn->deviceId,
                'from_name'   => $conn->deviceName,
                'pattern'     => $pattern,
                'intensity'   => $intensity,
                'ts'          => (int)(microtime(true) * 1000),
            ]);
            if ($ok) $delivered++;
        }
        $this->safeSend($conn, [
            'type'      => 'buzz_sent',
            'buzz_id'   => $buzzId,
            'delivered' => $delivered,
        ]);
    }

    private function handleBuzzAck(TcpConnection $conn, array $msg): void
    {
        $set = $this->clients[$conn->userId] ?? [];
        $fromDevice = (string)($msg['from_device'] ?? '');
        $buzzId = (string)($msg['buzz_id'] ?? '');
        if ($fromDevice === '' || $buzzId === '') return;
        $target = $set[$fromDevice] ?? null;
        if (!$target) return;
        $this->safeSend($target, [
            'type'      => 'buzz_ack',
            'buzz_id'   => $buzzId,
            'by_device' => $conn->deviceId,
            'by_name'   => $conn->deviceName,
            'ts'        => (int)(microtime(true) * 1000),
        ]);
    }

    private function onClose(TcpConnection $conn): void
    {
        if (!isset($conn->userId)) return;
        $userId = $conn->userId;
        $deviceId = $conn->deviceId ?? null;
        if ($deviceId !== null && isset($this->clients[$userId][$deviceId])
            && $this->clients[$userId][$deviceId] === $conn) {
            unset($this->clients[$userId][$deviceId]);
            if (empty($this->clients[$userId])) unset($this->clients[$userId]);
        }
        $this->broadcastDeviceList($userId);
        echo "[Buzz] WS closed user={$conn->username} device={$conn->deviceId}\n";
    }

    private function broadcastDeviceList(int $userId): void
    {
        $set = $this->clients[$userId] ?? [];
        $devices = [];
        foreach ($set as $c) {
            $devices[] = [
                'device_id'   => $c->deviceId,
                'device_name' => $c->deviceName,
                'online'      => true,
            ];
        }
        $payload = ['type' => 'device_list', 'devices' => $devices];
        foreach ($set as $c) $this->safeSend($c, $payload);
    }

    private function safeSend(TcpConnection $conn, array $payload): bool
    {
        try {
            $conn->send(json_encode($payload, JSON_UNESCAPED_UNICODE));
            return true;
        } catch (\Throwable $e) {
            return false;
        }
    }
}
