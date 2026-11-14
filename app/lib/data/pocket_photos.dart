import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../core/config.dart';

/// 題目照片從哪裡來。
enum PhotoSource { camera, gallery }

/// 口袋卡片的題目照片（M1）。只存在 App 自己的資料夾，不上傳、不做文字辨識（底線 8）。
///
/// 存之前先轉正、縮小、重新編碼成 JPEG，把位置與拍攝資訊（EXIF）丟掉。
abstract class PocketPhotoStore {
  /// 讓孩子拍一張或從相簿挑一張。取消時回傳 null；成功回傳存好的檔名。
  Future<String?> take(PhotoSource source);

  /// 檔名對應到的檔案。
  File fileOf(String name);

  Future<void> delete(String name);

  /// 刪除全部資料時呼叫：整個照片資料夾刪掉。
  Future<void> deleteAll();
}

/// 把照片轉正、縮到 [maxSide]、重新編碼成 JPEG。輸出不帶任何 EXIF（位置、時間、機型）。
/// 讀不懂的檔案回傳 null。
Uint8List? cleanPhotoBytes(Uint8List bytes, {int maxSide = PocketConfig.photoMaxSide}) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  var image = img.bakeOrientation(decoded);
  final longest = image.width > image.height ? image.width : image.height;
  if (longest > maxSide) {
    image = image.width >= image.height
        ? img.copyResize(image, width: maxSide)
        : img.copyResize(image, height: maxSide);
  }
  image.exif = img.ExifData();
  return img.encodeJpg(image, quality: PocketConfig.photoQuality);
}

/// 裝置上的照片資料夾：Application Support/pocket_photos（跟資料庫同一層，不進雲端備份，G4）。
class DevicePocketPhotoStore implements PocketPhotoStore {
  DevicePocketPhotoStore(this.dir, {ImagePicker? picker, Uuid uuid = const Uuid()})
      : _picker = picker ?? ImagePicker(),
        // ignore: prefer_initializing_formals
        _uuid = uuid;

  static Future<DevicePocketPhotoStore> onDevice() async {
    final base = await getApplicationSupportDirectory();
    return DevicePocketPhotoStore(Directory(p.join(base.path, 'pocket_photos')));
  }

  final Directory dir;
  final ImagePicker _picker;
  final Uuid _uuid;

  @override
  Future<String?> take(PhotoSource source) async {
    final picked = await _picker.pickImage(
      source: source == PhotoSource.camera ? ImageSource.camera : ImageSource.gallery,
      // 先讓系統縮一次（省記憶體），再自己清一次 EXIF。
      maxWidth: PocketConfig.photoMaxSide.toDouble(),
      maxHeight: PocketConfig.photoMaxSide.toDouble(),
      requestFullMetadata: false,
    );
    if (picked == null) return null;
    final raw = await picked.readAsBytes();
    final clean = await Isolate.run(() => cleanPhotoBytes(raw));
    if (clean == null) return null;
    await dir.create(recursive: true);
    final name = '${_uuid.v4()}.jpg';
    await File(p.join(dir.path, name)).writeAsBytes(clean, flush: true);
    return name;
  }

  @override
  File fileOf(String name) => File(p.join(dir.path, p.basename(name)));

  @override
  Future<void> delete(String name) async {
    final f = fileOf(name);
    if (await f.exists()) await f.delete();
  }

  @override
  Future<void> deleteAll() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}

/// 裝置上才有（`bootstrap.dart` override）。null ＝ 這台不能放照片（測試、桌面），口袋只能打字。
final pocketPhotoStoreProvider = Provider<PocketPhotoStore?>((ref) => null);
