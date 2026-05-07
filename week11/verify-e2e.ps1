# End-to-End verification script for Week 11 (PowerShell)
# Usage: .\verify-e2e.ps1 [-SkipDestroy]
#
# Steps:
#   1. Check required tools (terraform, kubectl, minikube)
#   2. Validate Terraform code (fmt + init + validate)
#   3. (Optional) Destroy current state to start clean
#   4. Apply Terraform to deploy the full stack
#   5. Verify pods, services, and basic reachability

param(
    [switch]$SkipDestroy
)

$ErrorActionPreference = "Stop"
$tfDir = Join-Path $PSScriptRoot "terraform"

function Write-Step($msg) { Write-Host "`n=== $msg ===" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "  [OK] $msg"   -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "  [!]  $msg"   -ForegroundColor Yellow }
function Write-Err($msg)  { Write-Host "  [X]  $msg"   -ForegroundColor Red }

# --- 1. Check tools ---
Write-Step "1. Checking required tools"
foreach ($tool in @("terraform", "kubectl", "minikube")) {
    if (Get-Command $tool -ErrorAction SilentlyContinue) {
        Write-Ok "$tool found"
    } else {
        Write-Err "$tool not found in PATH"
        exit 1
    }
}

# --- 2. Validate Terraform ---
Write-Step "2. Validating Terraform code"
Push-Location $tfDir
try {
    terraform fmt -check
    if ($LASTEXITCODE -ne 0) { throw "terraform fmt -check failed" }
    Write-Ok "fmt OK"

    terraform init -backend=false -input=false
    if ($LASTEXITCODE -ne 0) { throw "terraform init failed" }
    Write-Ok "init OK"

    terraform validate
    if ($LASTEXITCODE -ne 0) { throw "terraform validate failed" }
    Write-Ok "validate OK"
} finally {
    Pop-Location
}

# --- 3. Ensure Minikube is running ---
Write-Step "3. Checking Minikube cluster"
# We route minikube through `cmd /c` so stderr is swallowed at cmd level.
# PowerShell 5.1 otherwise wraps native stderr as NativeCommandError and the
# global ErrorActionPreference=Stop would abort on benign warnings (e.g. stale
# kubeconfig endpoint port).
$mkStatus = (& cmd /c "minikube status --format={{.Host}} 2>nul").Trim()
if (-not $mkStatus -or $mkStatus -ne "Running") {
    Write-Warn "Minikube not running, starting..."
    & cmd /c "minikube start"
    if ($LASTEXITCODE -ne 0) { Write-Err "minikube start failed"; exit 1 }
}
Write-Ok "Minikube running"

# Refresh kubeconfig in case the API server port changed since last start
# (otherwise kubectl will hit a stale endpoint and every later step breaks).
Write-Host "  Refreshing kubeconfig context..."
& cmd /c "minikube update-context 2>nul" | Out-Null
Write-Ok "kubeconfig in sync"

# --- 4. Destroy + apply (full reproducibility test) ---
Push-Location $tfDir
try {
    terraform init -input=false
    if ($LASTEXITCODE -ne 0) { throw "terraform init (with backend) failed" }

    if (-not $SkipDestroy) {
        Write-Step "4a. Destroying existing infrastructure"
        terraform destroy -auto-approve -var="environment=dev"
        if ($LASTEXITCODE -ne 0) {
            throw "terraform destroy failed (exit $LASTEXITCODE) - state may be inconsistent. Run a manual cleanup before retrying."
        }
        Write-Ok "destroy completed (or nothing to destroy)"
    }

    Write-Step "4b. Applying Terraform from scratch"
    $start = Get-Date
    terraform apply -auto-approve -var="environment=dev"
    if ($LASTEXITCODE -ne 0) { throw "terraform apply failed" }
    $duration = (Get-Date) - $start
    Write-Ok ("apply completed in {0:N0}s" -f $duration.TotalSeconds)
} finally {
    Pop-Location
}

# --- 5. Verify pods and services ---
Write-Step "5. Verifying Kubernetes resources"
Write-Host "Waiting for pods to become Ready (timeout 180s)..."
kubectl wait --for=condition=Ready pods --all --timeout=180s
if ($LASTEXITCODE -ne 0) {
    Write-Err "Some pods did not become Ready"
    kubectl get pods
    exit 1
}
Write-Ok "All pods Ready"

Write-Host "`nPods:"
kubectl get pods -o wide

Write-Host "`nServices:"
kubectl get svc

# --- 6. Smoke test: reach Nginx via kubectl port-forward ---
# We deliberately do not hit `minikube ip:30080` directly because on Windows
# with the Docker driver that address lives inside Docker Desktop's internal
# network and is not reachable from the host. port-forward works on every
# platform.
Write-Step "6. Reachability smoke test (Nginx via port-forward)"
$localPort = 18080
$pf = Start-Process kubectl `
    -ArgumentList "port-forward", "svc/nginx-dev", "${localPort}:80" `
    -PassThru -NoNewWindow -RedirectStandardOutput "$env:TEMP\pf-stdout.log" `
    -RedirectStandardError "$env:TEMP\pf-stderr.log"
Start-Sleep -Seconds 3
try {
    $url = "http://127.0.0.1:${localPort}/"
    Write-Host "  GET $url (via port-forward)"
    $resp = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 10
    Write-Ok "HTTP $($resp.StatusCode) - Nginx reachable"
} catch {
    Write-Err "Nginx not reachable via port-forward: $_"
    Write-Host "  port-forward stderr:"
    Get-Content "$env:TEMP\pf-stderr.log" -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "    $_" }
    exit 1
} finally {
    if ($pf -and -not $pf.HasExited) {
        Stop-Process -Id $pf.Id -Force -ErrorAction SilentlyContinue
    }
    Remove-Item "$env:TEMP\pf-stdout.log", "$env:TEMP\pf-stderr.log" -ErrorAction SilentlyContinue
}

Write-Host "`n=== End-to-End verification SUCCESS ===" -ForegroundColor Green
