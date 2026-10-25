#!/usr/bin/env bash
#
# Despliega lo último de main en este VPS.
#
# Lo corre GitHub Actions por SSH en cada push (.github/workflows/desplegar.yml), y también se
# puede correr a mano: `bash /var/www/distributor/desplegar.sh`. Con TODO=1 rehace todo aunque
# no haya cambios (por ejemplo, después de tocar appsettings.Production.json).
#
# Solo hace lo que el push necesita: si cambió el backend, migra, publica y reinicia; si cambió
# la web, la vuelve a compilar. Si algo falla se detiene ahí, y el servicio sigue con la versión
# que ya tenía.

set -euo pipefail

# Todo dentro de una función: el `git pull` de abajo puede cambiar este mismo archivo mientras
# corre, y bash lee los scripts de a poco. Así ya está leído entero antes de empezar.
main() {

RAIZ=/var/www/distributor
export PATH="$PATH:$HOME/.dotnet/tools"
export DOTNET_CLI_TELEMETRY_OPTOUT=1
export DOTNET_NOLOGO=1

cd "$RAIZ"

antes=$(git rev-parse HEAD)
# --ff-only: si alguien tocó el código en el VPS, falla en vez de pisarlo.
git pull --ff-only --quiet origin main
despues=$(git rev-parse HEAD)
echo "Versión: ${antes:0:7} -> ${despues:0:7}"

cambio() {
  [ "${TODO:-0}" = "1" ] && return 0
  git diff --name-only "$antes" "$despues" | grep -q "^$1"
}

if cambio "Backend/"; then
  echo "== Backend: migraciones, publicación y reinicio"
  cd "$RAIZ/Backend/Backend"
  dotnet restore --verbosity quiet
  ASPNETCORE_ENVIRONMENT=Production dotnet ef database update
  dotnet publish -c Release -o "$RAIZ/publish" --no-restore --verbosity quiet
  systemctl restart distributor-backend

  # Que de verdad haya levantado: 401 es lo esperado sin sesión.
  for _ in $(seq 1 30); do
    codigo=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:5220/api/producto || true)
    [ "$codigo" = "401" ] && break
    sleep 2
  done
  if [ "$codigo" != "401" ]; then
    echo "El backend no respondió (código $codigo). Últimas líneas del servicio:"
    journalctl -u distributor-backend -n 30 --no-pager
    exit 1
  fi
  echo "Backend arriba."
else
  echo "== Backend sin cambios"
fi

if cambio "Frontend/"; then
  echo "== Web: compilación"
  cd "$RAIZ/Frontend"
  pnpm install --frozen-lockfile --reporter=silent
  pnpm build
  echo "Web compilada."
else
  echo "== Web sin cambios"
fi

echo "Despliegue terminado: ${despues:0:7}"
}

main "$@"
exit
