<?php

require __DIR__ . '/vendor/autoload.php';

spl_autoload_register(function ($class) {
    $prefix = 'Buzz\\';
    if (strncmp($class, $prefix, strlen($prefix)) !== 0) return;
    $relative = substr($class, strlen($prefix));
    $file = __DIR__ . '/src/' . str_replace('\\', '/', $relative) . '.php';
    if (is_file($file)) require $file;
});

$config = require __DIR__ . '/config.php';

(new \Buzz\Server($config))->run();
