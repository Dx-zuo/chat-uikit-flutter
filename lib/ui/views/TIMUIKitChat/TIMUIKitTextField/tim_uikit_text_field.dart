import 'dart:async';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_setting_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/core/%20tim_uikit_wide_modal_operation_key.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKitTextField/tim_uikit_text_field_layout/narrow.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_state.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/separate_models/tui_chat_separate_view_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_conversation_view_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_self_info_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/platform.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKitTextField/tim_uikit_at_text.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_base.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKitTextField/tim_uikit_text_field_layout/wide.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/wide_popup.dart';

enum MuteStatus { none, me, all }

typedef CustomStickerPanel = Widget Function({
  void Function() sendTextMessage,
  void Function(int index, String data) sendFaceMessage,
  void Function() deleteText,
  void Function(int unicode) addText,
  void Function(String singleEmojiName) addCustomEmojiText,
  List<CustomEmojiFaceData> defaultCustomEmojiStickerList,

  /// If non-null, requires the child to have exactly this width.
  double? width,

  /// If non-null, requires the child to have exactly this height.
  double? height,
});

class TIMUIKitInputTextField extends StatefulWidget {
  /// conversation id
  final String conversationID;

  /// conversation type
  final ConvType conversationType;

  /// init text, use for draft text re-view
  final String? initText;

  /// messageList widget scroll controller
  final AutoScrollController? scrollController;

  /// hint text for textField widget
  final String? hintText;

  /// config for more pannel
  final MorePanelConfig? morePanelConfig;

  /// show send audio icon
  final bool showSendAudio;

  /// show send emoji icon
  final bool showSendEmoji;

  /// show more panel
  final bool showMorePanel;

  /// background color
  final Color? backgroundColor;

  /// control input field behavior
  final TIMUIKitInputTextFieldController? controller;

  /// on text changed
  final void Function(String)? onChanged;

  final TUIChatSeparateViewModel model;

  /// Whether to use the default emoji
  final bool isUseDefaultEmoji;

  final List customEmojiStickerList;

  /// sticker panel customization
  final CustomStickerPanel? customStickerPanel;

  /// Conversation need search
  final V2TimConversation currentConversation;

  final String? groupType;

  const TIMUIKitInputTextField(
      {Key? key,
      required this.conversationID,
      required this.conversationType,
      this.initText,
      this.hintText,
      this.scrollController,
      this.morePanelConfig,
      this.customStickerPanel,
      this.showSendAudio = true,
      this.showSendEmoji = true,
      this.showMorePanel = true,
      this.backgroundColor,
      this.controller,
      this.onChanged,
      this.isUseDefaultEmoji = false,
      this.customEmojiStickerList = const [],
      required this.model,
      required this.currentConversation,
      this.groupType})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => _InputTextFieldState();
}

class _InputTextFieldState extends TIMUIKitState<TIMUIKitInputTextField> {
  final TUIChatGlobalModel globalModel = serviceLocator<TUIChatGlobalModel>();
  final TUISettingModel settingModel = serviceLocator<TUISettingModel>();
  late FocusNode focusNode;
  String zeroWidthSpace = '\ufeff';
  String lastText = "";
  String languageType = "";
  int? currentCursor;

  Map<String, V2TimGroupMemberFullInfo> memberInfoMap = {};

  late TextEditingController textEditingController;
  final TUIConversationViewModel conversationModel =
      serviceLocator<TUIConversationViewModel>();
  final TUISelfInfoViewModel selfModel = serviceLocator<TUISelfInfoViewModel>();
  MuteStatus muteStatus = MuteStatus.none;

  int latestSendEditStatusTime = DateTime.now().millisecondsSinceEpoch;

  setCurrentCursor(int? value) {
    currentCursor = value;
  }

  void addStickerToText(String sticker) {
    final oldText = textEditingController.text;
    if (currentCursor != null && currentCursor! > -1) {
      final firstString = oldText.substring(0, currentCursor);
      final secondString = oldText.substring(currentCursor!);
      currentCursor = currentCursor! + sticker.length;
      textEditingController.text = "$firstString$sticker$secondString";
    } else {
      textEditingController.text = "$oldText$sticker";
    }

    if (TUIKitScreenUtils.getFormFactor(context) == ScreenType.Wide) {
      focusNode.unfocus();
    }
  }

  String _filterU200b(String text) {
    return text.replaceAll(RegExp(r'\ufeff'), "");
  }

  getShowName(message) {
    return message.friendRemark == null || message.friendRemark == ''
        ? message.nickName == null || message.nickName == ''
            ? message.sender
            : message.nickName
        : message.friendRemark;
  }

  handleSetDraftText([String? id, ConvType? convType]) async {
    String convID = id ?? widget.conversationID;
    String conversationID =
        (convType ?? widget.conversationType) == ConvType.c2c
            ? "c2c_$convID"
            : "group_$convID";
    String text = textEditingController.text;
    String? draftText = _filterU200b(text);

    if (draftText.isEmpty) {
      draftText = "";
    }
    await conversationModel.setConversationDraft(
        conversationID: conversationID, draftText: draftText);
  }

  backSpaceText() {
    String originalText = textEditingController.text;
    dynamic text;

    if (originalText == zeroWidthSpace) {
      _handleSoftKeyBoardDelete();
      // _addDeleteTag();
    } else {
      text = originalText.characters.skipLast(1);
      textEditingController.text = text;
      // handleSetDraftText();
    }
  }

// 和onSubmitted一样，只是保持焦点的不同
  onEmojiSubmitted() {
    lastText = "";
    final text = textEditingController.text.trim();
    final convType = widget.conversationType;
    if (text.isNotEmpty && text != zeroWidthSpace) {
      if (widget.model.repliedMessage != null) {
        MessageUtils.handleMessageError(
            widget.model.sendReplyMessage(
                text: text, convID: widget.conversationID, convType: convType),
            context);
      } else {
        MessageUtils.handleMessageError(
            widget.model.sendTextMessage(
                text: text, convID: widget.conversationID, convType: convType),
            context);
      }
      textEditingController.clear();
      goDownBottom();
    }
    currentCursor = null;
  }

// index为emoji的index,data为baseurl+name
  onCustomEmojiFaceSubmitted(int index, String data) {
    final convType = widget.conversationType;
    if (widget.model.repliedMessage != null) {
      MessageUtils.handleMessageError(
          widget.model.sendFaceMessage(
              index: index,
              data: data,
              convID: widget.conversationID,
              convType: convType),
          context);
    } else {
      MessageUtils.handleMessageError(
          widget.model.sendFaceMessage(
              index: index,
              data: data,
              convID: widget.conversationID,
              convType: convType),
          context);
    }
  }

  List<String> getUserIdFromMemberInfoMap() {
    List<String> userList = [];
    memberInfoMap.forEach((String key, V2TimGroupMemberFullInfo info) {
      userList.add(info.userID);
    });

    return userList;
  }

  onSubmitted() async {
    lastText = "";
    final text = textEditingController.text.trim();
    final convType = widget.conversationType;
    if (text.isNotEmpty && text != zeroWidthSpace) {
      if (widget.model.repliedMessage != null) {
        MessageUtils.handleMessageError(
            widget.model.sendReplyMessage(
                text: text, convID: widget.conversationID, convType: convType),
            context);
      } else if (memberInfoMap.isNotEmpty) {
        widget.model.sendTextAtMessage(
            text: text,
            convType: widget.conversationType,
            convID: widget.conversationID,
            atUserList: getUserIdFromMemberInfoMap());
      } else {
        MessageUtils.handleMessageError(
            widget.model.sendTextMessage(
                text: text, convID: widget.conversationID, convType: convType),
            context);
      }
      textEditingController.clear();
      currentCursor = null;
      lastText = "";
      memberInfoMap = {};

      goDownBottom();
      _handleSendEditStatus("", false);
    }
  }

  void goDownBottom() {
    if (globalModel.getMessageListPosition(widget.conversationID) ==
        HistoryMessagePosition.notShowLatest) {
      return;
    }
    Future.delayed(const Duration(milliseconds: 50), () {
      try {
        if (widget.scrollController != null) {
          widget.scrollController!.animateTo(
            widget.scrollController!.position.minScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.ease,
          );
        }
      // ignore: empty_catches
      } catch (e) {
      }
    });
  }

  void onModelChanged() {
    if (widget.model.repliedMessage != null) {
      narrowTextFieldKey.currentState?.showKeyboard = true;
      focusNode.requestFocus();
      _addDeleteTag();
    } else {}
    if (widget.model.editRevokedMsg != "") {
      narrowTextFieldKey.currentState?.showKeyboard = true;
      focusNode.requestFocus();
      textEditingController.clear();
      textEditingController.text = widget.model.editRevokedMsg;
      textEditingController.selection = TextSelection.fromPosition(TextPosition(
          affinity: TextAffinity.downstream,
          offset: widget.model.editRevokedMsg.length)
      );
      widget.model.editRevokedMsg = "";
    }
  }

  _addDeleteTag() {
    final originalText = textEditingController.text;
    textEditingController.text = zeroWidthSpace + originalText;
    textEditingController.selection = TextSelection.fromPosition(
        TextPosition(offset: textEditingController.text.length));
  }

  _onCursorChange() {
    final selection = textEditingController.selection;
    currentCursor = selection.baseOffset;
  }

  _handleSoftKeyBoardDelete() {
    if (widget.model.repliedMessage != null) {
      widget.model.repliedMessage = null;
    }
  }

  _getShowName(V2TimGroupMemberFullInfo? item) {
    final nameCard = item?.nameCard ?? "";
    final nickName = item?.nickName ?? "";
    final userID = item?.userID ?? "";
    return nameCard.isNotEmpty
        ? nameCard
        : nickName.isNotEmpty
            ? nickName
            : userID;
  }

  _longPressToAt(String? userID, String? nickName) {
    final memberInfo = V2TimGroupMemberFullInfo(
      userID: userID ?? "",
      nickName: nickName,
    );
    final showName = _getShowName(memberInfo);
    memberInfoMap["@$showName"] = memberInfo;
    String text = "${textEditingController.text}@$showName ";
    //please do not delete space
    focusNode.requestFocus();
    textEditingController.text = text;
    textEditingController.selection =
        TextSelection.fromPosition(TextPosition(offset: text.length - 1));
    lastText = text;
  }

  _handleAtText(String text, TUIChatSeparateViewModel model) async {
    String? groupID = widget.conversationType == ConvType.group
        ? widget.conversationID
        : null;

    if (groupID == null) {
      lastText = text;
      return;
    }

    RegExp atTextReg = RegExp(r'@([^@\s]*)');

    int textLength = text.length;
    // 删除的话
    if (lastText.length > textLength && text != "@") {
      Map<String, V2TimGroupMemberFullInfo> map = {};
      Iterable<Match> matches = atTextReg.allMatches(text);
      List<String?> parseAtList = [];
      for (final item in matches) {
        final str = item.group(0);
        parseAtList.add(str);
      }
      for (String? key in parseAtList) {
        if (key != null && memberInfoMap[key] != null) {
          map[key] = memberInfoMap[key]!;
        }
      }
      memberInfoMap = map;
    }
    // 有@的情况并且是文本新增的时候
    if (textLength > 0 &&
        text[textLength - 1] == "@" &&
        lastText.length < textLength) {
      final isWideScreen =
          TUIKitScreenUtils.getFormFactor(context) == ScreenType.Wide;
      if (isWideScreen) {
        TUIKitWidePopup.showPopupWindow(
          operationKey: TUIKitWideModalOperationKey.chooseMentionedMembers,
          context: context,
          width: MediaQuery.of(context).size.width * 0.3,
          height: MediaQuery.of(context).size.width * 0.4,
          title: TIM_t("选择提醒人"),
          child: (closeFunc) => AtText(
              groupMemberList: model.groupMemberList,
              groupInfo: model.groupInfo,
              groupID: groupID,
              closeFunc: closeFunc,
              onChooseMember: (memberInfo, tapDetails) {
                final showName = _getShowName(memberInfo);
                memberInfoMap["@$showName"] = memberInfo;
                textEditingController.text = "$text$showName ";
                currentCursor = textEditingController.text.length - 1;
                textEditingController.selection = TextSelection.fromPosition(
                    TextPosition(offset: "$text$showName ".length));
              },
              groupType: widget.groupType),
        );
      } else {
        V2TimGroupMemberFullInfo? memberInfo = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AtText(
                groupMemberList: model.groupMemberList,
                groupInfo: model.groupInfo,
                groupID: groupID,
                groupType: widget.groupType),
          ),
        );
        final showName = _getShowName(memberInfo);
        if (memberInfo != null) {
          memberInfoMap["@$showName"] = memberInfo;
          textEditingController.text = "$text$showName ";
        }
      }
    }
    lastText = text;
  }

  @override
  void initState() {
    super.initState();
    if (PlatformUtils().isWeb) {
      focusNode = FocusNode(
        onKey: (node, event) {
          if (event.isKeyPressed(LogicalKeyboardKey.enter)) {
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
      );
    } else {
      focusNode = FocusNode();
    }
    textEditingController =
        widget.controller?.textEditingController ?? TextEditingController();
    if (widget.controller != null) {
      widget.controller?.addListener(() {
        final actionType = widget.controller?.actionType;
        if (actionType == ActionType.longPressToAt) {
          _longPressToAt(
              widget.controller?.atUserID, widget.controller?.atUserName);
        }
      });
    }
    widget.model.addListener(onModelChanged);
    if (widget.initText != null) {
      textEditingController.text = widget.initText!;
    }
    final AppLocale appLocale = I18nUtils.findDeviceLocale(null);
    languageType =
        (appLocale == AppLocale.zhHans || appLocale == AppLocale.zhHant)
            ? 'zh'
            : 'en';
  }

  @override
  void didUpdateWidget(TIMUIKitInputTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.conversationID != oldWidget.conversationID) {
      handleSetDraftText(oldWidget.conversationID, oldWidget.conversationType);
      if (oldWidget.initText != widget.initText) {
        textEditingController.text = widget.initText ?? "";
      } else {
        textEditingController.text = "";
      }
    }
  }

  @override
  void dispose() {
    handleSetDraftText();
    widget.model.removeListener(onModelChanged);
    focusNode.dispose();
    super.dispose();
  }

  Future<bool> getMemberMuteStatus(String userID) async {
    // Get the mute state of the members recursively
    if (widget.model.groupMemberList?.any((item) => (item?.userID == userID)) ??
        false) {
      final int muteUntil = widget.model.groupMemberList
              ?.firstWhere((item) => (item?.userID == userID))
              ?.muteUntil ??
          0;
      return muteUntil * 1000 > DateTime.now().millisecondsSinceEpoch;
    } else {
      return false;
    }
  }

  _getMuteType(TUIChatSeparateViewModel model) async {
    if (widget.conversationType == ConvType.group) {
      if ((model.groupInfo?.isAllMuted ?? false) &&
          muteStatus != MuteStatus.all) {
        Future.delayed(const Duration(seconds: 0), () {
          setState(() {
            muteStatus = MuteStatus.all;
          });
        });
      } else if (selfModel.loginInfo?.userID != null &&
          await getMemberMuteStatus(selfModel.loginInfo!.userID!) &&
          muteStatus != MuteStatus.me) {
        Future.delayed(const Duration(seconds: 0), () {
          setState(() {
            muteStatus = MuteStatus.me;
          });
        });
      } else if (!(model.groupInfo?.isAllMuted ?? false) &&
          !(selfModel.loginInfo?.userID != null &&
              await getMemberMuteStatus(selfModel.loginInfo!.userID!)) &&
          muteStatus != MuteStatus.none) {
        Future.delayed(const Duration(seconds: 0), () {
          setState(() {
            muteStatus = MuteStatus.none;
          });
        });
      }
    }
  }

  _handleSendEditStatus(String value, bool status) {
    int now = DateTime.now().millisecondsSinceEpoch;
    if (value.isNotEmpty && widget.conversationType == ConvType.c2c) {
      if (status) {
        if (now - latestSendEditStatusTime < 5 * 1000) {
          return;
        }
      }
      // send status
      globalModel.sendEditStatusMessage(status, widget.conversationID);
      latestSendEditStatusTime = now;
    } else {
      globalModel.sendEditStatusMessage(false, widget.conversationID);
    }
  }

  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    final TUIChatSeparateViewModel model =
        Provider.of<TUIChatSeparateViewModel>(context);

    _getMuteType(model);

    return Selector<TUIChatSeparateViewModel, V2TimMessage?>(
        builder: ((context, value, child) {
          String? getForbiddenText() {
            if (!(model.isGroupExist)) {
              return "群组不存在";
            } else if (model.isNotAMember) {
              return "您不是群成员";
            } else if (muteStatus == MuteStatus.all) {
              return "全员禁言中";
            } else if (muteStatus == MuteStatus.me) {
              return "您被禁言";
            }
            return null;
          }

          final forbiddenText = getForbiddenText();
          return TUIKitScreenUtils.getDeviceWidget(
              defaultWidget: TIMUIKitTextFieldLayoutNarrow(
                  onEmojiSubmitted: onEmojiSubmitted,
                  onCustomEmojiFaceSubmitted: onCustomEmojiFaceSubmitted,
                  backSpaceText: backSpaceText,
                  addStickerToText: addStickerToText,
                  customStickerPanel: widget.customStickerPanel,
                  forbiddenText: forbiddenText,
                  onChanged: widget.onChanged,
                  backgroundColor: widget.backgroundColor,
                  morePanelConfig: widget.morePanelConfig,
                  repliedMessage: value,
                  currentCursor: currentCursor,
                  hintText: widget.hintText,
                  isUseDefaultEmoji: widget.isUseDefaultEmoji,
                  languageType: languageType,
                  textEditingController: textEditingController,
                  conversationID: widget.conversationID,
                  conversationType: widget.conversationType,
                  focusNode: focusNode,
                  controller: widget.controller,
                  setCurrentCursor: setCurrentCursor,
                  onCursorChange: _onCursorChange,
                  model: model,
                  handleSendEditStatus: _handleSendEditStatus,
                  handleAtText: (text) {
                    _handleAtText(text, model);
                  },
                  handleSoftKeyBoardDelete: _handleSoftKeyBoardDelete,
                  onSubmitted: onSubmitted,
                  goDownBottom: goDownBottom,
                  showSendAudio: widget.showSendAudio,
                  showSendEmoji: widget.showSendEmoji,
                  showMorePanel: widget.showMorePanel,
                  customEmojiStickerList: widget.customEmojiStickerList),
              wideWidget: TIMUIKitTextFieldLayoutWide(
                  currentConversation: widget.currentConversation,
                  onEmojiSubmitted: onEmojiSubmitted,
                  onCustomEmojiFaceSubmitted: onCustomEmojiFaceSubmitted,
                  backSpaceText: backSpaceText,
                  addStickerToText: addStickerToText,
                  customStickerPanel: widget.customStickerPanel,
                  forbiddenText: forbiddenText,
                  onChanged: widget.onChanged,
                  backgroundColor: widget.backgroundColor,
                  morePanelConfig: widget.morePanelConfig,
                  repliedMessage: value,
                  currentCursor: currentCursor,
                  hintText: widget.hintText,
                  isUseDefaultEmoji: widget.isUseDefaultEmoji,
                  languageType: languageType,
                  textEditingController: textEditingController,
                  conversationID: widget.conversationID,
                  conversationType: widget.conversationType,
                  focusNode: focusNode,
                  controller: widget.controller,
                  setCurrentCursor: setCurrentCursor,
                  onCursorChange: _onCursorChange,
                  model: model,
                  handleSendEditStatus: _handleSendEditStatus,
                  handleAtText: (text) {
                    _handleAtText(text, model);
                  },
                  handleSoftKeyBoardDelete: _handleSoftKeyBoardDelete,
                  onSubmitted: onSubmitted,
                  goDownBottom: goDownBottom,
                  showSendAudio: widget.showSendAudio,
                  showSendEmoji: widget.showSendEmoji,
                  showMorePanel: widget.showMorePanel,
                  customEmojiStickerList: widget.customEmojiStickerList));
        }),
        selector: (c, model) => model.repliedMessage);
  }
}
