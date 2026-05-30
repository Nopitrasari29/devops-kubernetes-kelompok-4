# 🔧 Dokumentasi Teknis: GitHub Actions CI/CD Workflow

**Dibuat oleh:** Farand Febriansyah (5027231084)  
**Tanggal:** 30 Mei 2026  
**Versi Workflow:** v1.0  
**File:** `.github/workflows/ci.yml`

---

## 📚 Daftar Isi

1. [Gambaran Umum](#-gambaran-umum-workflow)
2. [Arsitektur Workflow](#-arsitektur-workflow)
3. [Penjelasan Job & Step](#-penjelasan-detail-job--step)
4. [Secrets & Environment Variables](#-secrets--environment-variables)
5. [Flow Execution](#-flow-execution)
6. [Security Best Practices](#-security-best-practices)
7. [Monitoring & Debugging](#-monitoring--debugging)

---

## 🎯 Gambaran Umum Workflow

**Tujuan:** Otomatisasi deployment aplikasi TaskFlow ke Kubernetes cluster (Minikube) setiap kali ada push ke branch `main`.

**Trigger Events:**
- ✅ Push ke branch `main`
- ✅ Pull Request ke branch `main`

**Output:** Aplikasi TaskFlow di-deploy ke namespace `taskflow-prod` di Kubernetes cluster.

---

## 🏗️ Arsitektur Workflow

```
┌─────────────────────────────────────────────────────────────┐
│                   GitHub Event (Push/PR)                   │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
            ┌────────────────────────┐
            │   JOB 1: VALIDATE      │
            │                        │
            │ • Checkout code        │
            │ • Validate manifests   │
            │ • Display config       │
            └────────────┬───────────┘
                         │
                    (Success?)
                         │
                    ┌────▼─────┐
                    │    NO     │ ❌ Workflow Stopped
                    │           │
                    └───────────┘
                         │
                    (Yes) │
                         ▼
            ┌────────────────────────┐
            │    JOB 2: DEPLOY       │
            │                        │
            │ • Setup kubeconfig     │
            │ • Setup kubectl        │
            │ • Test connection      │
            │ • Create namespaces    │
            │ • Deploy to K8s        │
            │ • Wait for ready       │
            │ • Verify service       │
            └────────────┬───────────┘
                         │
                    (Success?)
                         │
            ┌────────────┴────────────┐
            │                         │
        (Yes)│                    (No)│
            │                        │
            ▼                        ▼
   ┌────────────────┐      ┌──────────────────┐
   │  JOB 3: NOTIFY │      │ Workflow Failed  │
   │                │      │ ❌ Needs review  │
   │ • Status check │      │ → Check logs     │
   └────────────────┘      └──────────────────┘
            │
            ▼
   ✅ DEPLOYMENT COMPLETE
```

---

## 📋 Penjelasan Detail Job & Step

### **JOB 1: VALIDATE (Validasi Konfigurasi)**

**Tujuan:** Memastikan semua file konfigurasi Kubernetes tersedia dan valid sebelum deployment.

#### Step 1.1: Checkout code
```yaml
- name: Checkout code
  uses: actions/checkout@v3
  with:
    fetch-depth: 0
```
- **Fungsi:** Download repository code ke runner machine
- **fetch-depth: 0:** Mengambil seluruh git history (untuk analisis)

#### Step 1.2: Validate Kubernetes manifests
```yaml
- name: Validate Kubernetes manifests
  run: |
    # Cek file manifests
    if [ ! -f kubernetes/namespace-dev.yaml ]; then
      exit 1
    fi
```
- **Fungsi:** Verifikasi 4 file manifest wajib ada:
  - ✅ `kubernetes/namespace-dev.yaml`
  - ✅ `kubernetes/namespace-prod.yaml`
  - ✅ `kubernetes/deployment.yaml`
  - ✅ `kubernetes/service.yaml`

#### Step 1.3: Display Kubernetes configuration
```yaml
- name: Display Kubernetes configuration
  run: |
    echo "📋 Kubernetes Configuration Summary:"
    cat kubernetes/deployment.yaml
```
- **Fungsi:** Tampilkan konfigurasi untuk verifikasi manual di logs

---

### **JOB 2: DEPLOY (Deployment ke Kubernetes)**

**Tujuan:** Deploy aplikasi ke Kubernetes cluster dengan kubeconfig dari GitHub Secret.

#### Step 2.1: Checkout code
- Sama dengan Job 1

#### Step 2.2: Setup kubeconfig
```yaml
- name: Setup kubeconfig
  run: |
    echo "${{ secrets.KUBECONFIG_BASE64 }}" | base64 -d > ${{ env.KUBECONFIG_PATH }}
    chmod 600 ${{ env.KUBECONFIG_PATH }}
```
- **Fungsi:**
  1. Ambil secret `KUBECONFIG_BASE64` dari GitHub
  2. Decode dari base64 ke file kubeconfig
  3. Set permission 600 (read/write untuk owner saja)
  4. Verifikasi file dibuat

- **Security:** Permission 600 hanya bisa diakses owner (runner user)

#### Step 2.3: Setup kubectl
```yaml
- name: Setup kubectl
  uses: azure/setup-kubectl@v3
  with:
    version: 'v1.28.0'
```
- **Fungsi:** Install kubectl binary versi 1.28.0 di runner machine

#### Step 2.4: Test Kubernetes connection
```yaml
- name: Test Kubernetes connection
  env:
    KUBECONFIG: ${{ env.KUBECONFIG_PATH }}
  run: |
    kubectl cluster-info
    kubectl get nodes
    kubectl config current-context
```
- **Fungsi:**
  1. `kubectl cluster-info` → Cek API server bisa diakses
  2. `kubectl get nodes` → Verifikasi cluster nodes active
  3. `kubectl config current-context` → Confirm context yang digunakan

#### Step 2.5: Create namespaces
```yaml
- name: Create namespaces
  env:
    KUBECONFIG: ${{ env.KUBECONFIG_PATH }}
  run: |
    kubectl apply -f kubernetes/namespace-dev.yaml
    kubectl apply -f kubernetes/namespace-prod.yaml
    kubectl get namespaces
```
- **Fungsi:**
  1. Apply namespace manifest (`dev` & `prod`)
  2. Verify namespaces tersedia
  3. `kubectl apply` idempotent: aman jika namespace sudah ada

#### Step 2.6: Deploy to Kubernetes (Production)
```yaml
- name: Deploy to Kubernetes (Production)
  env:
    KUBECONFIG: ${{ env.KUBECONFIG_PATH }}
  run: |
    kubectl apply -f kubernetes/deployment.yaml -n ${{ env.NAMESPACE_PROD }}
    kubectl apply -f kubernetes/service.yaml -n ${{ env.NAMESPACE_PROD }}
```
- **Fungsi:**
  1. Apply deployment manifest ke namespace `taskflow-prod`
  2. Apply service manifest ke namespace `taskflow-prod`
  3. `-n taskflow-prod` → Specify target namespace

#### Step 2.7: Wait for deployment to be ready
```yaml
- name: Wait for deployment to be ready
  env:
    KUBECONFIG: ${{ env.KUBECONFIG_PATH }}
  run: |
    kubectl rollout status deployment/${{ env.DEPLOYMENT_NAME }} \
      -n ${{ env.NAMESPACE_PROD }} \
      --timeout=5m
```
- **Fungsi:**
  1. `kubectl rollout status` → Wait sampai deployment ready
  2. `--timeout=5m` → Max tunggu 5 menit
  3. Fail jika deployment tidak ready dalam waktu yang ditentukan

#### Step 2.8: Verify service
```yaml
- name: Verify service
  env:
    KUBECONFIG: ${{ env.KUBECONFIG_PATH }}
  run: |
    kubectl get service -n ${{ env.NAMESPACE_PROD }}
    kubectl describe service/${{ env.DEPLOYMENT_NAME }} -n ${{ env.NAMESPACE_PROD }}
```
- **Fungsi:**
  1. List semua service di namespace `taskflow-prod`
  2. Show detail service (port mapping, endpoints, dll)

#### Step 2.9: Display deployment summary
```yaml
- name: Display deployment summary
  env:
    KUBECONFIG: ${{ env.KUBECONFIG_PATH }}
  run: |
    kubectl get all -n ${{ env.NAMESPACE_PROD }}
    kubectl describe deployment/${{ env.DEPLOYMENT_NAME }} -n ${{ env.NAMESPACE_PROD }}
```
- **Fungsi:** Tampilkan summary semua resources di namespace prod

#### Step 2.10: Cleanup sensitive files
```yaml
- name: Cleanup sensitive files
  if: always()
  run: |
    rm -f ${{ env.KUBECONFIG_PATH }}
```
- **Fungsi:**
  1. Hapus kubeconfig file setelah deploy selesai
  2. `if: always()` → Run step ini bahkan jika deploy fail
  3. **Security:** Jangan save kubeconfig di artifact

---

### **JOB 3: NOTIFY (Notifikasi)**

**Tujuan:** Verifikasi status workflow dan notify hasil.

```yaml
jobs:
  notify:
    needs: [validate, deploy]
    if: always()
```
- **depends_on:** Tunggu job `validate` & `deploy` selesai
- **if: always():** Run bahkan jika job sebelumnya fail (untuk notification)

---

## 🔐 Secrets & Environment Variables

### GitHub Secrets (Encrypted)

| Secret Name | Value | Cara Setup |
|---|---|---|
| `KUBECONFIG_BASE64` | Base64-encoded kubeconfig file | [Setup Guide](./GITHUB_ACTIONS_SETUP.md#-step-2-setup-github-secret) |

### Environment Variables (Public)

| Variable | Value | Purpose |
|---|---|---|
| `NAMESPACE_DEV` | `taskflow-dev` | Development namespace |
| `NAMESPACE_PROD` | `taskflow-prod` | Production namespace |
| `DEPLOYMENT_NAME` | `taskflow-api` | Deployment name di Kubernetes |
| `KUBECONFIG_PATH` | `/tmp/kubeconfig` | Temp path untuk kubeconfig file |

### Step-Level Environment Variables

```yaml
env:
  KUBECONFIG: ${{ env.KUBECONFIG_PATH }}
```
- Setiap step yang perlu access Kubernetes harus set `KUBECONFIG` env var
- Ini memberitahu `kubectl` di mana file kubeconfig berada

---

## ⚡ Flow Execution

### Execution Timeline

```
T=0s    → Push code ke GitHub
T=5s    → GitHub Actions triggered
T=10s   → Runner machine provisioned (Ubuntu latest)
T=15s   → JOB 1 START: VALIDATE
T=25s   → JOB 1 END: VALIDATE (success)
T=30s   → JOB 2 START: DEPLOY
T=35s   → Kubeconfig setup & kubectl installed
T=40s   → Connected to Kubernetes cluster
T=45s   → Namespaces created
T=50s   → Deployment manifests applied
T=60s   → Waiting for deployment ready...
T=120s  → Deployment ready ✅
T=130s  → Services verified ✅
T=140s  → JOB 2 END: DEPLOY (success)
T=145s  → JOB 3 START: NOTIFY
T=150s  → JOB 3 END: NOTIFY (success)
T=155s  → WORKFLOW COMPLETE ✅

Total Duration: ~2.5-3 minutes
```

### Parallel Execution

- **JOB 1 & JOB 2:** Sequential (Job 2 wait Job 1)
- **JOB 3:** Sequential (setelah Job 1 & 2 complete)
- **Alasan:** Dependency tree - Job 2 perlu validate selesai dulu

---

## 🔒 Security Best Practices

### 1. **Secret Management**

✅ **DO:**
- Store kubeconfig sebagai secret (encrypted)
- Use specific secret name (case-sensitive)
- Rotate secret regularly

❌ **DON'T:**
- Hardcode kubeconfig di workflow file
- Print secret ke logs
- Commit kubeconfig ke repository

### 2. **RBAC (Role-Based Access Control)**

**Recommended:**
```yaml
# Buat service account khusus untuk CI/CD dengan limited permissions
apiVersion: v1
kind: ServiceAccount
metadata:
  name: github-actions-deploy
  namespace: taskflow-prod
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: github-actions-deployer
rules:
  - apiGroups: ["apps"]
    resources: ["deployments", "deployments/scale"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]
  - apiGroups: [""]
    resources: ["services"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]
```

### 3. **Kubeconfig File Permissions**

```bash
# Correct: 600 (only owner can read/write)
chmod 600 /tmp/kubeconfig

# Wrong: 644 (others can read)
chmod 644 /tmp/kubeconfig  # ❌ DON'T
```

### 4. **Cleanup After Deploy**

```yaml
- name: Cleanup sensitive files
  if: always()  # Run even if job failed
  run: |
    rm -f /tmp/kubeconfig
```

---

## 🔍 Monitoring & Debugging

### 1. **View Workflow Logs**

**GitHub UI:**
1. Repository → **Actions** tab
2. Click workflow run
3. Click **Deploy to Kubernetes** job
4. Expand any step to see detailed logs

### 2. **Common Issues & Solutions**

#### ❌ "Secret not found"
```
Error: KUBECONFIG_BASE64 is not defined
```
**Solusi:** Add secret di GitHub Settings → Secrets and variables

#### ❌ "Unable to connect to the server"
```
Unable to connect to the server: dial tcp: lookup on ...: server misbehaving
```
**Solusi:** Minikube tidak running atau kubeconfig expired. Restart Minikube:
```bash
minikube stop
minikube start
# Export ulang kubeconfig ke base64
cat ~/.kube/config | base64 | pbcopy
# Update secret di GitHub
```

#### ❌ "Certificate verify failed"
```
certificate verify failed: x509: certificate signed by unknown authority
```
**Solusi:** Kubeconfig corrupted. Rebuild:
```bash
minikube delete
minikube start
# Export ulang kubeconfig
```

#### ❌ "Timeout waiting for deployment"
```
Waiting for rollout to finish: 0 of 2 updated replicas are available...
error: timed out waiting for the condition
```
**Solusi:** Check pod logs:
```bash
kubectl logs -f deployment/taskflow-api -n taskflow-prod
kubectl describe pod -n taskflow-prod
```

### 3. **Manual Debugging**

```bash
# Set kubeconfig lokal
export KUBECONFIG=~/.kube/config

# Cek deployment status
kubectl get deployment -n taskflow-prod
kubectl describe deployment taskflow-api -n taskflow-prod

# Cek pod logs
kubectl logs deployment/taskflow-api -n taskflow-prod

# Cek service
kubectl get service -n taskflow-prod
kubectl describe service taskflow-api -n taskflow-prod

# Test connectivity
kubectl port-forward service/taskflow-api 8080:80 -n taskflow-prod
# Buka: http://localhost:8080
```

### 4. **Re-trigger Workflow**

```bash
# Method 1: Push empty commit
git commit --allow-empty -m "Trigger workflow"
git push origin main

# Method 2: Use GitHub CLI
gh workflow run ci.yml --ref main

# Method 3: Manual trigger di GitHub UI
# Repository → Actions → Select workflow → Run workflow button
```

---

## 📊 Monitoring Checklist

- [ ] Workflow trigger berhasil (Actions tab menunjukkan job running)
- [ ] Job VALIDATE pass ✅
- [ ] Job DEPLOY pass ✅
- [ ] Pods ready di Kubernetes (`kubectl get pods`)
- [ ] Service accessible (`kubectl port-forward`)
- [ ] Logs clean tanpa error

---

## 🔄 Integrasi dengan Development Workflow

### Development Cycle

```
1. Developer push code ke main branch
   ↓
2. GitHub Actions triggered otomatis
   ↓
3. Workflow validate & deploy
   ↓
4. Pods di Kubernetes update otomatis
   ↓
5. Service accessible di minikube ip:30080
```

### Manual Testing

```bash
# Set kubeconfig
export KUBECONFIG=~/.kube/config

# Get minikube IP
minikube ip
# Output: 192.168.64.2

# Test service
curl http://192.168.64.2:30080

# Expected: Halo dari TaskFlow v2! Fitur baru!
```

---

## 📝 Referensi & Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Kubectl Cheatsheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)
- [Minikube Documentation](https://minikube.sigs.k8s.io/docs/)

---

## ✅ Checklist Implementasi

- [ ] `.github/workflows/ci.yml` sudah dibuat
- [ ] `KUBECONFIG_BASE64` secret sudah di-add ke GitHub
- [ ] Push code ke `main` branch
- [ ] Cek workflow trigger di **Actions** tab
- [ ] Verify deployment di Kubernetes
- [ ] Test service endpoint
- [ ] Review logs untuk troubleshooting (jika ada error)

---

**Status:** ✅ Production Ready  
**Versi:** 1.0  
**Last Updated:** 30 Mei 2026
