# Fieldline — Field Inventory & Edge AI

Ứng dụng **kiểm kê tài sản hiện trường** viết bằng Flutter. App quét mã QR/Barcode, nhận diện thiết bị và khoanh vùng hư hỏng **ngay trên máy** bằng YOLO (TFLite), lập phiếu kiểm kê **ngoại tuyến** (Isar), ký xác nhận, tự đồng bộ lên **Supabase** khi có mạng và xuất **báo cáo PDF A4**. Bản **web** là trung tâm quản lý dữ liệu.

> Đồ án cuối kỳ môn **Phát triển ứng dụng đa nền tảng**.

---

## Tính năng chính

### App hiện trường (iOS / Android / macOS)
- **Đăng nhập / đăng ký** bằng Supabase Auth. Phiên đăng nhập được giữ trên máy, nên sau lần đầu vẫn vào app được khi ngoại tuyến.
- **Quét mã** QR / EAN / UPC / Code128/39/93 / DataMatrix / PDF417. Hỗ trợ đèn flash, đổi camera, **nhập mã thủ công** khi camera lỗi.
- **Edge AI trên màn Quét**: YOLOv8s chạy trên thiết bị và nhận diện **9 lớp**:
  - Thiết bị: Tủ điện, Aptomat, Ghế, Bàn, Máy chiếu
  - Hư hỏng: Vết nứt, Gỉ sét, Thấm nước, Khuyết tật kim loại

  AI đọc phần ảnh **trong khung xanh** và vẫn chạy khi không thấy mã QR. Thẻ **chẩn đoán AI** hiển thị thời gian xử lý và phần cứng đang dùng (GPU/CPU).
- **Phân vùng hư hỏng trên ảnh minh chứng (Android/iOS)**: trong **Lập phiếu kiểm kê → Ảnh minh chứng**, thêm ảnh rồi chạm vào ảnh để xem AI khoanh vùng **vết nứt, thấm mốc, bong sơn và gỉ sét**. Ảnh minh chứng gốc vẫn được dùng khi lưu phiếu và xuất PDF.
- **Phiếu kiểm kê**: tên tài sản, loại, khu vực, vị trí, tình trạng, số lượng, ghi chú, **ảnh minh chứng** (`image_picker`). Phiếu chưa ký được lưu thành **bản nháp**: bản nháp không đồng bộ, không vào báo cáo, có thể mở lại để ký hoặc xoá.
- **Ký xác nhận** trên canvas (lưu tên và chức vụ người ký), xuất ảnh PNG.
- **Offline-first**: mọi phiếu lưu vào Isar trước.
- **Tự động đồng bộ** phiếu đã ký khi có mạng (debounce 3 giây, retry lùi dần từ 30 giây đến tối đa 5 phút). Có thể đồng bộ tay ở màn Đồng bộ.
- **Danh mục tài sản**: thêm/sửa tài sản, lọc theo khu vực, xuất danh sách PDF. Khi máy và cloud sửa cùng một tài sản, app hiện **màn đối chiếu** để chọn giữ bản nào.
- **Tổng quan & Báo cáo**: số liệu thật, chọn kỳ báo cáo theo tháng, xem trước PDF nhiều trang trước khi chia sẻ.
- **Địa điểm & Cài đặt**: thống kê theo khu vực, cấu hình đồng bộ.

### Bản web (trung tâm quản lý — Card 28)
- Đọc/ghi trực tiếp trên Supabase, không dùng Isar.
- Không có chức năng quét, lập phiếu, ký hay đồng bộ ngoại tuyến. Các route `/scanner`, `/audit-form`, `/signature`, `/sync` tự chuyển về trang chủ.

## Tech stack

| Mảng | Công nghệ |
|---|---|
| Framework | Flutter (Dart `^3.13.4`) |
| State | `flutter_riverpod` + `riverpod_generator` |
| Routing | `go_router` (auth redirect, `ShellRoute`) |
| Camera / Scanner | `mobile_scanner` 7.4.2 (**bản vá cục bộ** trong `third_party/`), `permission_handler` |
| Edge AI | `tflite_flutter` — YOLOv8s nhận diện ở màn Quét và YOLOv8n-seg V3 phân vùng ảnh minh chứng, đầu vào 640×640 |
| Local DB | `isar_plus` |
| Backend | `supabase_flutter` (Postgres + RLS, Auth, Storage) |
| Mạng | `connectivity_plus`, `http` |
| PDF | `pdf`, `printing` |
| Khác | `signature`, `image_picker`, `shared_preferences`, `flex_color_scheme`, `google_fonts`, `fpdart`, `freezed` |

## Kiến trúc

Dự án theo **Clean Architecture, chia theo feature**: `domain` (entity, abstract repository, use case) → `data` (model, repository impl) → `presentation` (controller, screen, widget).

```
lib/
├── main.dart                     # Khởi tạo Supabase; mobile: Isar, web: console overrides
├── core/
│   ├── ai_pipeline/ai_config.dart    # Đường dẫn model, inputSize, ngưỡng tin cậy
│   ├── database/local_db_init.dart   # initIsar() + isarInstanceProvider
│   ├── network/                      # supabase_config (không commit), provider, connectivity
│   ├── platform/app_mode.dart        # AppMode.field (mobile) / AppMode.console (web)
│   ├── router/app_router.dart        # GoRouter + auth guard
│   ├── theme/fieldline_theme.dart    # Theme "Fieldline" (theo Figma)
│   ├── utils/                        # pdf_report_generator, responsive_layout
│   └── widgets/                      # FieldlineShell (navigation), widget dùng chung
└── features/
    ├── auth/              # Supabase Auth, màn đăng nhập/đăng ký, tài khoản
    ├── edge_vision/       # Scanner, chẩn đoán AI và phân vùng ảnh minh chứng
    ├── offline_audit/     # Phiếu kiểm kê, Isar, ảnh minh chứng, sync & auto-sync
    ├── canvas_signature/  # Ký xác nhận
    ├── asset_catalog/     # Danh mục tài sản, editor, đối chiếu xung đột
    ├── report_dashboard/  # Tổng quan, báo cáo, xem trước PDF
    ├── workspace/         # Địa điểm, Cài đặt
    └── cloud_console/     # Dữ liệu và overrides cho bản web

supabase/
├── migrations/            # Thay đổi schema theo thời gian
└── seed/assets_sample.sql # 5 tài sản mẫu

third_party/mobile_scanner/ # Bản vá mobile_scanner (xem PATCH_NOTES.md)
assets/models/              # Model màn Quét (~45 MB) và phân vùng V3 (~14 MB)
docs/kiem-thu/              # Biên bản kiểm thử thủ công
```

### Màn hình

Tất cả màn hình đều đã hoàn thành. App hiện trường (iOS / Android / macOS) có đủ 9 nhóm màn. Bản web là trung tâm quản lý nên **cố ý không có** 4 màn làm việc ngoài hiện trường: router tự chuyển các route này về trang chủ (`fieldOnlyPaths` trong `lib/core/platform/app_mode.dart`).

| Route | Màn hình | App hiện trường | Bản web |
|---|---|:-:|:-:|
| `/login`, `/register` | Đăng nhập / Đăng ký | ✅ | ✅ |
| `/` | Tổng quan | ✅ | ✅ |
| `/assets`, `/assets/new`, `/assets/:code` | Danh mục, thêm/sửa tài sản | ✅ | ✅ |
| `/reports`, `/reports/preview` | Báo cáo, xem trước PDF | ✅ | ✅ |
| `/locations`, `/settings` | Địa điểm, Cài đặt | ✅ | ✅ |
| `/scanner` | Quét mã + Edge AI | ✅ | — ¹ |
| `/audit-form` | Lập phiếu kiểm kê, phân vùng ảnh minh chứng trên Android/iOS | ✅ | — ² |
| `/signature` | Ký xác nhận | ✅ | — ² |
| `/sync`, `/sync/conflicts` | Đồng bộ, đối chiếu xung đột | ✅ | — ³ |

**—** = không dùng trên web theo thiết kế, không phải tính năng còn thiếu.
1. Trình duyệt không chạy được TFLite (cần `dart:ffi`), và việc quét cần camera của thiết bị hiện trường.
2. Phiếu phải lưu ngoại tuyến vào Isar trước rồi mới ký, mà bản web không dùng Isar.
3. Bản web đọc và ghi thẳng lên Supabase, không có dữ liệu ngoại tuyến cần đồng bộ.

### Pipeline Edge AI

#### Nhận diện ở màn Quét

- **Mô hình:** YOLOv8s từ `DinoResults.zip`, checkpoint `runs/finetune_best_bo_da_sua/weights/best.pt`, huấn luyện ở 640. Đã thay `assets/models/object_detection.tflite` bằng bản TFLite float32 xuất qua ONNX (Ultralytics 8.4.183, ONNX opset 13, onnx2tf 2.6.9).
  - Input: `1×3×640×640` (NCHW).
  - Output: `1×(4+9)×8400` gồm `cx, cy, w, h` theo pixel rồi đến điểm của từng lớp. Giữ nguyên thứ tự 9 lớp và nhãn tiếng Việt.
  - Theo `metrics_comparison.json` trong ZIP: trên cùng tập val đã sửa nhãn, mAP50-95 từ **0.6731 → 0.7614**, mAP50 từ **0.7838 → 0.8787**. Model mới trên tập test: mAP50 **0.8507**, mAP50-95 **0.6941**. Model cũ trong phép so sánh này là `best_before.pt` của ZIP.
  - Đã đối chiếu TFLite với checkpoint FP32 trên ảnh rỗng, đầu vào ngẫu nhiên và ảnh validation trong ZIP: sai lệch điểm lớp lớn nhất **0.00000385**. Đây là kiểm tra chuyển đổi, không phải phép đo độ chính xác ngoài hiện trường.
  - SHA256 checkpoint: `7bc8924a9619d60d4835bc71e4be853a554a94a76017bae0fe1a5b52b6785c2f`.
  - SHA256 TFLite: `6c10c23227faec7335d4049037a63b394ac39e75cda79ac7b2eaef4208fda6df`.
- **Phần cứng chạy:** iOS thử **GPU delegate Metal** (cho phép FP16) và chuyển sang CPU 4 luồng nếu khởi tạo GPU thất bại.
- **Tiền xử lý:** AI chỉ nhận ô vuông giữa khung hình, cạnh bằng 70% cạnh ngắn (`AiConfig.cropFraction`), khớp với khung xanh trên màn quét.
  - iOS: bản vá `mobile_scanner` cắt và thu nhỏ ô này về RGB 640×640 bằng CoreGraphics, gửi sang Dart qua khóa `aiInput`. Dart chỉ còn đổi mảng này sang tensor.
  - Nền tảng khác: giải mã JPEG bằng `dart:ui` (thu nhỏ ngay lúc giải mã), rồi cắt ô giữa.
- **Ngưỡng tin cậy:** `0.5` cho thiết bị, `0.7` cho nhóm hư hỏng (lớp 0, 1, 2, 5). Nhóm hư hỏng dùng ngưỡng cao hơn vì ma trận nhầm lẫn cho thấy các lớp này báo nhầm nhiều ở vùng nền.
- **Bảo vệ CPU:** nếu AI đang xử lý thì bỏ qua (drop) frame mới.
- **Bản vá `mobile_scanner` (iOS/macOS và Android):**
  1. Plugin gốc bỏ qua frame không có mã. Bản vá vẫn gửi frame (khoảng 2 frame/giây) để AI chạy được khi không có QR.
  2. iOS/macOS gửi kèm `aiInput` (ảnh 640×640 đã cắt theo khung quét) như mô tả ở trên.

  Chi tiết xem `third_party/mobile_scanner/PATCH_NOTES.md`.
  - Android cũng gửi ảnh khi không thấy mã (tối đa 2 khung/giây), dùng đường xử lý JPEG của Dart.
- **Hạn chế dữ liệu:** theo `training_data_info.json`, phần lớn nhãn (kể cả val/test) do AI tạo và chưa được người kiểm tra đầy đủ. Lớp Tủ điện chỉ có 61 đối tượng train, 5 val, 12 test; cần kiểm tra thêm bằng ảnh thực tế. Giữ ngưỡng nhận diện hiện tại cho đến khi có kết quả hiệu chỉnh trên thiết bị.

#### Phân vùng hư hỏng trên ảnh minh chứng

- **Model:** YOLOv8n-seg V3, huấn luyện 120 epoch ở kích thước 640. Checkpoint `fieldline/fieldline_retrain_120/weights/best.pt` trong `TrainDACN2V3.zip` được xuất qua ONNX opset 13 sang TFLite float32 và đóng gói tại `assets/models/damage_segmentation_v3.tflite`.
- **Sử dụng:** thêm hoặc chọn ảnh minh chứng trong form, sau đó chạm vào ảnh đã đính kèm. App chạy bằng CPU trong isolate, tô vùng dự đoán lên bản xem trước và hiển thị điểm tin cậy từng lớp. Suy luận chạy trên thiết bị Android/iOS.
- **Input/output:** RGB float32 `1×3×640×640` có đệm khi ảnh lệch tỉ lệ. Đầu ra `1×40×8400` chứa khung, điểm của 4 lớp và hệ số mask. Tensor `1×32×160×160` chứa các mask cơ sở. App lọc dự đoán từ 0,30, loại khung trùng theo từng lớp và dựng tối đa 20 vùng trên ảnh xem trước.
- **Kiểm tra chuyển đổi:** cả hai tensor đầu ra của TFLite đã được so với ONNX trên một ảnh mẫu. SHA-256 của file TFLite là `59c5f33e06321410ead12f6bfb48117c5fdccf2cab4c1d1878f358f16a7e1ad9`.
- **Mask AP50–95 trên tập test của V3:** vết nứt **9,6%**, thấm mốc **21,2%**, bong sơn **26,0%**, gỉ sét **29,9%**. Các chỉ số này đo chất lượng phân vùng trên tập test; người kiểm kê cần đối chiếu vùng AI tô với ảnh gốc.
- **Hướng phát triển:** hiệu chỉnh kích thước từ mốc trong ảnh để tính m/m², xác nhận khối lượng thi công và tính chi phí theo bảng đơn giá.

### Dữ liệu

**Isar — `AuditRecordModel`**

| Nhóm | Trường |
|---|---|
| Tài sản | `scanCode`, `assetName`, `aiDetectedLabel`, `quantity` |
| Vị trí & tình trạng | `area`, `location`, `condition`, `notes` |
| Ký xác nhận | `signatureBytes`, `signerName`, `signerRole` |
| Minh chứng | `photoFiles` |
| Đồng bộ | `signatureUrl`, `timestamp`, `isSynced` |

**Isar — `AssetModel`:** `name`, `category`, `area`, `location`, `quantity`, `status`, `lastAuditAt`, `updatedAt`, `isSynced`, cùng `baseJson` / `conflictJson` để đối chiếu 3 bên.

**Supabase**
- Bảng: `audit_records`, `assets`, `profiles`.
- Storage bucket: `signatures` (ảnh chữ ký), `evidence` (ảnh minh chứng).
- **RLS:** chỉ người đã đăng nhập mới truy cập được dữ liệu. Phiếu kiểm kê chỉ người tạo (`created_by`) được sửa.

## Cài đặt & chạy

### Yêu cầu
- Flutter SDK hỗ trợ Dart `>= 3.13.4`
- Xcode + CocoaPods (iOS/macOS); Android Studio + Android SDK (Android)
- Một project Supabase
- Máy thật để thử camera và AI (simulator không có camera)

### 1. Lấy mã nguồn & cài package

```bash
git clone https://github.com/longtapdanhcode/Finalterm_DANENTANG.git
cd Finalterm_DANENTANG
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

### 2. Cấu hình Supabase

```bash
cp lib/core/network/supabase_config.dart.example lib/core/network/supabase_config.dart
```

Điền `url` và `anonKey` (publishable key) lấy từ **Supabase Dashboard → Project Settings → API**. File `supabase_config.dart` đã nằm trong `.gitignore`, **không commit file này**.

Nếu để trống, app vẫn khởi động. Tuy nhiên đăng nhập là bắt buộc, nên để dùng app thật cần cấu hình đầy đủ.

### 3. Khởi tạo database

Bước này giả định bảng `public.audit_records` và bucket `signatures` (tạo ở Card 10) đã có sẵn. Sau đó chạy lần lượt các file trong `supabase/migrations/` theo thứ tự tên file, bằng Supabase CLI (`supabase db push`) hoặc dán vào SQL Editor:

| Migration | Nội dung |
|---|---|
| `20261024120000_add_audit_record_details` | Thêm `area`, `location`, `condition`, `notes` |
| `20261024150000_add_asset_name_and_signer` | Thêm `asset_name`, `signer_name`, `signer_role` |
| `20261026090000_create_assets` | Tạo bảng `assets` |
| `20261028090000_add_audit_evidence_photos` | Thêm `photo_urls` và bucket `evidence` |
| `20261030090000_auth_profiles_and_rls` | Tạo bảng `profiles`, thêm `created_by`, siết RLS theo tài khoản |

Nếu cần dữ liệu mẫu, chạy thêm `supabase/seed/assets_sample.sql`.

### 4. Chạy

```bash
flutter run                 # mobile / macOS (chế độ hiện trường)
flutter run -d chrome       # bản web (trung tâm quản lý)
```

## Lưu ý theo nền tảng

- **iOS:**
  - Impeller đã được tắt trong `Info.plist` (`FLTEnableImpeller = false`) để tránh màn hình camera bị đen. Khi chạy CLI có thể thêm `--no-enable-impeller`.
  - Đã khai báo quyền camera (`NSCameraUsageDescription`) và thư viện ảnh minh chứng (`NSPhotoLibraryUsageDescription`).
- **Android:**
  - Đã khai báo quyền `CAMERA` và `INTERNET` cho cả bản debug và release.
  - App dùng `compileSdk = 37`; cần cài Android SDK Platform 37.
  - Kotlin của `tflite_flutter` dùng JVM target 11 để khớp Java của plugin, không phụ thuộc JDK trên máy.
  - Tắt Kotlin incremental compilation để tránh lỗi cache khi project và Pub cache nằm ở hai ổ đĩa Windows khác nhau.
  - Các lỗi từng gặp ở Sprint 6 được lưu trong `docs/kiem-thu/sprint6-card19.md`.
- **Web:** không có camera, AI hay lưu ngoại tuyến (xem phần Bản web ở trên).

## Kiểm thử

```bash
flutter test
```

| Thư mục test | Phạm vi |
|---|---|
| `test/core/utils/` | PDF báo cáo, PDF danh sách tài sản, responsive layout |
| `test/features/auth/` | Luồng đăng nhập/đăng ký |
| `test/features/edge_vision/` | Use case xử lý mã quét, repository AI, màn quét, chẩn đoán AI |
| `test/features/offline_audit/` | Form, bản nháp, ảnh minh chứng, model cloud, sync, auto-sync |
| `test/features/asset_catalog/` | Model, merge/đối chiếu, các màn tài sản |
| `test/features/report_dashboard/` | Thống kê, chọn kỳ báo cáo, dashboard |
| `test/features/workspace/`, `cloud_console/` | Địa điểm, Cài đặt, bản web |
| `test/helpers/` | Fake cho auth và ảnh minh chứng |

Biên bản kiểm thử thủ công nằm trong `docs/kiem-thu/`.

## Lộ trình phát triển

| Sprint | Card | Nội dung |
|---|---|---|
| 1 | 1–3 | Dataset, cấu hình AI, xuất model TFLite |
| 2 | 4–6 | Khung Flutter + Clean Architecture, scanner, inference on-device |
| 3 | 7–9 | Isar offline-first, form kiểm kê, canvas chữ ký |
| 4 | 10–12 | Supabase Cloud Sync, PDF A4, UI responsive |
| 5 | 13 | Dọn dẹp mã nguồn, kiểm thử |
| 6 | 17–19 | Giao diện Fieldline (Figma), trạng thái mạng thật, tên tài sản & người ký, kiểm thử iOS |
| 7 | 20–22 | Danh mục tài sản thật, thêm/sửa & xuất PDF, số liệu thật cho Tổng quan/Báo cáo |
| 8 | 23–25 | Ảnh minh chứng, tự động đồng bộ, đối chiếu xung đột tài sản |
| 9 | 26–28 | Supabase Auth + RLS, màn Địa điểm & Cài đặt, bản web quản lý |
| 10 | — | Model YOLOv8s mới, Edge AI chạy GPU Metal, cắt ảnh theo khung quét ở phía native |
| Mở rộng | — | YOLOv8n-seg V3 khoanh vùng 4 loại hư hỏng trên ảnh minh chứng |

## Quy trình Git

- Nhánh: `main` ← `develop` ← `feature/sprint<S>-card<N>-tv<K>`. Mọi thay đổi vào `develop` đều qua Pull Request.
- Commit theo [Conventional Commits](https://www.conventionalcommits.org/), ví dụ:

  ```
  feat(card26): đăng nhập, đăng ký bằng Supabase Auth và khoá dữ liệu theo tài khoản
  fix(ai): mô hình Edge AI bị huỷ ngay sau khi nạp nên không nhận diện được
  ```
