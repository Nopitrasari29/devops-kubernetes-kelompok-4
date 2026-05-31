# TaskFlow — Kubernetes & Microservices (Kelompok 4)

Aplikasi **TaskFlow Inc.** sebelumnya dijalankan secara manual di satu server tunggal yang rentan terhadap crash, memiliki waktu downtime saat pembaruan (deployment), serta proses rollback yang lambat. Proyek ini memindahkan arsitektur aplikasi TaskFlow ke dalam orkestrasi **Kubernetes (Minikube)** untuk membuktikan keandalan sistem terhadap tiga insiden produksi utama: downtime tak terdeteksi, jeda pembaruan versi baru, dan lambatnya pemulihan saat terjadi bug kritis.

---

## 👥 Anggota Kelompok & Pembagian Tugas

Berikut adalah daftar anggota Kelompok 4 beserta pembagian tanggung jawab masing-masing dalam pengerjaan modul Kubernetes ini:

| Nama | NRP | Peran / Jobdesk |
| :--- | :---: | :--- |
| **Aswalia Novitriasari** (Nopi) | 5027231012 | **Tugas 1 & 2 (Foundation)**: Membuat file manifes namespace (`dev` & `prod`), `deployment.yaml` & `service.yaml`, melakukan deploy awal, serta menyusun skrip otomatisasi `deploy.sh`. |
| **Riskiyatul Nur Oktarani** (Yatun) | 5027231013 | **Tugas 6 (Namespace Isolation)**: Melakukan pengujian isolasi namespace `dev` & `prod` serta mendokumentasikan hasilnya di berkas `docs/insiden-3-rollback.md`. |
| **Rafika Az Zahra Kusumastuti** (Pika) | 5027231050 | **Tugas 3 (Self-Healing)**: Mensimulasikan pemulihan otomatis saat Pod crash/dihapus (Insiden 1) dan mendokumentasikannya di berkas `docs/insiden-1-selfhealing.md`. |
| **Nisrina Atiqah Dwiputri Ridzki** (Tika) | 5027231075 | **Tugas 4 (Rolling Update)**: Mensimulasikan pembaruan versi aplikasi tanpa downtime (Insiden 2) dan mendokumentasikannya di berkas `docs/insiden-2-rolling-update.md`. |
| **Hasan** | 5027231073 | **Tugas 5 (Rollback)**: Melakukan pengujian rollback cepat menggunakan perintah `rollout undo` (Insiden 3) dan mendokumentasikannya di berkas `docs/insiden-3-rollback.md`. |
| **Farand Febriansyah** | 5027231084 | **Tugas 7 (CI/CD Setup)**: Mengonfigurasi kebutuhan teknis GitHub Actions, ekspor kubeconfig Minikube ke base64 GitHub Secret, dan menambahkan job deploy ke `.github/workflows/ci.yml`. |
| **M. Abhinaya Al Faruqi** | 50272231011 | **Tugas 7 (Testing & Docs)**: Menguji pipeline end-to-end (push kode → auto-update Kubernetes), finalisasi `README.md`, serta mendokumentasikan analisis di `docs/cicd-ke-kubernetes.md`. |

---

## 📂 Struktur Repositori

```text
devops-kubernetes-kelompok-4/
├── README.md                        ← Panduan ini (Anggota kelompok, Cara menjalankan & verifikasi)
├── .github/
│   └── workflows/
│       └── ci.yml                   ← Pipeline CI/CD Auto-Deploy
├── kubernetes/
│   ├── namespace-dev.yaml           ← Konfigurasi Namespace Development
│   ├── namespace-prod.yaml          ← Konfigurasi Namespace Production
│   ├── deployment.yaml              ← Konfigurasi Deployment Aplikasi
│   └── service.yaml                 ← Konfigurasi Service NodePort
├── scripts/
│   ├── export-kubeconfig.sh         ← Export kubeconfig Minikube ke base64
│   └── verify-deployment.sh         ← Verifikasi status deployment di Kubernetes
├── deploy.sh                        ← Skrip setup otomatis sekali jalan
└── docs/
    ├── images/
    │   ├── output-deploy-sh.png     ← Screenshot output deploy.sh
    │   ├── output-get-all.png       ← Screenshot output get all
    │   ├── output-get-namespaces.png← Screenshot output get namespaces
    │   ├── output-curl.png          ← Screenshot output curl
    │   └── output-github-actions.png← Screenshot output github actions
    ├── insiden-1-selfhealing.md     ← Dokumentasi Pengujian Self-Healing
    ├── insiden-2-rolling-update.md  ← Dokumentasi Pengujian Rolling Update
    ├── insiden-3-rollback.md        ← Dokumentasi Pengujian Rollback & Isolasi Namespace
    └── cicd-ke-kubernetes.md        ← Dokumentasi Pipeline CI/CD ke Kubernetes
```

---

## 🛠️ Prasyarat (Prerequisites)

Sebelum menjalankan deployment, pastikan Anda telah menginstal tools berikut di komputer lokal Anda:
1. **Docker Desktop** (Pastikan statusnya aktif)
2. **Minikube** ([Instalasi Minikube](https://minikube.sigs.k8s.io/docs/start/))
3. **Kubectl** (CLI untuk berinteraksi dengan cluster Kubernetes)

---

## 🚀 Langkah-Langkah Menjalankan Deployment

### 1. Jalankan Cluster Minikube
Aktifkan cluster lokal dengan alokasi resource minimum:
```bash
minikube start --driver=docker --cpus=2 --memory=4096
```

### 2. Deploy ke Kubernetes
Anda bisa melakukan deployment secara otomatis menggunakan skrip `deploy.sh` atau menjalankannya secara manual.

#### Opsi A: Menggunakan Skrip Otomatis (`deploy.sh`)
Jika Anda menggunakan **Git Bash**, **WSL**, atau **Linux/macOS Terminal**, jalankan perintah berikut:
```bash
# Berikan izin akses eksekusi (jika diperlukan)
chmod +x deploy.sh

# Jalankan skrip deploy
./deploy.sh
```

#### Opsi B: Menggunakan PowerShell Manual (Windows)
Jika Anda menggunakan **Windows PowerShell** dan tidak memiliki Git Bash, jalankan perintah berikut baris demi baris:
```powershell
# 1. Buat namespace dev dan prod
kubectl apply -f kubernetes/namespace-dev.yaml
kubectl apply -f kubernetes/namespace-prod.yaml

# 2. Deploy aplikasi dan service ke namespace production (taskflow-prod)
kubectl apply -f kubernetes/deployment.yaml -n taskflow-prod
kubectl apply -f kubernetes/service.yaml -n taskflow-prod

# 3. Tunggu hingga deployment selesai
kubectl rollout status deployment/taskflow-api -n taskflow-prod
```

---

## 🔍 Verifikasi Deployment

Untuk memastikan seluruh resource telah berjalan dengan benar di namespace `taskflow-prod`, jalankan perintah:
```bash
kubectl get all -n taskflow-prod
```

**Output yang Diharapkan:**
* Pods `taskflow-api-*` dalam status `Running` (2/2 replicas).
* Service `taskflow-api` tipe `NodePort` aktif dengan port internal `80` dan NodePort `30080`.
* Deployment `taskflow-api` dengan status `AVAILABLE` bernilai `2`.

---

## 🌐 Mengakses Aplikasi

Setelah semua resource berjalan, Anda dapat mengakses aplikasi TaskFlow dengan metode berikut:

### Opsi 1: Menggunakan URL Layanan Minikube
Dapatkan URL langsung yang dihasilkan oleh Minikube untuk mengakses Service:
```bash
minikube service taskflow-api -n taskflow-prod --url
```

### Opsi 2: Menggunakan IP Node Minikube
Dapatkan IP Minikube Anda:
```bash
minikube ip
```
Akses aplikasi melalui browser atau `curl` dengan alamat:
`http://<MINIKUBE_IP>:30080` (Contoh: `http://192.168.49.2:30080`)

### Opsi 3: Port Forwarding (Khusus Windows jika Opsi 1 & 2 tidak dapat diakses)
Jika IP Minikube tidak dapat diakses secara langsung dari host Windows Anda, jalankan port forwarding di terminal terpisah:
```bash
kubectl port-forward service/taskflow-api 30081:80 -n taskflow-prod
```
Akses aplikasi melalui browser atau `curl` di alamat:
`http://localhost:30081`

---
 
## 🧪 Dokumentasi Pengujian Insiden
 
Berikut adalah hasil pengujian ketiga insiden produksi utama yang dibuktikan dengan Kubernetes:
 
### Insiden 1: Self-Healing (Tugas 3)
 
> 📄 Dokumentasi lengkap: [docs/insiden-1-selfhealing.md](docs/insiden-1-selfhealing.md)
 
Kubernetes terbukti mampu memulihkan Pod yang crash secara otomatis tanpa intervensi manual. Saat salah satu Pod dihapus secara paksa, Kubernetes langsung membuat Pod pengganti dalam waktu **± 4 detik**, jauh lebih cepat dibandingkan cara lama yang membutuhkan menit hingga jam.
 
| Aspek | Cara Lama | Dengan Kubernetes |
|-------|-----------|-------------------|
| Deteksi masalah | Manual / menunggu laporan | Otomatis dalam hitungan detik |
| Waktu recovery | Menit hingga jam | **± 4 detik** |
| Intervensi manusia | Wajib | Tidak diperlukan |
 
### Insiden 2: Rolling Update Tanpa Downtime (Tugas 4)
 
> 📄 Dokumentasi lengkap: [docs/insiden-2-rolling-update.md](docs/insiden-2-rolling-update.md)
 
Pembaruan versi aplikasi dilakukan tanpa satu pun request yang gagal. Dengan konfigurasi `maxUnavailable: 0`, Kubernetes memastikan selalu ada Pod aktif selama proses update berlangsung.
 
### Insiden 3: Rollback Cepat & Isolasi Namespace (Tugas 5 & 6)
 
> 📄 Dokumentasi lengkap: [docs/insiden-3-rollback.md](docs/insiden-3-rollback.md)
 
Rollback ke versi sebelumnya selesai dalam **< 60 detik** hanya dengan satu perintah `kubectl rollout undo`. Pengujian isolasi namespace juga membuktikan bahwa gangguan di `taskflow-dev` sama sekali tidak mempengaruhi `taskflow-prod`.
 
---
 
## 🔄 CI/CD Pipeline (Tugas 7)
 
> 📄 Dokumentasi lengkap: [docs/cicd-ke-kubernetes.md](docs/cicd-ke-kubernetes.md)
 
Pipeline GitHub Actions melakukan **auto-deploy ke Kubernetes** setiap kali ada push ke branch `main`. Workflow memiliki 3 jobs: **VALIDATE** → **DEPLOY** → **NOTIFY**.

### Setup GitHub Actions

1. **Export kubeconfig ke base64:**
   ```bash
   ./scripts/export-kubeconfig.sh
   ```

2. **Add GitHub Secret `KUBECONFIG_BASE64`:**
   - Go to GitHub Settings → Secrets and variables → Actions
   - New repository secret
   - Name: `KUBECONFIG_BASE64`
   - Value: Paste base64 dari script output

3. **Verifikasi deployment:**
   ```bash
   ./scripts/verify-deployment.sh
   ```

### Helper Scripts

- **`scripts/export-kubeconfig.sh`** - Export kubeconfig ke base64
- **`scripts/verify-deployment.sh`** - Verify deployment status

### Troubleshooting

| Issue | Solusi |
|-------|--------|
| Secret not found | Verifikasi `KUBECONFIG_BASE64` di GitHub Settings |
| Cannot connect | `minikube stop && minikube start`, re-export kubeconfig |
| Deployment timeout | Check logs: `kubectl logs deployment/taskflow-api -n taskflow-prod` |

---

## ✅ Ringkasan Verifikasi

Berikut status verifikasi akhir dari seluruh komponen project:

| Komponen | Status | Penanggung Jawab |
|----------|--------|------------------|
| Namespace `dev` & `prod` | ✅ Aktif | Nopi (Tugas 1 & 2) |
| Deployment & Service | ✅ 2/2 Pods Running | Nopi (Tugas 1 & 2) |
| Self-Healing | ✅ Recovery < 4 detik | Pika (Tugas 3) |
| Rolling Update | ✅ Zero downtime | Tika (Tugas 4) |
| Rollback | ✅ < 60 detik | Hasan (Tugas 5) |
| Namespace Isolation | ✅ Terisolasi | Yatun (Tugas 6) |
| CI/CD Pipeline | ✅ 3 Jobs Pass | Farand & Abhinaya (Tugas 7) |
| Dokumentasi | ✅ Lengkap | Seluruh anggota |

---

*Terakhir diperbarui: 31 Mei 2026 — Difinalisasi oleh M. Abhinaya Al Faruqi*
