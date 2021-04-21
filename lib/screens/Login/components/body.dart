import 'package:Chatify/screens/HomeScreen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:Chatify/screens/Login/components/background.dart';
import 'package:Chatify/screens/Signup/signup_screen.dart';
import 'package:Chatify/components/already_have_an_account_acheck.dart';
import 'package:Chatify/components/rounded_button.dart';
import 'package:Chatify/components/text_field_container.dart';
import 'package:flutter_svg/svg.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:Chatify/widgets/Progresswidget.dart';
import 'package:google_sign_in/google_sign_in.dart';

class SignIn extends StatefulWidget {
  @override
  _SignInState createState() => _SignInState();
}

class _SignInState extends State<SignIn> {
  SharedPreferences preferences;
  final String defaultPhotoUrl =
      "https://moonvillageassociation.org/wp-content/uploads/2018/06/default-profile-picture1.jpg";
  final GlobalKey<FormState> _formkey = GlobalKey<FormState>();
  static const kPrimaryColor = Color(0xFF412DF7);
  final FirebaseMessaging _messaging = FirebaseMessaging();
  String fcmToken;
  TextEditingController emailEditingController = new TextEditingController();
  TextEditingController passwordEditingController = new TextEditingController();
  FirebaseAuth _auth = FirebaseAuth.instance;
  bool _passwordVisible;
  bool isloading = false;

  @override
  void initState() {
    _passwordVisible = false;
    _messaging.getToken().then((value) {
      fcmToken = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return Background(
      child: SingleChildScrollView(
        child: Form(
          key: _formkey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              // Text(
              //   "LOGIN",
              //   style: TextStyle(fontWeight: FontWeight.bold),
              // ),
              SizedBox(height: size.height * 0.03),
              SvgPicture.asset(
                "assets/icons/login.svg",
                height: size.height * 0.35,
              ),
              SizedBox(height: size.height * 0.03),
              TextFieldContainer(
                child: TextFormField(
                  controller: emailEditingController,
                  validator: (emailValue) {
                    if (emailValue.isEmpty) {
                      return 'This field is mandatory';
                    }

                    String p = "[a-zA-Z0-9\+\.\_\%\-\+]{1,256}" +
                        "\\@" +
                        "[a-zA-Z0-9][a-zA-Z0-9\\-]{0,64}" +
                        "(" +
                        "\\." +
                        "[a-zA-Z0-9][a-zA-Z0-9\\-]{0,25}" +
                        ")+";
                    RegExp regExp = new RegExp(p);

                    if (regExp.hasMatch(emailValue)) {
                      // So, the email is valid
                      return null;
                    }

                    return 'This is not a valid email';
                  },
                  cursorColor: kPrimaryColor,
                  decoration: InputDecoration(
                    icon: Icon(
                      Icons.email,
                      color: kPrimaryColor,
                    ),
                    hintText: "Your Email",
                    border: InputBorder.none,
                  ),
                ),
              ),
              TextFieldContainer(
                child: TextFormField(
                  controller: passwordEditingController,
                  obscureText: !_passwordVisible,
                  validator: (pwValue) {
                    if (pwValue.isEmpty) {
                      return 'This field is mandatory';
                    }
                    // if (pwValue.length < 6) {
                    //   return 'Password must be at least 6 characters';
                    // }

                    return null;
                  },
                  cursorColor: kPrimaryColor,
                  decoration: InputDecoration(
                    hintText: "Password",
                    icon: Icon(
                      Icons.lock,
                      color: kPrimaryColor,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _passwordVisible
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: kPrimaryColor,
                      ),
                      onPressed: () {
                        setState(() {
                          _passwordVisible = !_passwordVisible;
                        });
                      },
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
              RoundedButton(
                child: isloading
                    ? circularprogress()
                    : Text(
                        "LOGIN",
                        style: TextStyle(color: Colors.white),
                      ),
                press: () {
                  if (_formkey.currentState.validate()) {
                    loginUser();
                  }
                },
              ),
              SizedBox(height: size.height * 0.03),
              AlreadyHaveAnAccountCheck(
                press: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) {
                        return SignUpScreen();
                      },
                    ),
                  );
                },
              ),
              _buildTextSignIn(),
              _buildSocialSignIn(),
            ],
          ),
        ),
      ),
    );
  }

  void loginUser() async {
    this.setState(() {
      isloading = true;
    });
    preferences = await SharedPreferences.getInstance();

    FirebaseUser firebaseUser;

    await _auth
        .signInWithEmailAndPassword(
            email: emailEditingController.text.trim(),
            password: passwordEditingController.text.trim())
        .then((auth) {
      firebaseUser = auth.user;
    }).catchError((err) {
      this.setState(() {
        isloading = false;
      });
      Scaffold.of(context).showSnackBar(SnackBar(content: Text(err.message)));
    });

    if (firebaseUser != null) {
      Firestore.instance
          .collection("Users")
          .document(firebaseUser.uid)
          .updateData({"fcmToken": fcmToken});

      Firestore.instance
          .collection("Users")
          .document(firebaseUser.uid)
          .get()
          .then((datasnapshot) async {
        print(datasnapshot.data["photoUrl"]);

        await preferences.setString("uid", datasnapshot.data["uid"]);
        await preferences.setString("name", datasnapshot.data["name"]);
        await preferences.setString("photo", datasnapshot.data["photoUrl"]);
        await preferences.setString("email", datasnapshot.data["email"]);
        this.setState(() {
          isloading = false;
        });

        Navigator.pop(context);
        Route route = MaterialPageRoute(
            builder: (c) => HomeScreen(
                  currentuserid: firebaseUser.uid,
                ));
        Navigator.pushReplacement(context, route);
      });
    } else {
      this.setState(() {
        isloading = false;
      });
      Fluttertoast.showToast(msg: "Login Failed");
    }
  }

  signInWithGoogle(BuildContext context) async {
    this.setState(() {
      isloading = true;
    });
    preferences = await SharedPreferences.getInstance();
    final GoogleSignInAccount googleUser = await GoogleSignIn().signIn();
    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    final AuthCredential credential = GoogleAuthProvider.getCredential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final FirebaseUser user =
        (await _auth.signInWithCredential(credential)).user;
    if (user != null) {
      final QuerySnapshot result = await Firestore.instance
          .collection("Users")
          .where("uid", isEqualTo: user.uid)
          .getDocuments();
      if (result.documents.length == 0) {
        Firestore.instance.collection("Users").document(user.uid).setData({
          "uid": user.uid,
          "email": user.email,
          "name": "NewUser",
          "photoUrl": defaultPhotoUrl,
          "createdAt": DateTime.now().millisecondsSinceEpoch.toString(),
          "state": 1,
          "lastSeen": DateTime.now().millisecondsSinceEpoch.toString(),
          "fcmToken": fcmToken
        });
        FirebaseUser currentuser = user;
        await preferences.setString("uid", currentuser.uid);
        await preferences.setString("name", "NewUser");
        await preferences.setString("photo", defaultPhotoUrl);
        await preferences.setString("email", currentuser.email);
      } else {
        // FirebaseUser currentuser = firebaseUser;
        await preferences.setString("uid", result.documents[0]["uid"]);
        await preferences.setString("name", result.documents[0]["name"]);
        await preferences.setString("photo", result.documents[0]["photoUrl"]);
        await preferences.setString("email", result.documents[0]["email"]);
      }
      this.setState(() {
        isloading = false;
      });
      Navigator.pop(context);
      Route route = MaterialPageRoute(
          builder: (c) => HomeScreen(
                currentuserid: user.uid,
              ));
      Navigator.pushReplacement(context, route);
    }
  }

  Widget _buildTextSignIn() {
    return Column(
      children: <Widget>[
        Text(
          '- OR LOG IN WITH  -',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(
          height: 10.0,
        )
      ],
    );
  }

  Widget _buildSocialSignIn() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 0.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          GestureDetector(
            onTap: () => print('Login with Facebook'),
            child: Container(
              height: 60.0,
              width: 60.0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    offset: Offset(0, 2),
                    blurRadius: 6.0,
                  )
                ],
                image: DecorationImage(
                  image: AssetImage('assets/images/facebook.png'),
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => signInWithGoogle(context),
            child: Container(
              height: 60.0,
              width: 60.0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    offset: Offset(0, 2),
                    blurRadius: 6.0,
                  )
                ],
                image: DecorationImage(
                  image: AssetImage('assets/images/google.png'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
