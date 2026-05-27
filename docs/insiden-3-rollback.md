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
   ```bash
   kubectl rollout undo deployment/taskflow-api -n taskflow-prod

   ![alt text](<Screenshot 2026-05-28 001414.png>)