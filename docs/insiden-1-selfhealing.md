# Insiden 1: Self-Healing dengan Kubernetes

*(Tugas 3 oleh Rafika Az Zahra Kusumastuti)*

---

## Deskripsi Insiden

**Skenario lama:**
Sebelum menggunakan Kubernetes, jika sebuah container atau pod tiba-tiba crash atau mati di tengah malam, tidak ada yang mengetahuinya. Pengguna akan terus mendapatkan error hingga ada engineer yang menyadari dan melakukan restart secara manual, sebuah proses yang bisa memakan waktu berjam-jam.

**Kenapa insiden ini tidak akan terjadi lagi dengan Kubernetes?**

Kubernetes memiliki mekanisme **self-healing** bawaan melalui objek **Deployment**. Deployment secara terus-menerus memantau jumlah Pod yang berjalan dan membandingkannya dengan nilai `replicas` yang didefinisikan di YAML. Ketika sebuah Pod mati atau dihapus, Kubernetes secara otomatis membuat Pod baru **tanpa memerlukan intervensi manusia**. Proses ini terbukti selesai hanya dalam hitungan detik.

---

## Langkah Demonstrasi

### Persiapan: Cek Pod yang Berjalan

```bash
kubectl get all -n taskflow-prod
```

**Output sebelum demo:**
```
NAME                                       READY   STATUS    RESTARTS   AGE
pod/taskflow-api-c7bd86f95-lx72b           1/1     Running   0          23s
pod/taskflow-api-c7bd86f95-x4q2v           1/1     Running   0          23s

NAME                   TYPE       CLUSTER-IP       EXTERNAL-IP   PORT(S)        AGE
service/taskflow-api   NodePort   10.111.133.213   <none>        80:30080/TCP   17s

NAME                           READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/taskflow-api   2/2     2            2           23s

NAME                                     DESIRED   CURRENT   READY   AGE
replicaset.apps/taskflow-api-c7bd86f95   2         2         2       23s
```

> **<img width="890" height="330" alt="Screenshot 2026-05-26 152100" src="https://github.com/user-attachments/assets/aad4d8f1-faf7-499a-83e4-7f31322aab3f" />**

---

### Terminal 1: Pantau Pod Secara Real-Time

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

> **<img width="911" height="341" alt="Screenshot 2026-05-26 150349" src="https://github.com/user-attachments/assets/12451da2-af14-4851-8255-72bfa0a3f084" />**

---

### Terminal 2: Hapus Salah Satu Pod

```bash
kubectl delete pod taskflow-api-c7bd86f95-lx72b -n taskflow-prod
```

**Output:**
```
pod "taskflow-api-c7bd86f95-lx72b" deleted
```

> **<img width="862" height="90" alt="Screenshot 2026-05-26 150357" src="https://github.com/user-attachments/assets/56f0eab8-99fc-4d08-8e0a-d70e4c39bd64" />**

---

## Catatan Waktu Recovery

| Event | Waktu (AGE) | Keterangan |
|-------|-------------|------------|
| Pod lama dalam status `Running` | AGE 73s | Kondisi normal sebelum demo |
| Pod dihapus dan masuk `Terminating` | AGE 96s | Perintah `kubectl delete pod` dijalankan |
| Pod baru masuk `Pending` lalu `ContainerCreating` | AGE 96s | Kubernetes langsung merespons, 0 detik setelah delete |
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
taskflow-api-c7bd86f95-jqmpn   1/1     Running   0          17m   (pod BARU yang dibuat otomatis)
taskflow-api-c7bd86f95-x4q2v   1/1     Running   0          18m   (pod lama yang tidak terganggu)
```

Jumlah pod tetap 2 sesuai nilai `replicas: 2` di `deployment.yaml`.

> **<img width="865" height="116" alt="Screenshot 2026-05-26 151949" src="https://github.com/user-attachments/assets/7a968604-b33e-48ed-84c1-2cde7ce1d39f" />**

---

## Perbandingan: Cara Lama vs Kubernetes

| Aspek | Cara Lama (Manual) | Dengan Kubernetes |
|-------|-------------------|-------------------|
| **Deteksi masalah** | Menunggu ada yang lapor atau cek manual | Otomatis terdeteksi dalam hitungan detik |
| **Respons** | Engineer harus SSH ke server dan restart manual | Kubernetes langsung membuat Pod baru secara otomatis |
| **Waktu recovery** | Menit hingga jam tergantung kapan disadari | **± 4 detik** |
| **Kebutuhan intervensi** | Wajib ada orang yang masuk dan restart manual | Tidak perlu intervensi siapapun |
| **Risiko downtime** | Tinggi karena banyak langkah manual | Sangat rendah karena pod pengganti langsung dibuat |

---

## Kesimpulan

Demonstrasi di atas membuktikan bahwa Kubernetes menyelesaikan **Insiden 1 (container crash)** secara otomatis. Berbeda dengan pendekatan lama di mana harus ada orang yang menyadari masalah lalu masuk secara manual untuk restart, Kubernetes langsung membuat Pod pengganti tanpa intervensi siapapun.

Mekanisme ini bekerja karena Deployment terus menjaga **desired state** (`replicas: 2`). Begitu jumlah Pod yang aktif turun di bawah 2, Control Plane Kubernetes langsung menginstruksikan Worker Node untuk membuat Pod baru. Hasilnya, pengguna hampir tidak merasakan gangguan karena recovery selesai hanya dalam **± 4 detik**.
