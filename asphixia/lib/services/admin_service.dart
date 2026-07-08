import 'package:firebase_auth/firebase_auth.dart';

class AdminService {
  static const Set<String> adminEmails = {'joseuniverse909@gmail.com'};

  static bool isAdmin(User? user) {
    final email = user?.email?.toLowerCase();
    return email != null && adminEmails.contains(email);
  }
}
