<?php
/**
 * UnrealIRCd WebPanel Configuration
 * This file will be automatically generated during setup
 * 
 * For manual configuration, see:
 * https://www.unrealircd.org/docs/UnrealIRCd_webpanel
 */

return [
    'unrealircd' => [
        'host' => $_ENV['UNREALIRCD_HOST'] ?? 'ircd',
        'port' => (int)($_ENV['UNREALIRCD_PORT'] ?? 8600),
        'rpc_user' => $_ENV['UNREALIRCD_RPC_USER'] ?? 'adminpanel',
        'rpc_password' => $_ENV['UNREALIRCD_RPC_PASSWORD'] ?? 'webpanel_password_2024',
    ],
    
    'auth' => [
        'backend' => 'file', // or 'sql' for database authentication
        'file' => [
            'path' => __DIR__ . '/data/users.json',
        ],
        'sql' => [
            'host' => $_ENV['DB_HOST'] ?? 'localhost',
            'port' => (int)($_ENV['DB_PORT'] ?? 3306),
            'database' => $_ENV['DB_NAME'] ?? 'unrealircdwebpanel',
            'username' => $_ENV['DB_USER'] ?? 'unrealircdwebpanel',
            'password' => $_ENV['DB_PASSWORD'] ?? '',
        ],
    ],
    
    'security' => [
        'session_timeout' => 3600, // 1 hour
        'max_login_attempts' => 5,
        'lockout_duration' => 900, // 15 minutes
    ],
    
    'features' => [
        'plugins' => true,
        'updates' => true,
        'backups' => true,
    ],
];
