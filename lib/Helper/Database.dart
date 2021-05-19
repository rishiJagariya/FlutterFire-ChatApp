import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_chatapp/Helper/Constants.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import 'package:rsa_encrypt/rsa_encrypt.dart';
//import 'package:simple_rsa/simple_rsa.dart';
import 'package:firebase_chatapp/Helper/rsa_helper.dart';
import 'package:pointycastle/api.dart' as crypto;

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
    var userChats = _db
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
    DocumentReference keyRef0, keyRef1;
    String encrypted0, encrypted1;
    print('into send message function-------1------------>>>>>>>' + to + ">>>>>" + from + "<<<");
    //Working here - pending
    String from1 = from;
    if (isText) {
      if (to.toString().compareTo(from.toString()) < 0) {
        keyRef0 = _db.collection('publickeys').doc(from1);
        keyRef1 = _db.collection('publickeys').doc(to);
        print('into send message function---------1.1----------->>>>>>>');
      } else {
        keyRef0 = _db.collection('publickeys').doc(to);
        keyRef1 = _db.collection('publickeys').doc(from1);
        print('into send message function---------1.2----------->>>>>>>');
      }
      //print('into send message function---------2---------->>>>>>>');
      String pubkey0, pubkey1;
      await keyRef0.get().then((doc) => {
            if (doc.exists)
              pubkey0 = doc.data()['key']
            else
              print("No such document!")
          });
      print('into send message function------------2-------->>>>>>>');
      await keyRef1.get().then((doc) => {
            if (doc.exists)
              pubkey1 = doc.data()['key']
            else
              print("No such document!")
          });
      print('into send message function----------3---------->>>>>>>');
      print(pubkey1); print("  -------   "); print(pubkey0);
      //Rishi add this part for RSA
      encrypted0 =
          encrypt(msg, rsahelper.helper.parsePublicKeyFromPem(pubkey0));
      encrypted1 =
          encrypt(msg, rsahelper.helper.parsePublicKeyFromPem(pubkey1));
    }
    // end of RSA part
    print('into send message function----------4---------->>>>>>>');
    if (!existsOrNot) {
      List<String> members = [to, from];
      if (isText == true) {
        await tempDb
            .collection('chats')
            .doc(chatId)
            .collection('messages0')
            .add(
          {'from': from, 'message': encrypted0, 'time': now, 'isText': true},
        );
        await tempDb
            .collection('chats')
            .doc(chatId)
            .collection('messages1')
            .add(
          {'from': from, 'message': encrypted1, 'time': now, 'isText': true},
        );
      } else {
        await tempDb
            .collection('chats')
            .doc(chatId)
            .collection('messages0')
            .add(
          {'from': from, 'photo': path, 'time': now, 'isText': false},
        );
        await tempDb
            .collection('chats')
            .doc(chatId)
            .collection('messages1')
            .add(
          {'from': from, 'photo': path, 'time': now, 'isText': false},
        );
      }
      await tempDb
          .collection('chats')
          .doc(chatId)
          .set({'lastActive': now, 'members': members});
    } else {
      if (isText == true) {
        await tempDb
            .collection('chats')
            .doc(chatId)
            .collection('messages0')
            .add(
          {'from': from, 'message': encrypted0, 'time': now, 'isText': true},
        );
        await tempDb
            .collection('chats')
            .doc(chatId)
            .collection('messages1')
            .add(
          {'from': from, 'message': encrypted1, 'time': now, 'isText': true},
        );
      } else {
        await tempDb
            .collection('chats')
            .doc(chatId)
            .collection('messages0')
            .add(
          {'from': from, 'photo': path, 'time': now, 'isText': false},
        );
        await tempDb
            .collection('chats')
            .doc(chatId)
            .collection('messages1')
            .add(
          {'from': from, 'photo': path, 'time': now, 'isText': false},
        );
      }
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
