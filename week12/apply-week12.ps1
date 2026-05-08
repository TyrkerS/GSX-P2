# apply-week12.ps1
# Aplica el stack week10 + labels environment=dev + NetworkPolicies week12.
#
# Prerrequisito: Minikube corriendo con CNI Calico.
#   minikube delete
#   minikube start --cni=calico
#
# Uso:
#   pwsh ./week12/apply-week12.ps1

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

Write-Host "==> 0. Comprobando que el CNI es Calico..." -ForegroundColor Cyan
$calico = kubectl get pods -n kube-system --no-headers 2>$null | Select-String "calico"
if (-not $calico) {
    Write-Warning "No se detecta Calico en kube-system. Las NetworkPolicies pueden ser silenciosamente ignoradas."
    Write-Warning "Reinicia el cluster: minikube delete; minikube start --cni=calico"
    $r = Read-Host "Continuar igualmente? (y/N)"
    if ($r -ne "y") { exit 1 }
}

Write-Host "==> 1. Aplicando manifests de week10 (deployments + services)..." -ForegroundColor Cyan
kubectl apply -f "$root/week10/kubernetes/"

Write-Host "==> 2. Esperando a que los pods esten Ready..." -ForegroundColor Cyan
kubectl wait --for=condition=Ready pod -l app=nginx --timeout=120s
kubectl wait --for=condition=Ready pod -l app=backend --timeout=120s
kubectl wait --for=condition=Ready pod -l app=postgres --timeout=120s

Write-Host "==> 3. Anadiendo label environment=dev a deployments existentes..." -ForegroundColor Cyan
# kubectl label sobre deployment propaga al pod template y dispara rollout
kubectl label deployment nginx environment=dev --overwrite
kubectl label deployment backend environment=dev --overwrite
kubectl label statefulset postgres environment=dev --overwrite

# Tambien sobre los pods actuales para que la policy tenga efecto inmediato
# sin esperar al rollout
kubectl label pods -l app=nginx environment=dev --overwrite
kubectl label pods -l app=backend environment=dev --overwrite
kubectl label pods -l app=postgres environment=dev --overwrite

Write-Host "==> 4. Aplicando NetworkPolicies..." -ForegroundColor Cyan
kubectl apply -f "$PSScriptRoot/network-policies/00-default-deny.yaml"
kubectl apply -f "$PSScriptRoot/network-policies/05-allow-dns.yaml"
kubectl apply -f "$PSScriptRoot/network-policies/10-allow-frontend-backend.yaml"
kubectl apply -f "$PSScriptRoot/network-policies/20-allow-backend-postgres.yaml"
kubectl apply -f "$PSScriptRoot/network-policies/templates-staging-prod.yaml"
# 30-deny-cross-env.yaml es solo documentacion, no se aplica

Write-Host "==> 5. Estado final:" -ForegroundColor Cyan
kubectl get networkpolicies
Write-Host ""
kubectl get pods -L app,environment

Write-Host ""
Write-Host "OK. Ahora corre ./week12/verify-week12.ps1 para validar." -ForegroundColor Green
