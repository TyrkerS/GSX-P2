# verify-week12.ps1
# Comprueba que las NetworkPolicies de week12 estan haciendo lo correcto.
#
# Cinco casos:
#   1. nginx-dev  -> backend       (debe pasar)
#   2. backend-dev -> postgres     (debe pasar)
#   3. nginx-dev  -> postgres      (debe FALLAR — frontend no toca DB)
#   4. tester sin labels -> backend (debe FALLAR — no esta en allowlist)
#   5. resolucion DNS desde nginx  (debe pasar — policy 05)
#
# Uso: pwsh ./week12/verify-week12.ps1

$ErrorActionPreference = "Continue"

function Run-Test {
    param(
        [string]$Name,
        [string]$Expected,  # "pass" o "fail"
        [scriptblock]$Cmd
    )
    Write-Host "----- $Name (esperado: $Expected) -----" -ForegroundColor Cyan
    $result = & $Cmd 2>&1
    $exit = $LASTEXITCODE
    if (($Expected -eq "pass" -and $exit -eq 0) -or ($Expected -eq "fail" -and $exit -ne 0)) {
        Write-Host "  -> OK" -ForegroundColor Green
    } else {
        Write-Host "  -> FALLO. exit=$exit, output: $result" -ForegroundColor Red
    }
    Write-Host ""
}

$nginxPod = kubectl get pods -l app=nginx,environment=dev -o jsonpath='{.items[0].metadata.name}'
$backendPod = kubectl get pods -l app=backend,environment=dev -o jsonpath='{.items[0].metadata.name}'

if (-not $nginxPod -or -not $backendPod) {
    Write-Error "No encuentro pods con label environment=dev. Has corrido apply-week12.ps1?"
    exit 1
}

Write-Host "Pods identificados: nginx=$nginxPod  backend=$backendPod" -ForegroundColor Yellow
Write-Host ""

Run-Test "1. nginx-dev -> backend:3000" "pass" {
    kubectl exec $nginxPod -- wget -qO- --timeout=5 http://backend:3000/health
}

Run-Test "2. backend-dev -> postgres:5432" "pass" {
    kubectl exec $backendPod -- nc -zv -w 5 postgres 5432
}

Run-Test "3. nginx-dev -> postgres:5432 (debe FALLAR)" "fail" {
    kubectl exec $nginxPod -- nc -zv -w 5 postgres 5432
}

Run-Test "4. pod sin labels -> backend (debe FALLAR)" "fail" {
    kubectl run tester-noenv --rm -i --restart=Never --image=busybox --timeout=30s -- `
        wget -qO- --timeout=5 http://backend:3000/health
}

Run-Test "5. nginx-dev resuelve DNS de backend" "pass" {
    kubectl exec $nginxPod -- nslookup backend
}

Write-Host "Resumen: revisa los OK / FALLO arriba." -ForegroundColor Yellow
