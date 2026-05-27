# Insiden 2: Rolling Update Tanpa Downtime dengan Kubernetes

*(Tugas 4 oleh Nisrina Atiqah Dwiputri Ridzki)*

---

## Deskripsi Insiden

### Skenario Lama

Sebelum menggunakan Kubernetes, proses deployment versi baru aplikasi biasanya menyebabkan downtime karena aplikasi harus dimatikan terlebih dahulu sebelum versi baru dijalankan. Selama proses update berlangsung, pengguna tidak dapat mengakses layanan dan sering mendapatkan error hingga deployment selesai.

### Kenapa Insiden Ini Tidak Akan Terjadi Lagi dengan Kubernetes?

Kubernetes memiliki mekanisme **Rolling Update** yang memungkinkan proses pembaruan aplikasi dilakukan secara bertahap tanpa menghentikan seluruh layanan. Kubernetes akan membuat Pod baru terlebih dahulu dan memastikan Pod tersebut siap menerima request sebelum Pod lama dimatikan.

Dengan konfigurasi:

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1
    maxUnavailable: 0
````

Kubernetes menjamin bahwa selalu ada minimal satu Pod aktif yang melayani request pengguna selama proses update berlangsung, sehingga aplikasi tetap dapat diakses tanpa downtime.

---

## Langkah Demonstrasi

### Persiapan: Verifikasi Deployment Berjalan

```bash
kubectl get all -n taskflow-prod
```

### Output sebelum demo:

```text
NAME                                READY   STATUS    RESTARTS   AGE
pod/taskflow-api-74cbdfbdd6-f5kn9   1/1     Running   0          44s
pod/taskflow-api-74cbdfbdd6-kntpz   1/1     Running   0          44s

NAME                   TYPE       CLUSTER-IP     EXTERNAL-IP   PORT(S)        AGE
service/taskflow-api   NodePort   10.111.36.81   <none>        80:30080/TCP   36s

NAME                           READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/taskflow-api   2/2     2            2           44s

NAME                                      DESIRED   CURRENT   READY   AGE
replicaset.apps/taskflow-api-74cbdfbdd6   2         2         2       44s
```

> screenshot verifikasi deployment 

---

## Terminal 1 — Loop Request Secara Terus-Menerus

Untuk membuktikan bahwa aplikasi tetap dapat diakses selama update berlangsung, dilakukan request terus-menerus menggunakan loop berikut:

```powershell
while ($true) {
  $response = curl.exe -s -o NUL -w "%{http_code}" http://localhost:30081
  Write-Host "$(Get-Date -Format HH:mm:ss) — HTTP $response"
  Start-Sleep -Milliseconds 500
}
```

### Output Terminal 1

```text
21:18:34 — HTTP 200
21:18:35 — HTTP 200
21:18:35 — HTTP 200
21:18:36 — HTTP 200
21:18:36 — HTTP 200
21:18:37 — HTTP 200
21:18:37 — HTTP 200
21:18:38 — HTTP 200
21:18:39 — HTTP 200
21:18:39 — HTTP 200
21:18:40 — HTTP 200
21:18:40 — HTTP 200
21:18:41 — HTTP 200
21:18:42 — HTTP 200
21:18:42 — HTTP 200
21:18:43 — HTTP 200
21:18:43 — HTTP 200
21:18:44 — HTTP 200
21:18:44 — HTTP 200
21:18:45 — HTTP 200
21:18:45 — HTTP 200
21:18:46 — HTTP 200
21:18:46 — HTTP 200
21:18:47 — HTTP 200
21:18:48 — HTTP 200
21:18:48 — HTTP 200
21:18:49 — HTTP 200
21:18:49 — HTTP 200
```

Selama proses rolling update berlangsung, tidak ada satu pun request yang gagal ataupun menampilkan error seperti HTTP 503 atau HTTP 000.

> screenshot Terminal 1 

---

## Terminal 2 — Rolling Update ke Versi Baru

Dilakukan perubahan pada file `deployment.yaml` untuk mensimulasikan update aplikasi dari versi lama ke versi baru.

### Sebelum Update

```yaml
args:
  - "-text=Halo dari TaskFlow v1!"
```

### Setelah Update

```yaml
args:
  - "-text=Halo dari TaskFlow v2! Fitur baru!"
```

Setelah file diperbarui, deployment di-apply kembali menggunakan perintah berikut:

```bash
kubectl apply -f kubernetes/deployment.yaml -n taskflow-prod
```

Kemudian status rollout dipantau menggunakan:

```bash
kubectl rollout status deployment/taskflow-api -n taskflow-prod
```

### Output Terminal 2

```text
deployment.apps/taskflow-api configured
deployment "taskflow-api" successfully rolled out
```

> screenshot Terminal 2 

---

## Terminal 3 — Port Forwarding

Karena NodePort Minikube tidak dapat diakses langsung dari host Windows, dilakukan port forwarding agar service dapat diakses melalui localhost.

```bash
kubectl port-forward service/taskflow-api 30081:80 -n taskflow-prod
```

### Output

```text
Forwarding from 127.0.0.1:30081 -> 8080
Forwarding from [::1]:30081 -> 8080
```

> screenshot Terminal 3

---

## Verifikasi Setelah Rolling Update

Untuk memastikan update berhasil, dilakukan pengecekan endpoint aplikasi:

```bash
curl http://localhost:30081
```

### Output

```text
Halo dari TaskFlow v2! Fitur baru!
```

Hal ini membuktikan bahwa deployment berhasil berpindah dari versi v1 ke v2 tanpa downtime.

> screenshot hasil verifikasi v2 

---

## Hasil Pengamatan

Selama proses rolling update berlangsung:

* Seluruh request tetap mendapatkan response `HTTP 200`
* Tidak ditemukan downtime
* Tidak ada error seperti `HTTP 503` atau `HTTP 000`
* Aplikasi tetap dapat diakses selama deployment berlangsung
* Kubernetes melakukan update secara bertahap dengan membuat Pod baru terlebih dahulu sebelum mematikan Pod lama

---

## Perbandingan: Cara Lama vs Kubernetes

| Aspek                 | Cara Lama (Manual)              | Dengan Kubernetes        |
| --------------------- | ------------------------------- | ------------------------ |
| Downtime saat deploy  | Ada                             | Tidak ada                |
| Cara update aplikasi  | Stop aplikasi lalu deploy ulang | Rolling update otomatis  |
| Risiko request gagal  | Tinggi                          | Sangat rendah            |
| Ketersediaan aplikasi | Bisa terputus selama update     | Tetap tersedia           |
| Intervensi manusia    | Banyak langkah manual           | Otomatis oleh Kubernetes |

---

## Kesimpulan

Demonstrasi di atas membuktikan bahwa Kubernetes berhasil menyelesaikan masalah downtime saat deployment aplikasi menggunakan mekanisme **Rolling Update**.

Berbeda dengan pendekatan lama di mana aplikasi harus dimatikan terlebih dahulu sebelum versi baru dijalankan, Kubernetes memastikan selalu ada Pod aktif yang melayani request pengguna selama proses update berlangsung.

Dengan konfigurasi `maxUnavailable: 0`, seluruh request tetap mendapatkan response `HTTP 200` tanpa gangguan sedikit pun. Hal ini menunjukkan bahwa rolling update Kubernetes mampu menjaga availability aplikasi tetap tinggi selama deployment berlangsung.

