# Insiden 3: Rollback Cepat & Isolasi Namespace

*(Tugas 5 oleh [Hasan] - Rollback)*

---

## Bagian 1: Pengujian Rollback Cepat

### Deskripsi Insiden
Terkadang, versi aplikasi terbaru (v2) yang di-deploy ke production memiliki bug kritis yang tidak terdeteksi di tahap testing. Cara lama mengharuskan kita mencari error, mematikan server, dan melakukan konfigurasi ulang secara manual untuk kembali ke versi stabil, yang mana memakan waktu lama dan membuat layanan terganggu. 

Dengan Kubernetes, kita bisa mengembalikan aplikasi ke kondisi stabil sebelumnya (v1) hanya dengan satu perintah yang dieksekusi dalam hitungan detik.

![alt text](<Screenshot 2026-05-28 000702.png>)

### Langkah Demonstrasi & Verifikasi

1. **Menjalankan Perintah Rollback**
   Perintah berikut dieksekusi untuk membatalkan update v2 dan kembali ke v1:
```
   kubectl rollout undo deployment/taskflow-api -n taskflow-prod
```

   ![alt text](<Screenshot 2026-05-28 001414.png>)


## Bagian 2: Pengujian Isolasi Namespace
### (Tugas 6 oleh [Riskiyatul Nur Oktarani 5027231013] - Isolasi Namespace)

### Deskripsi
Membuktikan bahwa namespace `taskflow-dev` dan `taskflow-prod` benar-benar
terisolasi. Gangguan apapun di namespace dev tidak akan mempengaruhi prod.

### Langkah Demonstrasi & Verifikasi

#### 1. Kondisi Awal — Kedua Namespace Aktif

```
kubectl get pods -n taskflow-prod
kubectl get pods -n taskflow-dev
curl http://localhost:8888
```
<img width="999" height="204" alt="WhatsApp Image 2026-05-30 at 15 07 25" src="https://github.com/user-attachments/assets/a5a5fa06-f29f-4372-a488-d7e75a424d54" />

<img width="1054" height="712" alt="WhatsApp Image 2026-05-30 at 15 07 15" src="https://github.com/user-attachments/assets/eff39fee-e257-4ed0-93b5-c9b2c725672a" />


#### 2. Melakukan Penghapusan Semua Pod di Namespace Dev

```
kubectl delete pods --all -n taskflow-dev
```

<img width="1012" height="236" alt="WhatsApp Image 2026-05-30 at 15 10 38" src="https://github.com/user-attachments/assets/c44eb20e-6dac-4cca-bd51-22acfe54d59e" />


#### 3. Verifikasi Prod Tetap Aman Setelah Dev Dihancurkan

```
kubectl get pods -n taskflow-prod
curl http://localhost:8888
```

<img width="1012" height="586" alt="image" src="https://github.com/user-attachments/assets/6c9a4923-16a5-42a0-82d9-8356e2483d2b" />

<img width="933" height="92" alt="image" src="https://github.com/user-attachments/assets/3120318e-cc79-43e4-8757-5824a2027e18" />

### Hasil Pengujian

| Aspek | Namespace Dev | Namespace Prod |
|-------|--------------|----------------|
| Status setelah penghapusan | Pod terhapus | Tetap Running |
| Akses aplikasi | Terganggu | Tetap StatusCode 200  |
| Pengaruh ke prod | — | Tidak ada sama sekali  |

---

### Kesimpulan
Namespace di Kubernetes memberikan isolasi penuh antar environment.
Penghapusan seluruh Pod di `taskflow-dev` tidak berdampak apapun pada
`taskflow-prod`. Dev dan prod aman dikelola dalam satu cluster yang sama.
