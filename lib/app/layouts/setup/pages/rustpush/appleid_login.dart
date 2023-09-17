import 'dart:async';

import 'package:bluebubbles/app/layouts/settings/dialogs/custom_headers_dialog.dart';
import 'package:bluebubbles/app/layouts/setup/pages/page_template.dart';
import 'package:bluebubbles/app/layouts/setup/setup_view.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/ffi.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/rustpush/rustpush_service.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart' hide Response;

class AppleIdLogin extends StatefulWidget {
  @override
  State<AppleIdLogin> createState() => _AppleIdLoginState();
}

class _AppleIdLoginState extends OptimizedState<AppleIdLogin> {
  final TextEditingController appleIdController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final controller = Get.find<SetupViewController>();
  final FocusNode focusNode = FocusNode();

  bool obscureText = true;

  @override
  Widget build(BuildContext context) {
    return SetupPageTemplate(
      title: "Login with your Apple ID",
      subtitle: "Start using BlueBubbles with your Apple ID",
      contentWrapper: (child) => AnimatedSize(
        duration: const Duration(milliseconds: 200),
        child: context.isPhone ? const SizedBox.shrink() : child,
      ),
      customButton: Column(
        children: [
          ErrorText(parentController: controller),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: Theme(
                    data: context.theme.copyWith(
                      inputDecorationTheme: InputDecorationTheme(
                        labelStyle: TextStyle(color: context.theme.colorScheme.outline),
                      ),
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        Container(
                          width: context.width * 2 / 3,
                          child: Focus(
                            focusNode: focusNode,
                            onKey: (node, event) {
                              if (event is RawKeyDownEvent &&
                                  !event.data.isShiftPressed &&
                                  event.logicalKey == LogicalKeyboardKey.tab) {
                                node.nextFocus();
                                return KeyEventResult.handled;
                              }
                              return KeyEventResult.ignored;
                            },
                            child: TextField(
                              cursorColor: context.theme.colorScheme.primary,
                              autocorrect: false,
                              autofocus: false,
                              controller: appleIdController,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: context.theme.colorScheme.outline),
                                    borderRadius: BorderRadius.circular(20)),
                                focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: context.theme.colorScheme.primary),
                                    borderRadius: BorderRadius.circular(20)),
                                labelText: "Apple ID",
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          width: context.width * 2 / 3,
                          child: Focus(
                            onKey: (node, event) {
                              if (event is RawKeyDownEvent &&
                                  event.data.isShiftPressed &&
                                  event.logicalKey == LogicalKeyboardKey.tab) {
                                node.previousFocus();
                                node.previousFocus(); // This is intentional. Should probably figure out why it's needed
                                return KeyEventResult.handled;
                              }
                              return KeyEventResult.ignored;
                            },
                            child: TextField(
                              cursorColor: context.theme.colorScheme.primary,
                              autocorrect: false,
                              autofocus: false,
                              controller: passwordController,
                              textInputAction: TextInputAction.next,
                              onSubmitted: (pass) => connect(appleIdController.text, pass),
                              decoration: InputDecoration(
                                enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: context.theme.colorScheme.outline),
                                    borderRadius: BorderRadius.circular(20)),
                                focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: context.theme.colorScheme.primary),
                                    borderRadius: BorderRadius.circular(20)),
                                labelText: "Password",
                                contentPadding: const EdgeInsets.fromLTRB(12, 24, 40, 16),
                                suffixIcon: IconButton(
                                  icon: Icon(obscureText ? Icons.visibility_off : Icons.visibility),
                                  color: context.theme.colorScheme.outline,
                                  onPressed: () {
                                    setState(() {
                                      obscureText = !obscureText;
                                    });
                                  },
                                ),
                              ),
                              obscureText: obscureText,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(25),
                                gradient: LinearGradient(
                                  begin: AlignmentDirectional.topStart,
                                  colors: [HexColor('2772C3'), HexColor('5CA7F8').darkenPercent(5)],
                                ),
                              ),
                              height: 40,
                              padding: const EdgeInsets.all(2),
                              child: ElevatedButton(
                                style: ButtonStyle(
                                  shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                                    RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20.0),
                                    ),
                                  ),
                                  backgroundColor: MaterialStateProperty.all(context.theme.colorScheme.background),
                                  shadowColor: MaterialStateProperty.all(context.theme.colorScheme.background),
                                  maximumSize: MaterialStateProperty.all(const Size(200, 36)),
                                  minimumSize: MaterialStateProperty.all(const Size(30, 30)),
                                ),
                                onPressed: () async {
                                  controller.pageController.previousPage(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                },
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.arrow_back, color: context.theme.colorScheme.onBackground, size: 20),
                                    const SizedBox(width: 10),
                                    Text("Back",
                                        style: context.theme.textTheme.bodyLarge!
                                            .apply(fontSizeFactor: 1.1, color: context.theme.colorScheme.onBackground)),
                                  ],
                                ),
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(25),
                                gradient: LinearGradient(
                                  begin: AlignmentDirectional.topStart,
                                  colors: [HexColor('2772C3'), HexColor('5CA7F8').darkenPercent(5)],
                                ),
                              ),
                              height: 40,
                              child: ElevatedButton(
                                style: ButtonStyle(
                                  shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                                    RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20.0),
                                    ),
                                  ),
                                  backgroundColor: MaterialStateProperty.all(Colors.transparent),
                                  shadowColor: MaterialStateProperty.all(Colors.transparent),
                                  maximumSize: MaterialStateProperty.all(const Size(200, 36)),
                                  minimumSize: MaterialStateProperty.all(const Size(30, 30)),
                                ),
                                onPressed: () async {
                                  ss.settings.customHeaders.value = {};
                                  http.onInit();
                                  connect(appleIdController.text, passwordController.text);
                                },
                                onLongPress: () async {
                                  await showCustomHeadersDialog(context);
                                  connect(appleIdController.text, passwordController.text);
                                },
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text("Sign In",
                                        style: context.theme.textTheme.bodyLarge!
                                            .apply(fontSizeFactor: 1.1, color: Colors.white)),
                                    const SizedBox(width: 10),
                                    const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> connect(String appleId, String password) async {
    var result = await api.tryAuth(state: pushService.state, username: appleId, password: password);
    if (result == 2) {
      controller.updateConnectError("Bad Username or Password");
    }
    ss.settings.iCloudAccount.value = appleId;
    if (result == 1) {
      controller.updateConnectError("");
      // we need 2fa
      controller.twoFaUser = appleId;
      controller.twoFaPass = password;
      controller.pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      return;
    }
    controller.pageController.animateToPage(
      (controller.pageController.page! + 2).toInt(),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }
}
