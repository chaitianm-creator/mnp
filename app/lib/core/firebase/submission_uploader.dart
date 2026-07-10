import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

/// 提出画像のアップロード(Phase 5 §4)。
/// クライアント側で最大1280px・80%品質に圧縮してから送信(コスト防衛 + Storageルール5MB上限)。
/// 戻り値は Storage パス(submitForReview の storagePath にそのまま渡す)。
class SubmissionUploader {
  SubmissionUploader({ImagePicker? picker, FirebaseStorage? storage, FirebaseAuth? auth})
      : _picker = picker ?? ImagePicker(),
        _storage = storage ?? FirebaseStorage.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final ImagePicker _picker;
  final FirebaseStorage _storage;
  final FirebaseAuth _auth;

  /// ギャラリーから選択→圧縮→アップロード。キャンセル時は null。
  Future<String?> pickAndUpload({required String questId}) async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 80,
    );
    if (picked == null) return null;

    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('auth/unauthenticated');

    final bytes = await picked.readAsBytes();
    final path =
        'users/$uid/submissions/${questId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _storage.ref(path).putData(
          bytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
    return path;
  }
}
