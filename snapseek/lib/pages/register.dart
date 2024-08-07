import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:snapseek/components/button.dart';
import 'package:snapseek/components/extension.dart';
import 'package:snapseek/components/textfield.dart';
import 'package:snapseek/components/google_button.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:snapseek/pages/login.dart';
import 'package:stream_feed_flutter_core/stream_feed_flutter_core.dart' as stream_feed;

//stateful because we want to show errors on screen for when password and confirm password are different

class Register extends StatefulWidget {
  final Function()? onRegisterComplete;
  const Register({super.key, this.onRegisterComplete});

  @override
  State<Register> createState() => _RegisterState();
}

class _RegisterState extends State<Register> {
  final TextEditingController userController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  String errorMessage = '';

  Future<stream_feed.Token> getStreamToken(String firebaseToken, String userId) async {
    final response = await http.post(
      Uri.parse('http://127.0.0.1:5000/get_stream_token'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, String>{
        'firebase_token': firebaseToken,
        'user_id': userId,
      })
    );
    if (response.statusCode == 200) {
      var jsonResponse = jsonDecode(response.body);
      if (jsonResponse.containsKey('stream_token')) {
        return stream_feed.Token(jsonResponse['stream_token']);
      } else {
        throw Exception('Stream token not found in response');
      }
    } else {
      throw Exception('Failed to load stream token');
    }
  }

  void signUp() async {
    showDialog(
        context: context,
        builder: (context) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        });
    Map<String, dynamic> userData = {};
    try {
      //only create user if password and confirmpassword are the same
      if (passwordController.text == confirmPasswordController.text) {
        UserCredential userCredential =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: emailController.text,
          password: passwordController.text,
        );
        String uid = userCredential.user!.uid;
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'username': userController.text, // Store the username
          // Add other user details here if necessary
        });
        userData['handle'] = userController.text;
        String? firebaseToken = await userCredential.user?.getIdToken();
        stream_feed.Token streamToken = await getStreamToken(firebaseToken!, FirebaseAuth.instance.currentUser!.uid);
        final user = stream_feed.User(id: FirebaseAuth.instance.currentUser!.uid);
        try {
          await context.feedClient.setUser(user, streamToken);
        } catch (e) {
          print('Error setting user: $errorPropertyTextConfiguration');
        }
        try {
          await context.feedClient.user(FirebaseAuth.instance.currentUser!.uid).update(userData);
        } catch (e) {
          print('Error updating user: $e');
        }
        print(user.handle);
        print(user.profileImage);
        widget.onRegisterComplete?.call();
        Navigator.pop(context);
      } else {
        Navigator.pop(context);
        setState(() {
          errorMessage = "Passwords don't match";
        });
      }
    } on FirebaseAuthException catch (e) {
      Navigator.pop(context);
      setState(() {
        errorMessage = "$e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.white,
        body: SingleChildScrollView(
          child: SafeArea(
              child: Center(
                  child: Padding(
            padding: const EdgeInsets.only(left: 25.0, right: 25.0),
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Padding(
                      padding: EdgeInsets.only(top: 40.0, bottom: 40.0),
                      child: Text("SnapSeek",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 25))),
                  const Text('Create an account',
                      style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 20)),
                  CustomTextField(
                    controller: userController,
                    hintText: 'Username',
                    obscureText: false,
                  ),
                  CustomTextField(
                    controller: emailController,
                    hintText: 'Email address',
                    obscureText: false,
                  ),
                  CustomTextField(
                    controller: passwordController,
                    hintText: 'Password',
                    obscureText: true,
                  ),
                  CustomTextField(
                    controller: confirmPasswordController,
                    hintText: 'Confirm password',
                    obscureText: true,
                  ),
                  const SizedBox(height: 10.0),
                  if (errorMessage.isNotEmpty)
                    Text(errorMessage,
                        style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 10.0),
                  CustomButton(onTap: signUp, name: 'Sign up'),
                  const SizedBox(height: 20.0),
                  Row(children: [
                    Expanded(
                        child:
                            Divider(thickness: 0.5, color: Colors.grey[400])),
                    const Padding(
                      padding: EdgeInsets.only(right: 10.0, left: 10.0),
                      child: Text('Or continue with',
                          style: TextStyle(
                              color: Color.fromARGB(255, 99, 98, 98))),
                    ),
                    Expanded(
                        child: Divider(thickness: 0.5, color: Colors.grey[400]))
                  ]),
                  const SizedBox(height: 20.0),
                  const GoogleButton(imagePath: 'lib/images/google logo.png'),
                  const SizedBox(height: 20.0),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Already have an account?",
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        //onTap passed in from login_or_register.dart file
                        //to call variables from the stateful class, use 'widget._____'
                        onTap: () {
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (context, animation1, animation2) => const Login(),
                              transitionDuration: Duration.zero,
                              reverseTransitionDuration: Duration.zero,
                            )
                          );
                        },
                        child: const Text('Sign in',
                            style: TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold)),
                      )
                    ],
                  )
                ]),
          ))),
        ));
  }
}
