import 'dart:async';

import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/utils/logger.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart' hide Response;
import 'package:tuple/tuple.dart';
import 'package:universal_io/io.dart';

ActionHandler ah = Get.isRegistered<ActionHandler>() ? Get.find<ActionHandler>() : Get.put(ActionHandler());

Future<void> saveFileIsolate(Tuple2<String, Uint8List> data) async {
  final file = await File(data.item1).create(recursive: true);
  await file.writeAsBytes(data.item2);
}

class ActionHandler extends GetxService {
  final RxList<Tuple2<String, RxDouble>> attachmentProgress = <Tuple2<String, RxDouble>>[].obs;
  final List<String> outOfOrderTempGuids = [];
  
  Future<List<Message>> prepMessage(Chat c, Message m, Message? selected, String? r) async {
    if ((m.text?.isEmpty ?? true) && (m.subject?.isEmpty ?? true) && r == null) return [];

    final List<Message> messages = <Message>[];

    if (!(await ss.isMinBigSur) && r == null) {
      // Split URL messages on OS X to prevent message matching glitches
      String mainText = m.text!;
      String? secondaryText;
      final match = parseLinks(m.text!.replaceAll("\n", " ")).firstOrNull;
      if (match != null) {
        if (match.start == 0) {
          mainText = m.text!.substring(0, match.end).trimRight();
          secondaryText = m.text!.substring(match.end).trimLeft();
        } else if (match.end == m.text!.length) {
          mainText = m.text!.substring(0, match.start).trimRight();
          secondaryText = m.text!.substring(match.start).trimLeft();
        }
      }

      messages.add(m..text = mainText);
      if (!isNullOrEmpty(secondaryText)!) {
        messages.add(Message(
          text: secondaryText,
          threadOriginatorGuid: m.threadOriginatorGuid,
          threadOriginatorPart: "${m.threadOriginatorPart ?? 0}:0:0",
          expressiveSendStyleId: m.expressiveSendStyleId,
          dateCreated: DateTime.now(),
          hasAttachments: false,
          isFromMe: true,
          handleId: 0,
        ));
      }

      for (Message message in messages) {
        message.generateTempGuid();
        await c.addMessage(message);
      }
    } else {
      m.generateTempGuid();
      await c.addMessage(m);
      messages.add(m);
    }
    return messages;
  }

  Future<void> sendMessage(Chat c, Message m, Message? selected, String? r) async {
    final completer = Completer<void>();
    if (r == null) {
      http.sendMessage(
        c.guid,
        m.guid!,
        m.text!,
        subject: m.subject,
        method: (ss.settings.enablePrivateAPI.value
            && ss.settings.privateAPISend.value)
            || (m.subject?.isNotEmpty ?? false)
            || m.threadOriginatorGuid != null
            || m.expressiveSendStyleId != null
            ? "private-api" : "apple-script",
        selectedMessageGuid: m.threadOriginatorGuid,
        effectId: m.expressiveSendStyleId,
        partIndex: int.tryParse(m.threadOriginatorPart?.split(":").firstOrNull ?? ""),
      ).then((response) async {
        final newMessage = Message.fromMap(response.data['data']);
        try {
          await Message.replaceMessage(m.guid, newMessage);
          Logger.info("Message match: [${newMessage.text}] - ${newMessage.guid} - ${m.guid}", tag: "MessageStatus");
        } catch (_) {
          Logger.info("Message match failed for ${newMessage.guid} - already handled?", tag: "MessageStatus");
        }
        completer.complete();
      }).catchError((error) async {
        Logger.error('Failed to send message! Error: ${error.toString()}');

        final tempGuid = m.guid;
        m = handleSendError(error, m);

        if (!ls.isAlive || !(cm.getChatController(c.guid)?.isAlive ?? false)) {
          await notif.createFailedToSend();
        }
        await Message.replaceMessage(tempGuid, m);
        completer.completeError(error);
      });
    } else {
      http.sendTapback(c.guid, selected!.text ?? "", selected.guid!, r, partIndex: m.associatedMessagePart).then((response) async {
        final newMessage = Message.fromMap(response.data['data']);
        try {
          await Message.replaceMessage(m.guid, newMessage);
          Logger.info("Reaction match: [${newMessage.text}] - ${newMessage.guid} - ${m.guid}", tag: "MessageStatus");
        } catch (_) {
          Logger.info("Reaction match failed for ${newMessage.guid} - already handled?", tag: "MessageStatus");
        }
        completer.complete();
      }).catchError((error) async {
        Logger.error('Failed to send message! Error: ${error.toString()}');

        final tempGuid = m.guid;
        m = handleSendError(error, m);

        if (!ls.isAlive || !(cm.getChatController(c.guid)?.isAlive ?? false)) {
          await notif.createFailedToSend();
        }
        await Message.replaceMessage(tempGuid, m);
        completer.completeError(error);
      });
    }

    return completer.future;
  }
  
  Future<void> prepAttachment(Chat c, Message m) async {
    final attachment = m.attachments.first!;
    final progress = Tuple2(attachment.guid!, 0.0.obs);
    attachmentProgress.add(progress);
    // Save the attachment to storage and DB
    if (!kIsWeb) {
      String pathName = "${fs.appDocDir.path}/attachments/${attachment.guid}/${attachment.transferName}";
      await compute(saveFileIsolate, Tuple2(pathName, attachment.bytes!));
    }
    await c.addMessage(m);
  }

  Future<void> sendAttachment(Chat c, Message m) async {
    if (m.attachments.isEmpty || m.attachments.firstOrNull?.bytes == null) return;
    final attachment = m.attachments.first!;
    final progress = attachmentProgress.firstWhere((e) => e.item1 == attachment.guid);
    final completer = Completer<void>();
    http.sendAttachmentBytes(c.guid, attachment.guid!, attachment.bytes!, attachment.transferName!,
        onSendProgress: (count, total) => progress.item2.value = count / attachment.bytes!.length
    ).then((response) async {
      final newMessage = Message.fromMap(response.data['data']);

      for (Attachment? a in newMessage.attachments) {
        if (a == null) continue;
        Attachment.replaceAttachment(m.guid, a);
      }
      try {
        await Message.replaceMessage(m.guid, newMessage);
        Logger.info("Attachment match: [${newMessage.text}] - ${newMessage.guid} - ${m.guid}", tag: "MessageStatus");
      } catch (_) {
        Logger.info("Attachment match failed for ${newMessage.guid} - already handled?", tag: "MessageStatus");
      }
      attachmentProgress.removeWhere((e) => e.item1 == m.guid || e.item2 >= 1);

      completer.complete();
    }).catchError((error) async {
      Logger.error('Failed to send message! Error: ${error.toString()}');

      final tempGuid = m.guid;
      m = handleSendError(error, m);

      if (!ls.isAlive || !(cm.getChatController(c.guid)?.isAlive ?? false)) {
        await notif.createFailedToSend();
      }
      await Message.replaceMessage(tempGuid, m);
      attachmentProgress.removeWhere((e) => e.item1 == m.guid || e.item2 >= 1);
      completer.completeError(error);
    });

    return completer.future;
  }

  Future<Chat?> createChat(List<String> addresses, String text) async {
    Logger.info("Starting chat to $addresses");

    Message message = Message(
      text: text.trim(),
      dateCreated: DateTime.now(),
      isFromMe: true,
      handleId: 0,
    );
    message.generateTempGuid();

    final response = await http.createChat(addresses, text.trim()).catchError((err) {
      message = handleSendError(err, message);
      showSnackbar("Error", "Failed to create chat! Error code: ${message.error}");
    });

    if (message.error != 0) {
      return null;
    }

    message = Message.fromMap(response.data['data']['messages'].first);
    final chat = Chat.fromMap(response.data['data']);

    // Save the chat and message
    chat.save();
    chat.addMessage(message);
    return chat;
  }

  Future<void> handleNewMessage(Chat c, Message m, String? tempGuid, {bool checkExisting = true}) async {
    // sanity check
    if (checkExisting) {
      final existing = Message.findOne(guid: tempGuid ?? m.guid);
      if (existing != null) {
        return await handleUpdatedMessage(c, m, tempGuid, checkExisting: false);
      }
    }
    // should have been handled by the sanity check
    if (tempGuid != null) return;
    Logger.info("New message: [${m.text}] - for chat [${c.guid}]", tag: "ActionHandler");
    // Gets the chat from the db or server (if new)
    c = m.isParticipantEvent ? await handleNewOrUpdatedChat(c) : (Chat.findOne(guid: c.guid) ?? await handleNewOrUpdatedChat(c));
    // Get the message handle
    final handle = c.handles.firstWhereOrNull((e) => e.originalROWID == m.handleId);
    if (handle != null) {
      m.handleId = handle.id;
      m.handle = handle;
    }
    // Display notification if needed and save everything to DB
    if (!ls.isAlive) {
      await MessageHelper.handleNotification(m, c);
    }
    await c.addMessage(m);
  }

  Future<void> handleUpdatedMessage(Chat c, Message m, String? tempGuid, {bool checkExisting = true}) async {
    // sanity check
    if (checkExisting) {
      final existing = Message.findOne(guid: tempGuid ?? m.guid);
      if (existing == null) {
        return await handleNewMessage(c, m, tempGuid, checkExisting: false);
      }
    }
    Logger.info("Updated message: [${m.text}] - for chat [${c.guid}]", tag: "ActionHandler");
    // update any attachments
    for (Attachment? a in m.attachments) {
      if (a == null) continue;
      Attachment.replaceAttachment(tempGuid ?? m.guid, a);
    }
    // update the message in the DB
    await Message.replaceMessage(tempGuid ?? m.guid, m);
  }

  Future<Chat> handleNewOrUpdatedChat(Chat partialData) async {
    // fetch all contacts for matching new handles if in background
    if (!ls.isUiThread) {
      await cs.init();
    }
    // get and return the chat from server
    return await cm.fetchChat(partialData.guid) ?? partialData;
  }
}