import 'package:rsa_encrypt/rsa_encrypt.dart';
import 'package:pointycastle/api.dart' as crypto;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_chatapp/Helper/Database.dart';

class RsaHelper{

  RsaKeyHelper helper = RsaKeyHelper();
  Future<crypto.AsymmetricKeyPair> keyPairFuture;
  crypto.AsymmetricKeyPair keyPair;
  String pub, pri;
  final storage = new FlutterSecureStorage();
  
  RsaHelper() {
    print('into init of RSA helper');
  }

  init() async{
    keyPairFuture = helper.computeRSAKeyPair(helper.getSecureRandom());
    keyPair = await keyPairFuture;
    
    this.pub = helper.encodePublicKeyToPemPKCS1(keyPair.publicKey);
    this.pri = helper.encodePrivateKeyToPemPKCS1(keyPair.privateKey);
  

    DatabaseHelper databaseHelper; 

    //print('public key after PEM encoding : \n' + pub);
    //print('\n private key after PEM encoding : \n' + pri);
  }

  storePrivateKey(String uid) async {
    //final String key = null;
    await storage.write(key: uid, value: pri);
    //print("write successfull");
  }

  getPrivateKey(String uid) async {
    //print("into getprivate key");
    String rand = await storage.read(key: uid);
    return helper.parsePrivateKeyFromPem(rand);
    //return rand;
  }

}

final RsaHelper rsahelper = RsaHelper();








   

  