
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_app/screens/login_screen.dart';

void main() {
  testWidgets('Raqeeb Login Screen UI Test', (WidgetTester tester) async {
    // Display the login screen without calling Firebase.
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginScreen(),
      ),
    );

    // Check the application name.
    expect(find.text('رقيب'), findsOneWidget);

    // Check the login heading.
expect(find.text('تسجيل الدخول'), findsNWidgets(2));
    // Check email and password fields.
    expect(find.byType(TextFormField), findsNWidgets(2));

    // Check the login button.
    expect(find.byType(ElevatedButton), findsOneWidget);

    // Check the admin-managed account message.
    expect(
      find.text('للحصول على حساب، يرجى التواصل مع المسؤول'),
      findsOneWidget,
    );
  });
}
