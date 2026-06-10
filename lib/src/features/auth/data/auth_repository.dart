import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum UserRole {
  user,
  admin,
  guest;

  static UserRole fromString(String value) {
    return switch (value.trim().toLowerCase()) {
      'admin' => UserRole.admin,
      'user' => UserRole.user,
      'guest' => UserRole.guest,
      _ => throw AuthRepositoryException('Unknown account role: $value'),
    };
  }

  String get value => name;
}

class AuthenticatedUser {
  const AuthenticatedUser({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.username,
    required this.role,
    required this.profileImageUrl,
    required this.phoneNumber,
  });

  final String uid;
  final String email;
  final String fullName;
  final String username;
  final UserRole role;
  final String profileImageUrl;
  final String phoneNumber;

  bool get isAdmin => role == UserRole.admin;
  bool get isGuest => role == UserRole.guest;

  factory AuthenticatedUser.fromFirestore({
    required User firebaseUser,
    required DocumentSnapshot<Map<String, dynamic>> snapshot,
  }) {
    final data = snapshot.data();
    if (data == null) {
      throw const AuthRepositoryException('User profile was not found.');
    }

    return AuthenticatedUser(
      uid: firebaseUser.uid,
      email: data['email']?.toString() ?? firebaseUser.email ?? '',
      fullName: data['full_name']?.toString() ?? '',
      username: data['username']?.toString() ?? '',
      role: UserRole.fromString(data['role']?.toString() ?? ''),
      profileImageUrl: data['profile_image_url']?.toString() ?? '',
      phoneNumber: data['phone_number']?.toString() ?? '',
    );
  }

  factory AuthenticatedUser.guest() {
    return const AuthenticatedUser(
      uid: 'guest',
      email: '',
      fullName: 'Guest',
      username: 'guest',
      role: UserRole.guest,
      profileImageUrl: '',
      phoneNumber: '',
    );
  }
}

class AuthRepositoryException implements Exception {
  const AuthRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

final firebaseAuthProvider = Provider<FirebaseAuth?>((ref) {
  if (Firebase.apps.isEmpty) {
    return null;
  }

  return FirebaseAuth.instance;
});

final firebaseFirestoreProvider = Provider<FirebaseFirestore?>((ref) {
  if (Firebase.apps.isEmpty) {
    return null;
  }

  return FirebaseFirestore.instance;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    firebaseAuth: ref.watch(firebaseAuthProvider),
    firestore: ref.watch(firebaseFirestoreProvider),
  );
});

final usersStreamProvider = StreamProvider<List<AppUser>>((ref) {
  return ref.watch(authRepositoryProvider).watchUsers();
});

class AppUser {
  const AppUser({
    required this.documentId,
    required this.uid,
    required this.fullName,
    required this.username,
    required this.email,
    required this.phoneNumber,
    required this.role,
  });

  final String documentId;
  final String uid;
  final String fullName;
  final String username;
  final String email;
  final String phoneNumber;
  final UserRole role;

  factory AppUser.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AppUser(
      documentId: doc.id,
      uid: data['uid']?.toString() ?? doc.id,
      fullName: data['full_name']?.toString() ?? '',
      username: data['username']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
      phoneNumber: data['phone_number']?.toString() ?? '',
      role: UserRole.fromString(data['role']?.toString() ?? 'user'),
    );
  }
}

class AuthRepository {
  AuthRepository({
    required FirebaseAuth? firebaseAuth,
    required FirebaseFirestore? firestore,
  }) : _firebaseAuth = firebaseAuth,
       _firestore = firestore;

  final FirebaseAuth? _firebaseAuth;
  final FirebaseFirestore? _firestore;

  Stream<User?> authStateChanges() {
    return _firebaseAuth?.authStateChanges() ?? Stream<User?>.value(null);
  }

  Future<AuthenticatedUser?> currentSession() async {
    final firebaseUser = _firebaseAuth?.currentUser;
    if (firebaseUser == null) {
      return null;
    }

    return _readUserProfile(firebaseUser);
  }

  Future<AuthenticatedUser> signIn({
    required String email,
    required String password,
    UserRole? expectedRole,
  }) async {
    final firebaseAuth = _requireFirebaseAuth();
    final credential = await firebaseAuth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final firebaseUser = credential.user;
    if (firebaseUser == null) {
      throw const AuthRepositoryException('Unable to start login session.');
    }

    final session = await _readUserProfile(firebaseUser);
    if (expectedRole != null && session.role != expectedRole) {
      await firebaseAuth.signOut();
      throw AuthRepositoryException(
        'This account is registered as ${session.role.value}, not ${expectedRole.value}.',
      );
    }

    return session;
  }

  Future<AuthenticatedUser> signUp({
    required String fullName,
    required String username,
    required String email,
    required String password,
  }) async {
    final firebaseAuth = _requireFirebaseAuth();
    final credential = await firebaseAuth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final firebaseUser = credential.user;
    if (firebaseUser == null) {
      throw const AuthRepositoryException('Unable to create account.');
    }

    final normalizedEmail = firebaseUser.email ?? email.trim();
    await _usersCollection.doc(firebaseUser.uid).set({
      'uid': firebaseUser.uid,
      'full_name': fullName.trim(),
      'username': username.trim(),
      'email': normalizedEmail,
      'phone_number': '',
      'role': UserRole.user.value,
    });

    return _readUserProfile(firebaseUser);
  }

  Future<void> signOut() {
    return _firebaseAuth?.signOut() ?? Future<void>.value();
  }

  Future<void> sendPasswordResetEmail(String email) {
    final firebaseAuth = _requireFirebaseAuth();
    return firebaseAuth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> updatePhoneNumber({
    required String uid,
    required String phoneNumber,
  }) async {
    if (uid.isEmpty || uid == 'guest') {
      throw const AuthRepositoryException(
        'Login before editing your phone number.',
      );
    }

    await _usersCollection.doc(uid).update({
      'phone_number': phoneNumber.trim(),
    });
  }

  Stream<List<AppUser>> watchUsers() {
    final firestore = _firestore;
    if (firestore == null) {
      return Stream.value(const []);
    }

    return firestore.collection('users').snapshots().map((snapshot) {
      final users = snapshot.docs.map(AppUser.fromFirestore).toList();
      users.sort((a, b) => a.fullName.compareTo(b.fullName));
      return users;
    });
  }

  Future<void> createUserProfile({
    required String fullName,
    required String username,
    required String email,
    required String phoneNumber,
    required UserRole role,
  }) async {
    final doc = _usersCollection.doc();
    await doc.set({
      'uid': doc.id,
      'full_name': fullName.trim(),
      'username': username.trim(),
      'email': email.trim(),
      'phone_number': phoneNumber.trim(),
      'role': role.value,
    });
  }

  Future<void> updateUserProfile({
    required String documentId,
    required String username,
    required String phoneNumber,
    required UserRole role,
  }) {
    return _usersCollection.doc(documentId).update({
      'username': username.trim(),
      'phone_number': phoneNumber.trim(),
      'role': role.value,
    });
  }

  Future<void> deleteUserProfile(String documentId) {
    return _usersCollection.doc(documentId).delete();
  }

  Future<AuthenticatedUser> _readUserProfile(User firebaseUser) async {
    final snapshot = await _usersCollection.doc(firebaseUser.uid).get();
    return AuthenticatedUser.fromFirestore(
      firebaseUser: firebaseUser,
      snapshot: snapshot,
    );
  }

  CollectionReference<Map<String, dynamic>> get _usersCollection {
    final firestore = _firestore;
    if (firestore == null) {
      throw const AuthRepositoryException(
        'Firebase is not configured yet. Add Firebase options before logging in.',
      );
    }

    return firestore.collection('users');
  }

  FirebaseAuth _requireFirebaseAuth() {
    final firebaseAuth = _firebaseAuth;
    if (firebaseAuth == null) {
      throw const AuthRepositoryException(
        'Firebase is not configured yet. Add Firebase options before logging in.',
      );
    }

    return firebaseAuth;
  }
}
