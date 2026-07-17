<?php
/*
 * Autor: DannGzShot
 * Fecha de creacion: 16/03/2026
 * Descripcion: Prepara variables y rutas locales antes de ejecutar la app en Docker.
 */

if (!defined('REDGPS_LOCAL_DOCKER')) {
    define('REDGPS_LOCAL_DOCKER', true);
}

if (!defined('REDGPS_SMARTY_AUTO_COMPILE')) {
    define('REDGPS_SMARTY_AUTO_COMPILE', true);
}

if (PHP_SAPI !== 'cli' && isset($_SERVER['REQUEST_URI'])) {
    $basePath = '/redgps';
    $requestUri = $_SERVER['REQUEST_URI'];
    $parts = parse_url($requestUri);
    $path = $parts['path'] ?? '/';

    if (strpos($path, $basePath) === 0) {
        $newPath = substr($path, strlen($basePath));
        if ($newPath === false || $newPath === '') {
            $newPath = '/';
        }

        $newUri = $newPath;
        if (!empty($parts['query'])) {
            $newUri .= '?' . $parts['query'];
        }

        $_SERVER['ORIGINAL_REQUEST_URI'] = $_SERVER['REQUEST_URI'];
        $_SERVER['REQUEST_URI'] = $newUri;
        $_SERVER['REDGPS_BASE_PATH'] = $basePath;

        if (isset($_SERVER['PHP_SELF']) && strpos($_SERVER['PHP_SELF'], $basePath) === 0) {
            $_SERVER['PHP_SELF'] = substr($_SERVER['PHP_SELF'], strlen($basePath)) ?: '/index.php';
        }

        if (isset($_SERVER['SCRIPT_NAME']) && strpos($_SERVER['SCRIPT_NAME'], $basePath) === 0) {
            $_SERVER['SCRIPT_NAME'] = substr($_SERVER['SCRIPT_NAME'], strlen($basePath)) ?: '/index.php';
        }

        if (isset($_SERVER['SCRIPT_URI']) && strpos($_SERVER['SCRIPT_URI'], $basePath) !== false) {
            $_SERVER['SCRIPT_URI'] = str_replace($basePath, '', $_SERVER['SCRIPT_URI']);
        }

        if (isset($_SERVER['PATH_INFO']) && strpos($_SERVER['PATH_INFO'], $basePath) === 0) {
            $_SERVER['PATH_INFO'] = substr($_SERVER['PATH_INFO'], strlen($basePath)) ?: '/';
        }
    }
}

$atomicRoots = [
    '/var/www/html/web/atomic',
    '/var/www/html/web/atomic/core',
    '/var/www/html/web/atomic/lib',
    '/var/www/html/web/atomic/lib/php-route',
    '/var/www/html/web/atomic/lib/php-route/src',
];

$commonsRoots = [
    '/home/redgps/commons',
    '/home/redgps/commons/libs',
    '/home/redgps/commons/helpers',
];

$excludedRoots = [
    '/home/redgps/commons/libs/Spaces',
    '/home/redgps/commons/libs/google-api-php-client',
    '/home/redgps/commons/libs/vonage-php-sdk-core',
    '/home/redgps/commons/libs/openstreetmap_staticmap',
    '/home/redgps/commons/libs/zfirebasephp',
    '/home/redgps/commons/libs/Twilio/example',
    '/home/redgps/commons/libs/Twilio/advanced-examples',
    '/home/redgps/commons/libs/SendGrid/examples',
    '/home/redgps/commons/libs/Psr/Log/Test',
    '/home/redgps/commons/libs/dompdf/www/test',
];

$host = isset($_SERVER['HTTP_HOST']) ? strtolower($_SERVER['HTTP_HOST']) : '';
$requestUri = isset($_SERVER['REQUEST_URI']) ? $_SERVER['REQUEST_URI'] : '';
$script = isset($_SERVER['SCRIPT_FILENAME']) ? $_SERVER['SCRIPT_FILENAME'] : '';

if (stripos($host, 'dev.partners.local') !== false
    || stripos($host, 'qa.partners.local') !== false
    || strpos($requestUri, '/partners') === 0
    || strpos($script, '/partners/') !== false) {
    $appRoots = [
        '/var/www/html/web/partners/sources',
        '/var/www/html/web/partners/sources/lib',
        '/var/www/html/web/partners/sources/helpers',
    ];
} elseif (stripos($host, 'dev.reportes.local') !== false
    || stripos($host, 'qa.reportes.local') !== false
    || strpos($requestUri, '/reportes') === 0
    || strpos($script, '/reportes/') !== false) {
    $appRoots = [
        '/var/www/html/web/reportes/sources',
        '/var/www/html/web/reportes/sources/lib',
        '/var/www/html/web/reportes/sources/helpers',
    ];
} else {
    $appRoots = [
        '/var/www/html/web/redgps/sources',
        '/var/www/html/web/redgps/sources/lib',
        '/var/www/html/web/redgps/sources/helpers',
    ];
}

$roots = array_merge($atomicRoots, $appRoots, $commonsRoots);
set_include_path(implode(PATH_SEPARATOR, array_merge(['.', '/usr/local/lib/php'], $roots)));

$preload = [
    '/var/www/html/web/atomic/lib/AtomicAutoload.php',
    '/var/www/html/web/atomic/lib/PhpRoute.php',
    '/var/www/html/web/atomic/lib/RouterManager.php',
    '/var/www/html/web/atomic/lib/ViewManager.php',
];

foreach ($preload as $file) {
    if (is_file($file)) {
        require_once $file;
    }
}

spl_autoload_register(function ($class) use ($roots, $excludedRoots) {
    static $classMap = null;

    $class = ltrim($class, '\\');
    $classKey = strtolower($class);

    $isExcluded = static function ($path) use ($excludedRoots) {
        foreach ($excludedRoots as $excludedRoot) {
            if (strpos($path, $excludedRoot . DIRECTORY_SEPARATOR) === 0 || $path === $excludedRoot) {
                return true;
            }
        }

        return false;
    };

    if ($classKey === 'mongoconnection') {
        $mongoConnection = '/home/redgps/commons/libs/MongoConnection.php';
        if (is_file($mongoConnection)) {
            require_once $mongoConnection;
            return true;
        }
    }

    $classPath = str_replace('\\', DIRECTORY_SEPARATOR, $class) . '.php';
    $baseName = basename(str_replace('\\', '/', $class)) . '.php';

    foreach ($roots as $root) {
        $direct = $root . '/' . $classPath;
        if (is_file($direct)) {
            require_once $direct;
            return true;
        }

        $flat = $root . '/' . $baseName;
        if (is_file($flat)) {
            require_once $flat;
            return true;
        }
    }

    if ($classMap === null) {
        $classMap = [];

        foreach ($roots as $root) {
            if (!is_dir($root)) {
                continue;
            }

            if ($isExcluded($root)) {
                continue;
            }

            $iterator = new RecursiveIteratorIterator(
                new RecursiveDirectoryIterator($root, FilesystemIterator::SKIP_DOTS)
            );

            foreach ($iterator as $fileInfo) {
                if (!$fileInfo->isFile()) {
                    continue;
                }

                if ($isExcluded($fileInfo->getPathname())) {
                    continue;
                }

                if (strtolower($fileInfo->getExtension()) !== 'php') {
                    continue;
                }

                $filename = strtolower($fileInfo->getFilename());
                if (!isset($classMap[$filename])) {
                    $classMap[$filename] = $fileInfo->getPathname();
                }
            }
        }
    }

    $key = strtolower($baseName);

    if (isset($classMap[$key]) && is_file($classMap[$key])) {
        require_once $classMap[$key];
        return true;
    }

    return false;
}, true, true);
