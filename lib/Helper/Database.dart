import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_chatapp/Helper/Constants.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

class DatabaseHelper {
  FirebaseFirestore _db;
  FirebaseStorage _firebaseStorage =
      FirebaseStorage(storageBucket: Constants.firebaseReferenceURI);
  StorageUploadTask _uploadTask;

  DatabaseHelper() {
    _db = FirebaseFirestore.instance;
  }

  getUserByUsername(String username) async {
    return await _db.collection('users').doc(username).get();
  }

  getUserByEmail(String email) async {
    return await _db.collection('users').where('email', isEqualTo: email).get();
  }

  getChats(String uid) {
    return _db
        .collection('chats')
        .where('members', arrayContains: uid)
        .orderBy('lastActive', descending: true)
        .snapshots();
  }

  generateChatId(String username1, String username2) {
    return username1.toString().compareTo(username2.toString()) < 0
        ? username1.toString() + '-' + username2.toString()
        : username2.toString() + '-' + username1.toString();
  }

  Future<bool> checkChatExistsOrNot(String username1, String username2) async {
    String chatId = generateChatId(username1, username2);
    DocumentSnapshot doc = await _db.collection('chats').doc(chatId).get();
    return doc.exists;
  }

  sendMessage(
      {@required String to,
      @required String from,
      @required bool isText,
      String msg,
      String path}) async {
    bool existsOrNot = await checkChatExistsOrNot(to, from);
    FirebaseFirestore tempDb = FirebaseFirestore.instance;
    String chatId = generateChatId(from, to);
    Timestamp now = Timestamp.now();
    if (!existsOrNot) {
      List<String> members = [to, from];
      isText
          ? await tempDb
              .collection('chats')
              .doc(chatId)
              .collection('messages')
              .add(
              {'from': from, 'message': msg, 'time': now, 'isText': true},
            )
          : await tempDb
              .collection('chats')
              .doc(chatId)
              .collection('messages')
              .add(
              {'from': from, 'photo': path, 'time': now, 'isText': false},
            );
      await tempDb
          .collection('chats')
          .doc(chatId)
          .set({'lastActive': now, 'members': members});
    } else {
      isText
          ? await tempDb
              .collection('chats')
              .doc(chatId)
              .collection('messages')
              .add(
              {'from': from, 'message': msg, 'time': now, 'isText': true},
            )
          : await tempDb
              .collection('chats')
              .doc(chatId)
              .collection('messages')
              .add(
              {'from': from, 'photo': path, 'time': now, 'isText': false},
            );
      await tempDb.collection('chats').doc(chatId).update({'lastActive': now});
    }
  }

  uploadImage(File _image, String to, String from) async {
    String filePath =
        'chatImages/${generateChatId(to, from)}/${DateTime.now()}.png';
    _uploadTask = _firebaseStorage.ref().child(filePath).putFile(_image);
    await _uploadTask.onComplete;
    print('File Uploaded');
    return _uploadTask;
  }

  getURLforImage(String imagePath) async {
    FirebaseStorage storage = FirebaseStorage.instance;
    StorageReference sRef =
        await storage.getReferenceFromUrl(Constants.firebaseReferenceURI);
    StorageReference pathReference = sRef.child(imagePath);
    return await pathReference.getDownloadURL();
  }
}
