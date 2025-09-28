import 'package:flutter/material.dart';
import 'create.dart'; // Import the Create.dart file

class LoginScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Simple controllers for form fields
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    return Scaffold(
      backgroundColor: Colors.pink[50],
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(58.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                'iFeed',
                style: TextStyle(
                  fontSize: 35,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[500],
                ),
              ),
              SizedBox(height: 30),
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: 'Email or Phone number',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              SizedBox(height: 20),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  // Basic validation before proceeding (e.g., check if fields are not empty)
                  if (emailController.text.isNotEmpty && passwordController.text.isNotEmpty) {
                    // Add login logic here if needed
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Please fill in all fields')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  minimumSize: Size(double.infinity, 48),
                ),
                child: Text('Login'),
              ),
              TextButton(
                onPressed: () {
                  // Add forgot password logic here
                },
                child: Text('Forgot your Password'),
              ),
              ElevatedButton(
                onPressed: () {
                  // Navigate to CreateScreen
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => CreateScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  minimumSize: Size(double.infinity, 48),
                ),
                child: Text('Create Account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}