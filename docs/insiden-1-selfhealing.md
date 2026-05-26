# Insiden 1 — Self-Healing dengan Kubernetes

*(Tugas 3 — Rafika Az Zahra Kusumastuti)*

---

## Deskripsi Insiden

**Skenario lama:**
Sebelum menggunakan Kubernetes, jika sebuah container/pod tiba-tiba crash atau mati di tengah malam, tidak ada yang mengetahuinya. Pengguna akan terus mendapatkan error hingga ada engineer yang menyadari dan melakukan restart secara manual — proses yang bisa memakan waktu berjam-jam.

**Kenapa insiden ini tidak akan terjadi lagi dengan Kubernetes?**

Kubernetes memiliki mekanisme **self-healing** bawaan melalui objek **Deployment**. Deployment secara terus-menerus memantau jumlah Pod yang berjalan dan membandingkannya dengan nilai `replicas` yang didefinisikan di YAML. Ketika sebuah Pod mati atau dihapus, Kubernetes secara otomatis membuat Pod baru **tanpa memerlukan intervensi manusia**. Proses ini terbukti selesai hanya dalam hitungan detik.

---

## Langkah Demonstrasi

### Persiapan: Cek Pod yang Berjalan

```bash
kubectl get pods -n taskflow-prod
```

**Output sebelum demo:**
```
NAME                           READY   STATUS    RESTARTS   AGE
taskflow-api-c7bd86f95-lx72b   1/1     Running   0          73s
taskflow-api-c7bd86f95-x4q2v   1/1     Running   0          73s
```

---

### Terminal 1 — Pantau Pod Secara Real-Time

```bash
kubectl get pods -n taskflow-prod -w
```

**Output Terminal 1 (hasil demo):**
```
NAME                           READY   STATUS              RESTARTS   AGE
taskflow-api-c7bd86f95-lx72b   1/1     Running             0          73s
taskflow-api-c7bd86f95-x4q2v   1/1     Running             0          73s
taskflow-api-c7bd86f95-lx72b   1/1     Terminating         0          96s
taskflow-api-c7bd86f95-lx72b   1/1     Terminating         0          96s
taskflow-api-c7bd86f95-jqmpn   0/1     Pending             0          0s
taskflow-api-c7bd86f95-jqmpn   0/1     Pending             0          0s
taskflow-api-c7bd86f95-jqmpn   0/1     ContainerCreating   0          0s
taskflow-api-c7bd86f95-lx72b   0/1     Error               0          97s
taskflow-api-c7bd86f95-lx72b   0/1     Error               0          98s
taskflow-api-c7bd86f95-jqmpn   1/1     Running             0          4s
```

> **"C:\Users\Pengguna\Pictures\Screenshots\Screenshot 2026-05-26 150349.png"**

---

### Terminal 2 — Hapus Salah Satu Pod

```bash
kubectl delete pod taskflow-api-c7bd86f95-lx72b -n taskflow-prod
```

**Output:**
```
pod "taskflow-api-c7bd86f95-lx72b" deleted
```

> **"C:\Users\Pengguna\Pictures\Screenshots\Screenshot 2026-05-26 150357.png"**

---

## Catatan Waktu Recovery

| Event | Waktu (AGE) | Keterangan |
|-------|-------------|------------|
| Pod lama dalam status `Running` | AGE 73s | Kondisi normal sebelum demo |
| Pod dihapus → masuk `Terminating` | AGE 96s | Perintah `kubectl delete pod` dijalankan |
| Pod baru masuk `Pending` → `ContainerCreating` | AGE 96s | Kubernetes langsung merespons (0 detik setelah delete) |
| Pod baru masuk `Running` | AGE 100s (96s + 4s) | Pod pengganti siap melayani request |
| **Total durasi recovery** | **± 4 detik** | Dari delete hingga pod baru Running |

---

## Verifikasi Setelah Self-Healing

```bash
kubectl get pods -n taskflow-prod
```

**Output setelah self-healing:**
```
NAME                           READY   STATUS    RESTARTS   AGE
taskflow-api-c7bd86f95-x4q2v   1/1     Running   0          ...   ← pod lama (tidak terganggu)
taskflow-api-c7bd86f95-jqmpn   1/1     Running   0          4s    ← pod BARU otomatis
```

Jumlah pod tetap 2 sesuai nilai `replicas: 2` di `deployment.yaml`.

---

## Perbandingan: Cara Lama vs Kubernetes

| Aspek | Cara Lama (Manual) | Dengan Kubernetes |
|-------|-------------------|-------------------|
| **Deteksi masalah** | Menunggu ada yang lapor / cek manual | Otomatis terdeteksi dalam hitungan detik |
| **Respons** | Engineer harus SSH ke server dan restart manual | Kubernetes langsung membuat Pod baru otomatis |
| **Waktu recovery** | Menit hingga jam (tergantung kapan disadari) | **± 4 detik** |
| **Kebutuhan intervensi** | Wajib ada orang yang masuk dan restart manual | Tidak perlu intervensi siapapun |
| **Risiko downtime** | Tinggi — pengguna terkena error selama proses | Sangat rendah — pod pengganti langsung dibuat |

---

## Kesimpulan

Demonstrasi di atas membuktikan bahwa Kubernetes menyelesaikan **Insiden 1 (container crash)** secara otomatis. Berbeda dengan pendekatan lama di mana harus ada orang yang menyadari masalah lalu masuk secara manual untuk restart, Kubernetes langsung membuat Pod pengganti tanpa intervensi siapapun.

Mekanisme ini bekerja karena Deployment terus menjaga **desired state** (`replicas: 2`). Begitu jumlah Pod yang aktif turun di bawah 2, Control Plane Kubernetes langsung menginstruksikan Worker Node untuk membuat Pod baru. Hasilnya, pengguna hampir tidak merasakan gangguan — recovery selesai hanya dalam **± 4 detik**.