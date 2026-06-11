import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final url = Uri.parse('https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=AIzaSyAKlR59P2gbnvVHv9V19QhGvFXA6lpDvV4');
  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'email': 'aymen@domfix.com',
      'password': '12345678',
      'returnSecureToken': true,
    }),
  );
  
  if (response.statusCode == 200) {
    print('User created successfully:');
    print(response.body);
  } else {
    print('Failed or already exists:');
    print(response.body);
    
    // If exists, try sign in to get UID
    final signInUrl = Uri.parse('https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=AIzaSyAKlR59P2gbnvVHv9V19QhGvFXA6lpDvV4');
    final signInResponse = await http.post(
      signInUrl,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': 'aymen@domfix.com',
        'password': '12345678',
        'returnSecureToken': true,
      }),
    );
    print('Sign in response:');
    print(signInResponse.body);
  }
}
