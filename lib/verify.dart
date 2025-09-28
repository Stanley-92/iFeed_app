import 'package:flutter/material.dart';
import 'package:ifeed/profile.dart';
import 'Mainfeed.dart';

class VerifyScreen extends StatefulWidget {
  @override
  VerifyScreenState createState() => VerifyScreenState();
}

class VerifyScreenState extends State<VerifyScreen> {
  List<TextEditingController> controllers = List.generate(5, (index) => TextEditingController());
  final String _expectedCode = "12345"; // Hardcoded expected code for demo; replace with API or dynamic value
  bool _isVerifying = false;

  @override
  void dispose() {
    for (var controller in controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _verifyCode() {
    setState(() {
      _isVerifying = true;
    });
    String enteredCode = controllers.map((controller) => controller.text).join();
    if (enteredCode == _expectedCode) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verification Successful!')),
      );
      // Add navigation or further logic here (e.g., to a home screen)

Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => ProfileUserScreen ()),
    );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid Verification Code')),
      );
    }
    setState(() {
      _isVerifying = false;
    });
  }

  void _resendCode() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Code resent to leystan405@gmail.com')),
    );
    // Add logic to resend code (e.g., API call)
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.pink[50],
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                'iFeed',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
              ),
              SizedBox(height: 40),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: <Widget>[
                      Text(
                        'Verification Code',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 20),
                      Text(
                        "We've sent a code: to leystan405@gmail.com",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: SizedBox(
                              width: 40,
                              height: 40,
                              child: TextField(
                                controller: controllers[index],
                                textAlign: TextAlign.center,
                                keyboardType: TextInputType.number,
                                maxLength: 1,
                                decoration: InputDecoration(
                                  counterText: '',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                ),
                                onChanged: (value) {
                                  if (value.length == 1 && index < 4) {
                                    FocusScope.of(context).nextFocus();
                                  }
                                },
                              ),
                            ),
                          );
                        }),
                      ),
                      SizedBox(height: 20),
                      TextButton(
                        onPressed: _resendCode,
                        child: Text(
                          "Didn't get a code?",
                          style: TextStyle(color: Colors.blue),
                        ),
                      ),
                      SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _isVerifying ? null : _verifyCode,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          minimumSize: Size(double.infinity, 50),
                        ),
                        child: _isVerifying
                            ? CircularProgressIndicator(color: Colors.white)
                            : Text('Verify'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}