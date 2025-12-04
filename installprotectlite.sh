#!/bin/bash

echo "===================================="
echo "   INSTALL PROTECT PANEL v7"
echo "   PROTECT BY @Humannnceko"
echo "===================================="

# Lokasi panel
PANEL_DIR="/var/www/pterodactyl"
MW_DIR="$PANEL_DIR/app/Http/Middleware"
MW_FILE="$MW_DIR/AntiIntipMiddleware.php"

echo "[1] Memastikan folder middleware..."
mkdir -p $MW_DIR

echo "[2] Memasang AntiIntipMiddleware..."
cat > $MW_FILE <<'EOF'
<?php

namespace Pterodactyl\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class AntiIntipMiddleware
{
    public function handle(Request $request, Closure $next)
    {
        $user = Auth::user();

        if ($user && !$user->root_admin) {

            if ($request->route('server')) {
                $server = $request->route('server');

                if ($server->owner_id !== $user->id) {
                    return response()->json([
                        "status" => "denied",
                        "message" => "𝗣𝗥𝗢𝗧𝗘𝗖𝗧 𝗕𝗬 @𝗛𝘂𝗺𝗮𝗻𝗻𝗻𝗰𝗲𝗸𝗼 — jangan lah suka Mengintip 🔒"
                    ], 403);
                }
            }
        }

        return $next($request);
    }
}
EOF

echo "[3] Daftarkan middleware ke Kernel..."
KERNEL_FILE="$PANEL_DIR/app/Http/Kernel.php"

if ! grep -q "AntiIntipMiddleware" "$KERNEL_FILE"; then
    sed -i "/protected \$routeMiddleware = \[/a \ \ \ \ 'anti.intip' => \\Pterodactyl\\Http\\Middleware\\AntiIntipMiddleware::class," "$KERNEL_FILE"
fi

echo "[4] Menambahkan proteksi middleware ke route server..."

ROUTE_FILE="$PANEL_DIR/routes/server.php"

if ! grep -q "anti.intip" "$ROUTE_FILE"; then
    sed -i "s/middleware('auth');/middleware(['auth','anti.intip']);/g" $ROUTE_FILE
fi

echo "[5] Fix permission..."
chown -R www-data:www-data $PANEL_DIR
chmod -R 755 $PANEL_DIR

echo "[6] Restart panel service..."
systemctl restart pteroq >/dev/null 2>&1
systemctl restart nginx >/dev/null 2>&1

echo
echo "===================================="
echo " INSTALL PROTECT v7 SELESAI!"
echo " PROTECT BY @Humannnceko"
echo " Anti-intip sudah aktif di panel!"
echo "===================================="