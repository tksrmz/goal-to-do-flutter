import 'package:firebase_auth/firebase_auth.dart';

/// ログインの失敗の理由。画面のメッセージに使う。
enum SignInFailure {
  /// メールアドレスかパスワードが正しくない（AC-002）
  invalidCredential,

  /// 試行が多すぎて一時的に止められている
  tooManyRequests,

  /// ネットワークに接続できない（初回のログインにはネットワークが必要。NFR-008）
  network,

  unknown,
}

final class SignInException(final SignInFailure failure) implements Exception {
  @override
  String toString() => 'SignInException: ${failure.name}';
}

/// 認証（FR-001）。新規登録の操作は持たない（NFR-003、AC-006）。
abstract interface class AuthRepository {
  /// ログイン中のユーザーの UID。未ログインなら `null`。
  Stream<String?> userIdChanges();

  /// 失敗すると [SignInException]。
  Future<void> signIn({required String email, required String password});

  Future<void> signOut();
}

final class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth);

  final FirebaseAuth _auth;

  @override
  Stream<String?> userIdChanges() =>
      _auth.authStateChanges().map((user) => user?.uid);

  @override
  Future<void> signIn({required String email, required String password}) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw SignInException(switch (e.code) {
        // メールアドレス列挙保護（既定で有効）では、どちらが誤りかを区別しない invalid-credential になる
        'invalid-credential' ||
        'invalid-email' ||
        'user-not-found' ||
        'wrong-password' ||
        'user-disabled' => SignInFailure.invalidCredential,
        'too-many-requests' => SignInFailure.tooManyRequests,
        'network-request-failed' => SignInFailure.network,
        _ => SignInFailure.unknown,
      });
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();
}
