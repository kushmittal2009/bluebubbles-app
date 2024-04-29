import 'package:barcode_widget/barcode_widget.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/rustpush/rustpush_service.dart';
import 'package:bluebubbles/utils/share.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart' hide Response;
import 'package:bluebubbles/src/rust/api/api.dart' as api;

class DevicePanelController extends StatefulController {

  final RxBool allowSharing = false.obs;
}

class DevicePanel extends CustomStateful<DevicePanelController> {
  DevicePanel() : super(parentController: Get.put(DevicePanelController()));

  @override
  State<StatefulWidget> createState() => _DevicePanelState();
}

class _DevicePanelState extends CustomState<DevicePanel, void, DevicePanelController> {

  api.DartDeviceInfo? deviceInfo;
  String deviceName = "";

  @override
  void initState() {
    super.initState();
    api.getDeviceInfoState(state: pushService.state).then((value) {
      setState(() {
        deviceInfo = value;
        deviceName = RustPushBBUtils.modelToUser(deviceInfo!.name);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget nextIcon = Obx(() => ss.settings.skin.value != Skins.Material ? Icon(
      ss.settings.skin.value != Skins.Material ? CupertinoIcons.chevron_right : Icons.arrow_forward,
      color: context.theme.colorScheme.outline,
      size: iOS ? 18 : 24,
    ) : const SizedBox.shrink());

    return Obx(
      () => SettingsScaffold(
        title: "${ss.settings.macIsMine.value ? 'My' : 'Shared'} Mac",
        initialHeader: null,
        iosSubtitle: iosSubtitle,
        materialSubtitle: materialSubtitle,
        tileColor: tileColor,
        headerColor: headerColor,
        bodySlivers: [
          SliverList(
            delegate: SliverChildListDelegate(
              <Widget>[
                SettingsSection(
                  backgroundColor: tileColor,
                  children: [
                    Center(
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(25),
                            child: Icon(
                              RustPushBBUtils.isLaptop(deviceName) ? CupertinoIcons.device_laptop : CupertinoIcons.device_desktop,
                              size: 200,
                              color: context.theme.colorScheme.properOnSurface,
                            ),
                          ),
                          Text(deviceName, style: context.theme.textTheme.titleLarge),
                          const SizedBox(height: 10),
                          Text(deviceInfo?.serial ?? ""),
                          const SizedBox(height: 10),
                          Text(deviceInfo?.osVersion ?? ""),
                          const SizedBox(height: 25),
                        ],
                      )
                    ),
                  ],
                ),
                if (ss.settings.macIsMine.value)
                SettingsHeader(
                    iosSubtitle: iosSubtitle,
                    materialSubtitle: materialSubtitle,
                    text: "Share Mac"),
                if (ss.settings.macIsMine.value)
                SettingsSection(
                  backgroundColor: tileColor,
                  children: [
                    Obx(() => SettingsSwitch(
                      onChanged: (bool val) {
                        controller.allowSharing.value = !val;
                      },
                      initialVal: !controller.allowSharing.value,
                      title: "Prevent sharing",
                      backgroundColor: tileColor,
                      subtitle: "Choose your friends wisely. Apple may block devices due to spam or exceeding 20 users.",
                      isThreeLine: true,
                    )),
                    if (deviceInfo != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(15, 0, 15, 0),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: BarcodeWidget.fromBytes(
                          barcode: Barcode.qrCode(
                            errorCorrectLevel: BarcodeQRCorrectionLevel.medium,
                          ),
                          data: pushService.getQrInfo(controller.allowSharing.value, deviceInfo!.encodedData),
                          backgroundColor: const Color(0),
                          color: context.theme.colorScheme.onSurface,
                        ),
                      )),
                    if (kIsDesktop)
                    SettingsTile(
                      backgroundColor: tileColor,
                      title: "Copy Activation Code",
                      onTap: () async {
                        Clipboard.setData(ClipboardData(text: await pushService.uploadCode(controller.allowSharing.value, deviceInfo!)));
                      },
                      trailing: Icon(
                        ss.settings.skin.value == Skins.iOS ? CupertinoIcons.doc_on_clipboard : Icons.copy
                      ),
                      subtitle: controller.allowSharing.value ? null : "Code can only be used once",
                    ),
                    if (!kIsDesktop)
                    SettingsTile(
                      backgroundColor: tileColor,
                      title: "Share Activation Code",
                      onTap: () async {
                        var code = await pushService.uploadCode(controller.allowSharing.value, deviceInfo!);
                        if (code.length > 50) {
                          Share.text("OpenBubbles", "Text me on OpenBubbles with my activation code! $code");
                        } else {
                          Share.text("OpenBubbles", "Text me on OpenBubbles with my activation code! $code\n$rpApiRoot/code/$code");
                        }
                      },
                      subtitle: controller.allowSharing.value ? null : "Code can only be used once",
                      trailing: Icon(
                        ss.settings.skin.value == Skins.iOS ? CupertinoIcons.share : Icons.share
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void saveSettings() {
    ss.saveSettings();
  }
}