import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
    Locale('zh', 'TW'),
  ];

  /// The application name
  ///
  /// In zh, this message translates to:
  /// **'日程清单'**
  String get appTitle;

  /// No description provided for @backToToday.
  ///
  /// In zh, this message translates to:
  /// **'回到今天'**
  String get backToToday;

  /// No description provided for @addTodayWork.
  ///
  /// In zh, this message translates to:
  /// **'添加今日工作'**
  String get addTodayWork;

  /// No description provided for @loadFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载失败'**
  String get loadFailed;

  /// No description provided for @nextWeek.
  ///
  /// In zh, this message translates to:
  /// **'未来一周'**
  String get nextWeek;

  /// No description provided for @nextWeekEmpty.
  ///
  /// In zh, this message translates to:
  /// **'未来一周暂无工作安排'**
  String get nextWeekEmpty;

  /// No description provided for @today.
  ///
  /// In zh, this message translates to:
  /// **'今天'**
  String get today;

  /// No description provided for @total.
  ///
  /// In zh, this message translates to:
  /// **'合计'**
  String get total;

  /// No description provided for @addWork.
  ///
  /// In zh, this message translates to:
  /// **'添加工作'**
  String get addWork;

  /// No description provided for @noWorkTitle.
  ///
  /// In zh, this message translates to:
  /// **'当天还没有工作安排'**
  String get noWorkTitle;

  /// No description provided for @noWorkSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'点击下方按钮添加工作'**
  String get noWorkSubtitle;

  /// No description provided for @confirmDelete.
  ///
  /// In zh, this message translates to:
  /// **'确认删除'**
  String get confirmDelete;

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get delete;

  /// No description provided for @deleted.
  ///
  /// In zh, this message translates to:
  /// **'已删除'**
  String get deleted;

  /// No description provided for @deleteFailed.
  ///
  /// In zh, this message translates to:
  /// **'删除失败'**
  String get deleteFailed;

  /// No description provided for @noTitle.
  ///
  /// In zh, this message translates to:
  /// **'(无标题)'**
  String get noTitle;

  /// No description provided for @loadNoteFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载笔记失败'**
  String get loadNoteFailed;

  /// No description provided for @saveSuccess.
  ///
  /// In zh, this message translates to:
  /// **'保存成功！'**
  String get saveSuccess;

  /// No description provided for @saveFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存失败'**
  String get saveFailed;

  /// No description provided for @imageInserted.
  ///
  /// In zh, this message translates to:
  /// **'图片已插入'**
  String get imageInserted;

  /// No description provided for @insertImageFailed.
  ///
  /// In zh, this message translates to:
  /// **'插入图片失败'**
  String get insertImageFailed;

  /// No description provided for @selectImageFailed.
  ///
  /// In zh, this message translates to:
  /// **'选择图片失败'**
  String get selectImageFailed;

  /// No description provided for @takePhotoFailed.
  ///
  /// In zh, this message translates to:
  /// **'拍照失败'**
  String get takePhotoFailed;

  /// No description provided for @cameraPermissionError.
  ///
  /// In zh, this message translates to:
  /// **'无法使用相机，请在系统设置中允许相机权限'**
  String get cameraPermissionError;

  /// No description provided for @deleteNote.
  ///
  /// In zh, this message translates to:
  /// **'删除笔记'**
  String get deleteNote;

  /// No description provided for @save.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get save;

  /// No description provided for @remarks.
  ///
  /// In zh, this message translates to:
  /// **'备注'**
  String get remarks;

  /// No description provided for @remarksPlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'写写今天的工作内容和感受...'**
  String get remarksPlaceholder;

  /// No description provided for @galleryImage.
  ///
  /// In zh, this message translates to:
  /// **'相册图片'**
  String get galleryImage;

  /// No description provided for @takePhoto.
  ///
  /// In zh, this message translates to:
  /// **'拍照'**
  String get takePhoto;

  /// No description provided for @drawingBoard.
  ///
  /// In zh, this message translates to:
  /// **'画板'**
  String get drawingBoard;

  /// No description provided for @images.
  ///
  /// In zh, this message translates to:
  /// **'图片'**
  String get images;

  /// No description provided for @tapToViewFullImage.
  ///
  /// In zh, this message translates to:
  /// **'点击可查看大图'**
  String get tapToViewFullImage;

  /// No description provided for @wageStatistics.
  ///
  /// In zh, this message translates to:
  /// **'工资统计'**
  String get wageStatistics;

  /// No description provided for @retry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get retry;

  /// No description provided for @statsHidden.
  ///
  /// In zh, this message translates to:
  /// **'统计数据已隐藏'**
  String get statsHidden;

  /// No description provided for @statsHiddenHint.
  ///
  /// In zh, this message translates to:
  /// **'可在 设置 → 隐私设置 中关闭隐藏'**
  String get statsHiddenHint;

  /// No description provided for @noWageRecords.
  ///
  /// In zh, this message translates to:
  /// **'还没有工资记录'**
  String get noWageRecords;

  /// No description provided for @noWageRecordsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'添加工作笔记并填写工资后即可查看统计'**
  String get noWageRecordsSubtitle;

  /// No description provided for @recent6MonthsTrend.
  ///
  /// In zh, this message translates to:
  /// **'近6个月收入趋势'**
  String get recent6MonthsTrend;

  /// No description provided for @noData.
  ///
  /// In zh, this message translates to:
  /// **'暂无数据'**
  String get noData;

  /// No description provided for @workCount.
  ///
  /// In zh, this message translates to:
  /// **'共{count}次'**
  String workCount(int count);

  /// No description provided for @month.
  ///
  /// In zh, this message translates to:
  /// **'月'**
  String get month;

  /// No description provided for @privacySettings.
  ///
  /// In zh, this message translates to:
  /// **'隐私设置'**
  String get privacySettings;

  /// No description provided for @privacyDescription.
  ///
  /// In zh, this message translates to:
  /// **'隐私设置帮助你控制在应用中显示的敏感信息。开启隐藏后，相关数据将以\"***\"代替。'**
  String get privacyDescription;

  /// No description provided for @hideIncomeAmount.
  ///
  /// In zh, this message translates to:
  /// **'隐藏收入金额'**
  String get hideIncomeAmount;

  /// No description provided for @hideIncomeAmountSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'开启后，所有页面的收入金额将显示为\"***\"'**
  String get hideIncomeAmountSubtitle;

  /// No description provided for @hideStatisticsPage.
  ///
  /// In zh, this message translates to:
  /// **'隐藏统计页面'**
  String get hideStatisticsPage;

  /// No description provided for @hideStatisticsPageSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'开启后，统计Tab将显示为空状态，保护你的收入数据隐私'**
  String get hideStatisticsPageSubtitle;

  /// No description provided for @privacyHint.
  ///
  /// In zh, this message translates to:
  /// **'隐私设置即时生效，无需重启应用'**
  String get privacyHint;

  /// No description provided for @settings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settings;

  /// No description provided for @appearance.
  ///
  /// In zh, this message translates to:
  /// **'外观'**
  String get appearance;

  /// No description provided for @followSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get followSystem;

  /// No description provided for @followSystemSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'自动跟随系统亮色/暗色设置'**
  String get followSystemSubtitle;

  /// No description provided for @lightMode.
  ///
  /// In zh, this message translates to:
  /// **'浅色模式'**
  String get lightMode;

  /// No description provided for @lightModeSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'始终使用浅色主题'**
  String get lightModeSubtitle;

  /// No description provided for @darkMode.
  ///
  /// In zh, this message translates to:
  /// **'深色模式'**
  String get darkMode;

  /// No description provided for @darkModeSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'始终使用暗色主题'**
  String get darkModeSubtitle;

  /// No description provided for @privacy.
  ///
  /// In zh, this message translates to:
  /// **'隐私'**
  String get privacy;

  /// No description provided for @privacyNavTitle.
  ///
  /// In zh, this message translates to:
  /// **'隐私设置'**
  String get privacyNavTitle;

  /// No description provided for @privacyNavSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'控制收入金额和统计数据的显示'**
  String get privacyNavSubtitle;

  /// No description provided for @data.
  ///
  /// In zh, this message translates to:
  /// **'数据'**
  String get data;

  /// No description provided for @exportData.
  ///
  /// In zh, this message translates to:
  /// **'导出数据'**
  String get exportData;

  /// No description provided for @exporting.
  ///
  /// In zh, this message translates to:
  /// **'正在导出...'**
  String get exporting;

  /// No description provided for @exportDataSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'将全部工作笔记导出为文件'**
  String get exportDataSubtitle;

  /// No description provided for @backupAndRestore.
  ///
  /// In zh, this message translates to:
  /// **'备份与恢复'**
  String get backupAndRestore;

  /// No description provided for @processing.
  ///
  /// In zh, this message translates to:
  /// **'处理中...'**
  String get processing;

  /// No description provided for @backupAndRestoreSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'导出数据库备份或从备份恢复'**
  String get backupAndRestoreSubtitle;

  /// No description provided for @cloudBackupWebDAV.
  ///
  /// In zh, this message translates to:
  /// **'云备份 (WebDAV)'**
  String get cloudBackupWebDAV;

  /// No description provided for @cloudBackupSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'备份到坚果云或自定义服务器'**
  String get cloudBackupSubtitle;

  /// No description provided for @about.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get about;

  /// No description provided for @aboutAppTitle.
  ///
  /// In zh, this message translates to:
  /// **'关于日程清单'**
  String get aboutAppTitle;

  /// No description provided for @aboutAppSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'版本 1.0.0 —— 让每一份付出都有记录'**
  String get aboutAppSubtitle;

  /// No description provided for @aboutAppName.
  ///
  /// In zh, this message translates to:
  /// **'日程清单'**
  String get aboutAppName;

  /// No description provided for @aboutAppLegalese.
  ///
  /// In zh, this message translates to:
  /// **'帮助日结兼职人员轻松记录工作与收入'**
  String get aboutAppLegalese;

  /// No description provided for @aboutAppBody.
  ///
  /// In zh, this message translates to:
  /// **'温暖地记录每一天的辛劳，让付出可视化。'**
  String get aboutAppBody;

  /// No description provided for @projectHomepage.
  ///
  /// In zh, this message translates to:
  /// **'项目主页'**
  String get projectHomepage;

  /// No description provided for @projectHomepageSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'在浏览器中查看源代码'**
  String get projectHomepageSubtitle;

  /// No description provided for @errorLog.
  ///
  /// In zh, this message translates to:
  /// **'错误日志'**
  String get errorLog;

  /// No description provided for @errorLogSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'查看应用运行时的错误记录'**
  String get errorLogSubtitle;

  /// No description provided for @checkUpdate.
  ///
  /// In zh, this message translates to:
  /// **'检查更新'**
  String get checkUpdate;

  /// No description provided for @checkUpdateSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'检查是否有新版本可用'**
  String get checkUpdateSubtitle;

  /// No description provided for @noUpdatesAvailable.
  ///
  /// In zh, this message translates to:
  /// **'当前已是最新版本'**
  String get noUpdatesAvailable;

  /// No description provided for @updateAvailable.
  ///
  /// In zh, this message translates to:
  /// **'发现新版本：v{version}'**
  String updateAvailable(String version);

  /// No description provided for @checkUpdateFailed.
  ///
  /// In zh, this message translates to:
  /// **'检查更新失败'**
  String get checkUpdateFailed;

  /// No description provided for @noErrorLogs.
  ///
  /// In zh, this message translates to:
  /// **'暂无错误记录'**
  String get noErrorLogs;

  /// No description provided for @errorLogTitle.
  ///
  /// In zh, this message translates to:
  /// **'错误日志'**
  String get errorLogTitle;

  /// No description provided for @selectExportFormat.
  ///
  /// In zh, this message translates to:
  /// **'选择导出格式'**
  String get selectExportFormat;

  /// No description provided for @exportDialogContent.
  ///
  /// In zh, this message translates to:
  /// **'将全部工作笔记导出为文件，请选择格式：'**
  String get exportDialogContent;

  /// No description provided for @csv.
  ///
  /// In zh, this message translates to:
  /// **'CSV'**
  String get csv;

  /// No description provided for @json.
  ///
  /// In zh, this message translates to:
  /// **'JSON'**
  String get json;

  /// No description provided for @exportShareSubject.
  ///
  /// In zh, this message translates to:
  /// **'日程清单数据导出'**
  String get exportShareSubject;

  /// No description provided for @exportShareText.
  ///
  /// In zh, this message translates to:
  /// **'日程清单导出的工作笔记数据'**
  String get exportShareText;

  /// No description provided for @exportFailed.
  ///
  /// In zh, this message translates to:
  /// **'导出失败'**
  String get exportFailed;

  /// No description provided for @backupRestoreDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'备份与恢复'**
  String get backupRestoreDialogTitle;

  /// No description provided for @backupRestoreDialogContent.
  ///
  /// In zh, this message translates to:
  /// **'备份：将数据库导出为文件\n恢复：从备份文件恢复数据（会覆盖当前数据）'**
  String get backupRestoreDialogContent;

  /// No description provided for @backup.
  ///
  /// In zh, this message translates to:
  /// **'备份'**
  String get backup;

  /// No description provided for @restore.
  ///
  /// In zh, this message translates to:
  /// **'恢复'**
  String get restore;

  /// No description provided for @backupFilePrefix.
  ///
  /// In zh, this message translates to:
  /// **'日程清单_备份_'**
  String get backupFilePrefix;

  /// No description provided for @backupShareSubject.
  ///
  /// In zh, this message translates to:
  /// **'日程清单数据备份'**
  String get backupShareSubject;

  /// No description provided for @backupShareText.
  ///
  /// In zh, this message translates to:
  /// **'日程清单数据库备份文件'**
  String get backupShareText;

  /// No description provided for @backupFailed.
  ///
  /// In zh, this message translates to:
  /// **'备份失败'**
  String get backupFailed;

  /// No description provided for @dbFileNotExist.
  ///
  /// In zh, this message translates to:
  /// **'数据库文件不存在'**
  String get dbFileNotExist;

  /// No description provided for @restoreSuccess.
  ///
  /// In zh, this message translates to:
  /// **'恢复成功！请重启应用以加载数据'**
  String get restoreSuccess;

  /// No description provided for @restoreFailed.
  ///
  /// In zh, this message translates to:
  /// **'恢复失败'**
  String get restoreFailed;

  /// No description provided for @language.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get language;

  /// No description provided for @chinese.
  ///
  /// In zh, this message translates to:
  /// **'中文'**
  String get chinese;

  /// No description provided for @english.
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @traditionalChinese.
  ///
  /// In zh, this message translates to:
  /// **'繁體中文'**
  String get traditionalChinese;

  /// No description provided for @cloudBackup.
  ///
  /// In zh, this message translates to:
  /// **'云备份'**
  String get cloudBackup;

  /// No description provided for @instructions.
  ///
  /// In zh, this message translates to:
  /// **'说明'**
  String get instructions;

  /// No description provided for @webdavInfo.
  ///
  /// In zh, this message translates to:
  /// **'支持坚果云等标准 WebDAV 服务器'**
  String get webdavInfo;

  /// No description provided for @jianguoyunInfo.
  ///
  /// In zh, this message translates to:
  /// **'坚果云用户请在「账户信息 → 安全选项」中生成应用密码'**
  String get jianguoyunInfo;

  /// No description provided for @backupPathInfo.
  ///
  /// In zh, this message translates to:
  /// **'备份文件将存储在云盘 daily_gig_journal 目录下'**
  String get backupPathInfo;

  /// No description provided for @serverConfig.
  ///
  /// In zh, this message translates to:
  /// **'服务器配置'**
  String get serverConfig;

  /// No description provided for @serverAddress.
  ///
  /// In zh, this message translates to:
  /// **'服务器地址'**
  String get serverAddress;

  /// No description provided for @accountLabel.
  ///
  /// In zh, this message translates to:
  /// **'账号（坚果云为注册邮箱）'**
  String get accountLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In zh, this message translates to:
  /// **'密码（坚果云需使用应用密码）'**
  String get passwordLabel;

  /// No description provided for @appPasswordHint.
  ///
  /// In zh, this message translates to:
  /// **'应用密码（非登录密码）'**
  String get appPasswordHint;

  /// No description provided for @testing.
  ///
  /// In zh, this message translates to:
  /// **'测试中...'**
  String get testing;

  /// No description provided for @testConnection.
  ///
  /// In zh, this message translates to:
  /// **'测试连接'**
  String get testConnection;

  /// No description provided for @actions.
  ///
  /// In zh, this message translates to:
  /// **'操作'**
  String get actions;

  /// No description provided for @backingUp.
  ///
  /// In zh, this message translates to:
  /// **'备份中...'**
  String get backingUp;

  /// No description provided for @backupToCloud.
  ///
  /// In zh, this message translates to:
  /// **'备份到云盘'**
  String get backupToCloud;

  /// No description provided for @restoring.
  ///
  /// In zh, this message translates to:
  /// **'恢复中...'**
  String get restoring;

  /// No description provided for @restoreFromCloud.
  ///
  /// In zh, this message translates to:
  /// **'从云盘恢复'**
  String get restoreFromCloud;

  /// No description provided for @autoBackup.
  ///
  /// In zh, this message translates to:
  /// **'自动备份'**
  String get autoBackup;

  /// No description provided for @autoBackupTitle.
  ///
  /// In zh, this message translates to:
  /// **'保存/删除时自动备份'**
  String get autoBackupTitle;

  /// No description provided for @autoBackupSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'开启后，每次新增、修改或删除日程时自动备份到云盘'**
  String get autoBackupSubtitle;

  /// No description provided for @confirmRestore.
  ///
  /// In zh, this message translates to:
  /// **'确认恢复'**
  String get confirmRestore;

  /// No description provided for @confirmRestoreButton.
  ///
  /// In zh, this message translates to:
  /// **'确认恢复'**
  String get confirmRestoreButton;

  /// No description provided for @confirmRestoreDialogContent.
  ///
  /// In zh, this message translates to:
  /// **'恢复数据将覆盖当前所有数据，此操作不可撤销。\n建议先备份当前数据再执行恢复。'**
  String get confirmRestoreDialogContent;

  /// No description provided for @restoreSuccessCloud.
  ///
  /// In zh, this message translates to:
  /// **'恢复成功！请重启应用以加载恢复的数据'**
  String get restoreSuccessCloud;

  /// No description provided for @restoreFailedCloud.
  ///
  /// In zh, this message translates to:
  /// **'恢复失败'**
  String get restoreFailedCloud;

  /// No description provided for @backupFailedCloud.
  ///
  /// In zh, this message translates to:
  /// **'备份失败'**
  String get backupFailedCloud;

  /// No description provided for @selectBackupFile.
  ///
  /// In zh, this message translates to:
  /// **'选择备份文件'**
  String get selectBackupFile;

  /// No description provided for @selectBackupFileSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'点击文件即可恢复该日期的备份'**
  String get selectBackupFileSubtitle;

  /// No description provided for @fetchingFileList.
  ///
  /// In zh, this message translates to:
  /// **'正在获取备份文件列表...'**
  String get fetchingFileList;

  /// No description provided for @noBackupFiles.
  ///
  /// In zh, this message translates to:
  /// **'云端没有找到备份文件'**
  String get noBackupFiles;

  /// No description provided for @fetchFileListFailed.
  ///
  /// In zh, this message translates to:
  /// **'获取文件列表失败'**
  String get fetchFileListFailed;

  /// No description provided for @calendarTab.
  ///
  /// In zh, this message translates to:
  /// **'日历'**
  String get calendarTab;

  /// No description provided for @statisticsTab.
  ///
  /// In zh, this message translates to:
  /// **'统计'**
  String get statisticsTab;

  /// No description provided for @settingsTab.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settingsTab;

  /// No description provided for @basicInfo.
  ///
  /// In zh, this message translates to:
  /// **'基本信息'**
  String get basicInfo;

  /// No description provided for @workTitle.
  ///
  /// In zh, this message translates to:
  /// **'工作标题'**
  String get workTitle;

  /// No description provided for @workTitleHint.
  ///
  /// In zh, this message translates to:
  /// **'例如：会展协助、发传单、家教'**
  String get workTitleHint;

  /// No description provided for @workLocation.
  ///
  /// In zh, this message translates to:
  /// **'工作地点'**
  String get workLocation;

  /// No description provided for @workLocationHint.
  ///
  /// In zh, this message translates to:
  /// **'例如：会展中心A馆、解放路步行街'**
  String get workLocationHint;

  /// No description provided for @contactPerson.
  ///
  /// In zh, this message translates to:
  /// **'对接人'**
  String get contactPerson;

  /// No description provided for @contactPersonHint.
  ///
  /// In zh, this message translates to:
  /// **'例如：张三、李经理'**
  String get contactPersonHint;

  /// No description provided for @workTime.
  ///
  /// In zh, this message translates to:
  /// **'工作时间'**
  String get workTime;

  /// No description provided for @startTime.
  ///
  /// In zh, this message translates to:
  /// **'开始时间'**
  String get startTime;

  /// No description provided for @endTime.
  ///
  /// In zh, this message translates to:
  /// **'结束时间'**
  String get endTime;

  /// No description provided for @incomeDetails.
  ///
  /// In zh, this message translates to:
  /// **'收入详情'**
  String get incomeDetails;

  /// No description provided for @hourlyRate.
  ///
  /// In zh, this message translates to:
  /// **'时薪 (¥)'**
  String get hourlyRate;

  /// No description provided for @workHours.
  ///
  /// In zh, this message translates to:
  /// **'工作时长 (h)'**
  String get workHours;

  /// No description provided for @dailyWage.
  ///
  /// In zh, this message translates to:
  /// **'日工资 (¥)'**
  String get dailyWage;

  /// No description provided for @wageHelperText.
  ///
  /// In zh, this message translates to:
  /// **'填时薪自动算日工资，填日工资反推时薪'**
  String get wageHelperText;

  /// No description provided for @estimatedIncome.
  ///
  /// In zh, this message translates to:
  /// **'预计收入'**
  String get estimatedIncome;

  /// No description provided for @workTimes.
  ///
  /// In zh, this message translates to:
  /// **'工作次'**
  String get workTimes;

  /// No description provided for @saveMethod.
  ///
  /// In zh, this message translates to:
  /// **'保存方式'**
  String get saveMethod;

  /// No description provided for @saveWithImage.
  ///
  /// In zh, this message translates to:
  /// **'包含图片和批示'**
  String get saveWithImage;

  /// No description provided for @saveAnnotationOnly.
  ///
  /// In zh, this message translates to:
  /// **'仅插入批示'**
  String get saveAnnotationOnly;

  /// No description provided for @draftSaved.
  ///
  /// In zh, this message translates to:
  /// **'草稿已保存'**
  String get draftSaved;

  /// No description provided for @saveDraftFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存草稿失败'**
  String get saveDraftFailed;

  /// No description provided for @draftLoaded.
  ///
  /// In zh, this message translates to:
  /// **'草稿已加载'**
  String get draftLoaded;

  /// No description provided for @loadDraftFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载草稿失败'**
  String get loadDraftFailed;

  /// No description provided for @layerPanel.
  ///
  /// In zh, this message translates to:
  /// **'图层面板'**
  String get layerPanel;

  /// No description provided for @addPhoto.
  ///
  /// In zh, this message translates to:
  /// **'+ 添加照片'**
  String get addPhoto;

  /// No description provided for @noLayers.
  ///
  /// In zh, this message translates to:
  /// **'暂无图层'**
  String get noLayers;

  /// No description provided for @importImageFailed.
  ///
  /// In zh, this message translates to:
  /// **'导入图片失败'**
  String get importImageFailed;

  /// No description provided for @saveFailedCanvas.
  ///
  /// In zh, this message translates to:
  /// **'保存失败'**
  String get saveFailedCanvas;

  /// No description provided for @moveModeHint.
  ///
  /// In zh, this message translates to:
  /// **'拖动选中图层到目标位置，再次点击\"移动\"确认'**
  String get moveModeHint;

  /// No description provided for @cropModeHint.
  ///
  /// In zh, this message translates to:
  /// **'拖拽选择裁切区域，点击✓确认'**
  String get cropModeHint;

  /// No description provided for @undo.
  ///
  /// In zh, this message translates to:
  /// **'撤销'**
  String get undo;

  /// No description provided for @imageTool.
  ///
  /// In zh, this message translates to:
  /// **'图片'**
  String get imageTool;

  /// No description provided for @layerTool.
  ///
  /// In zh, this message translates to:
  /// **'图层'**
  String get layerTool;

  /// No description provided for @moveTool.
  ///
  /// In zh, this message translates to:
  /// **'移动'**
  String get moveTool;

  /// No description provided for @cropTool.
  ///
  /// In zh, this message translates to:
  /// **'裁切'**
  String get cropTool;

  /// No description provided for @clearTool.
  ///
  /// In zh, this message translates to:
  /// **'清空'**
  String get clearTool;

  /// No description provided for @monday.
  ///
  /// In zh, this message translates to:
  /// **'星期一'**
  String get monday;

  /// No description provided for @tuesday.
  ///
  /// In zh, this message translates to:
  /// **'星期二'**
  String get tuesday;

  /// No description provided for @wednesday.
  ///
  /// In zh, this message translates to:
  /// **'星期三'**
  String get wednesday;

  /// No description provided for @thursday.
  ///
  /// In zh, this message translates to:
  /// **'星期四'**
  String get thursday;

  /// No description provided for @friday.
  ///
  /// In zh, this message translates to:
  /// **'星期五'**
  String get friday;

  /// No description provided for @saturday.
  ///
  /// In zh, this message translates to:
  /// **'星期六'**
  String get saturday;

  /// No description provided for @sunday.
  ///
  /// In zh, this message translates to:
  /// **'星期日'**
  String get sunday;

  /// No description provided for @yearSuffix.
  ///
  /// In zh, this message translates to:
  /// **'年'**
  String get yearSuffix;

  /// No description provided for @monthSuffix.
  ///
  /// In zh, this message translates to:
  /// **'月'**
  String get monthSuffix;

  /// No description provided for @hoursSuffix.
  ///
  /// In zh, this message translates to:
  /// **'h'**
  String get hoursSuffix;

  /// No description provided for @minutesSuffix.
  ///
  /// In zh, this message translates to:
  /// **'m'**
  String get minutesSuffix;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.countryCode) {
          case 'TW':
            return AppLocalizationsZhTw();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
