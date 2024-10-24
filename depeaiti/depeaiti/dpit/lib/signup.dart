import 'package:flutter/material.dart';
import 'package:flutter_signin_button/flutter_signin_button.dart';
import 'main.dart'; // Import your main.dart for navigation

void main() {
  runApp(const SignUpPage());
}

class SignUpPage extends StatelessWidget {
  const SignUpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF262626), // Dark background color
        appBar: AppBar(
          title: const Text('Sign Up'),
          backgroundColor: Colors.black, // Black background for the AppBar
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // First Name TextField
                _buildTextField(
                  hintText: 'First Name',
                  icon: Icons.person_outline,
                ),
                const SizedBox(height: 10),
                // Last Name TextField
                _buildTextField(
                  hintText: 'Last Name',
                  icon: Icons.person_outline,
                ),
                const SizedBox(height: 10),
                // Email TextField
                _buildTextField(
                  hintText: 'Email',
                  icon: Icons.email_outlined,
                ),
                const SizedBox(height: 10),
                // Password TextField
                _buildTextField(
                  hintText: 'Password',
                  icon: Icons.lock_outline,
                  obscureText: true,
                ),
                const SizedBox(height: 20),
                // Sign Up Button
                ElevatedButton(
                  onPressed: () {
                    // Navigate to main.dart homepage (MyHomePage)
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const MyHomePage(title: 'E-Stetho'),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    backgroundColor:
                        const Color(0xFF00ADEF), // Blue button color
                  ),
                  child: const Text(
                    'Sign Up',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Google Sign Up Button
                SignInButton(
                  Buttons.GoogleDark,
                  text: "Sign up with Google",
                  onPressed: () {
                    // Navigate to main.dart homepage (MyHomePage)
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const MyHomePage(title: 'E-Stetho'),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                // Apple Sign Up Button
                SignInButton(
                  Buttons.AppleDark,
                  text: "Sign up with Apple",
                  onPressed: () {
                    // Navigate to main.dart homepage (MyHomePage)
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const MyHomePage(title: 'E-Stetho'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Function to build text fields
  Widget _buildTextField({
    required String hintText,
    required IconData icon,
    bool obscureText = false,
  }) {
    return TextField(
      obscureText: obscureText,
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFF3B3B3B), // Dark input box background
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.white70, fontSize: 18),
        prefixIcon: Icon(icon, color: Colors.white70),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
          borderSide: BorderSide.none,
        ),
      ),
      style: const TextStyle(color: Colors.white),
    );
  }
}
