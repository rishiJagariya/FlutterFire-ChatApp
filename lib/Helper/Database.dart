import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_chatapp/Helper/Constants.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:simple_rsa/simple_rsa.dart';

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
    //print('into get chats()');
    var userChats =  _db
        .collection('chats')
        .where('members', arrayContains: uid)
        .orderBy('lastActive', descending: true)
        .snapshots();
    //print(userChats);
    return userChats;
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


    //Rishi add this part for RSA
    //final publicKey = await parseKeyFromFile<RSAPublicKey>('assets/test/public.pem');
    
    // final publicPem = await rootBundle.loadString('assets/test/public.pem');
    // final publicKey = RSAKeyParser().parse(publicPem) as RSAPublicKey;

    // final privKey = await parseKeyFromFile<RSAPrivateKey>('assets/test/private.pem');
    // final encrypter = Encrypter(RSA(publicKey: publicKey, privateKey: privKey));

    // final encrypted = encrypter.encrypt(msg);
    // print(encrypted);

    final PUBLIC_KEY =
      "MIIBITANBgkqhkiG9w0BAQEFAAOCAQ4AMIIBCQKCAQBuAGGBgg9nuf6D2c5AIHc8" +
          "vZ6KoVwd0imeFVYbpMdgv4yYi5obtB/VYqLryLsucZLFeko+q1fi871ZzGjFtYXY" +
          "9Hh1Q5e10E5hwN1Tx6nIlIztrh5S9uV4uzAR47k2nng7hh6vuZ33kak2hY940RSL" +
          "H5l9E5cKoUXuQNtrIKTS4kPZ5IOUSxZ5xfWBXWoldhe+Nk7VIxxL97Tk0BjM0fJ3" +
          "8rBwv3++eAZxwZoLNmHx9wF92XKG+26I+gVGKKagyToU/xEjIqlpuZ90zesYdjV+" +
          "u0iQjowgbzt3ASOnvJSpJu/oJ6XrWR3egPoTSx+HyX1dKv9+q7uLl6pXqGVVNs+/" +
          "AgMBAAE=";

    String encrypted = await encryptString(msg, PUBLIC_KEY);

    // end of RSA part
    if (!existsOrNot) {
      List<String> members = [to, from];
      isText
          ? await tempDb
              .collection('chats')
              .doc(chatId)
              .collection('messages')
              .add(
              {'from': from, 'message': encrypted, 'time': now, 'isText': true},
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
              {'from': from, 'message': encrypted, 'time': now, 'isText': true},
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
