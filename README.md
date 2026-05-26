# TaskFlow — Kubernetes & Microservices (Kelompok 4)

Repositori ini berisi berkas konfigurasi Kubernetes dan skrip deployment untuk memindahkan aplikasi **TaskFlow Inc.** ke cluster Kubernetes (Minikube). Langkah ini diambil untuk mengatasi masalah downtime aplikasi, pembaruan (rolling update) lambat, dan proses rollback manual yang memakan waktu lama.

---

## 📂 Struktur Repositori

```text
devops-kubernetes-kelompok-4/
├── README.md                        ← Panduan ini (Cara menjalankan & verifikasi)
├── .github/
│   └── workflows/
│       └── ci.yml                   ← Pipeline CI/CD Auto-Deploy (Tugas Farand & Abhinaya)
├── kubernetes/
│   ├── namespace-dev.yaml           ← Konfigurasi Namespace Development (Tugas Nopi)
│   ├── namespace-prod.yaml          ← Konfigurasi Namespace Production (Tugas Nopi)
│   ├── deployment.yaml              ← Konfigurasi Deployment Aplikasi (Tugas Nopi)
│   └── service.yaml                 ← Konfigurasi Service NodePort (Tugas Nopi)
├── deploy.sh                        ← Skrip setup otomatis sekali jalan (Tugas Nopi)
└── docs/
    ├── insiden-1-selfhealing.md     ← Dokumentasi Pengujian Self-Healing (Tugas Pika)
    ├── insiden-2-rolling-update.md  ← Dokumentasi Pengujian Rolling Update (Tugas Tika)
    ├── insiden-3-rollback.md        ← Dokumentasi Pengujian Rollback & Isolasi (Tugas Hasan & Yatun)
    └── cicd-ke-kubernetes.md        ← Dokumentasi Pipeline CI/CD ke Kubernetes (Tugas Abhinaya)
```

---

## 🛠️ Prasyarat (Prerequisites)

Sebelum menjalankan deployment, pastikan Anda telah menginstal tools berikut di komputer lokal Anda:
1. **Docker Desktop** (Pastikan sudah aktif)
2. **Minikube** ([Instalasi Minikube](https://minikube.sigs.k8s.io/docs/start/))
3. **Kubectl** (CLI untuk mengelola Kubernetes)

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
