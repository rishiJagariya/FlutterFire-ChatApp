import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:rsa_encrypt/rsa_encrypt.dart';
import 'package:rxdart/rxdart.dart';
import 'rsa_helper.dart';

import 'OfflineStore.dart';

class AuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  OfflineStorage offlineStorage = new OfflineStorage();

  Stream<User> user;
  Stream<Map<String, dynamic>> profile;
  PublishSubject loading = PublishSubject();

  AuthService() {
    print('into authservice constrctor');
    user = _auth.authStateChanges();
    profile = user.switchMap(
      (User u) {
        if (u != null)
          return _db
              .collection('users')
              .doc(u.uid)
              .snapshots()
              .map((snap) => snap.data());
        return Stream.empty();
      },
    );
  }

  Future<User> googleSignIn() async {
    loading.add(true);
    GoogleSignInAccount googleUser = await _googleSignIn.signIn();
    GoogleSignInAuthentication googleAuth = await googleUser.authentication;

    final AuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    User user = (await _auth.signInWithCredential(credential)).user;
    updateUserData(user);

    await offlineStorage.saveUserInfo(
        user.photoURL, user.displayName, user.email, user.uid);

    DocumentReference keyRef = _db.collection('publickeys').doc(user.uid);
    print('into googlesign in method');
    await rsahelper.init();
    keyRef.get().then((docSnapshot) => {
          if (docSnapshot.exists == false)
            {
              rsahelper.storePrivateKey(user.uid),
              keyRef.set({'key': rsahelper.pub})
            }
        });
        
    return user;
  }

  void updateUserData(User user) async {
    DocumentReference ref = _db.collection('users').doc(user.uid);
    profile = _auth.authStateChanges().switchMap(
      (User u) {
        if (u != null) {
          return _db
              .collection('users')
              .doc(u.uid)
              .snapshots()
              .map((snap) => snap.data());
        }
        return Stream.empty();
      },
    );
    return ref.set({
      'uid': user.uid,
      'email': user.email,
      'photo': user.photoURL,
      'name': user.displayName
    }, SetOptions(merge: true));
  }

  void signOut() => _auth.signOut();
}

final AuthService authService = AuthService();
