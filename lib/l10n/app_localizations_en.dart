// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Daily Gig Journal';

  @override
  String get backToToday => 'Back to Today';

  @override
  String get addTodayWork => 'Add Today\'s Work';

  @override
  String get loadFailed => 'Load failed';

  @override
  String get nextWeek => 'Next Week';

  @override
  String get nextWeekEmpty => 'No work scheduled for the next week';

  @override
  String get today => 'Today';

  @override
  String get total => 'Total';

  @override
  String get addWork => 'Add Work';

  @override
  String get noWorkTitle => 'No work scheduled for this day';

  @override
  String get noWorkSubtitle => 'Tap the button below to add work';

  @override
  String get confirmDelete => 'Confirm Delete';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get deleted => 'Deleted';

  @override
  String get deleteFailed => 'Delete failed';

  @override
  String get noTitle => '(No Title)';

  @override
  String get loadNoteFailed => 'Failed to load note';

  @override
  String get saveSuccess => 'Saved successfully!';

  @override
  String get saveFailed => 'Save failed';

  @override
  String get imageInserted => 'Image inserted';

  @override
  String get insertImageFailed => 'Failed to insert image';

  @override
  String get selectImageFailed => 'Failed to select image';

  @override
  String get takePhotoFailed => 'Failed to take photo';

  @override
  String get cameraPermissionError =>
      'Cannot use camera. Please allow camera permission in system settings';

  @override
  String get deleteNote => 'Delete Note';

  @override
  String get save => 'Save';

  @override
  String get remarks => 'Remarks';

  @override
  String get remarksPlaceholder => 'Write about today\'s work and feelings...';

  @override
  String get galleryImage => 'Gallery';

  @override
  String get takePhoto => 'Camera';

  @override
  String get drawingBoard => 'Drawing Board';

  @override
  String get images => 'Images';

  @override
  String get tapToViewFullImage => 'Tap to view full image';

  @override
  String get wageStatistics => 'Wage Statistics';

  @override
  String get retry => 'Retry';

  @override
  String get statsHidden => 'Statistics Hidden';

  @override
  String get statsHiddenHint => 'You can disable hiding in Settings → Privacy';

  @override
  String get noWageRecords => 'No wage records yet';

  @override
  String get noWageRecordsSubtitle =>
      'Add work notes and fill in wages to view statistics';

  @override
  String get recent6MonthsTrend => 'Income Trend (Last 6 Months)';

  @override
  String get noData => 'No data';

  @override
  String workCount(int count) {
    return '$count times';
  }

  @override
  String get month => 'month';

  @override
  String get privacySettings => 'Privacy Settings';

  @override
  String get privacyDescription =>
      'Privacy settings control the display of sensitive information in the app. When hiding is enabled, related data will be shown as \"***\".';

  @override
  String get hideIncomeAmount => 'Hide Income Amount';

  @override
  String get hideIncomeAmountSubtitle =>
      'When enabled, income amounts on all pages will be shown as \"***\"';

  @override
  String get hideStatisticsPage => 'Hide Statistics Page';

  @override
  String get hideStatisticsPageSubtitle =>
      'When enabled, the Statistics tab will show an empty state to protect your income privacy';

  @override
  String get privacyHint =>
      'Privacy settings take effect immediately, no app restart needed';

  @override
  String get settings => 'Settings';

  @override
  String get appearance => 'Appearance';

  @override
  String get followSystem => 'Follow System';

  @override
  String get followSystemSubtitle =>
      'Automatically follow system light/dark setting';

  @override
  String get lightMode => 'Light Mode';

  @override
  String get lightModeSubtitle => 'Always use light theme';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get darkModeSubtitle => 'Always use dark theme';

  @override
  String get privacy => 'Privacy';

  @override
  String get privacyNavTitle => 'Privacy Settings';

  @override
  String get privacyNavSubtitle => 'Control display of income and statistics';

  @override
  String get data => 'Data';

  @override
  String get exportData => 'Export Data';

  @override
  String get exporting => 'Exporting...';

  @override
  String get exportDataSubtitle => 'Export all work notes to a file';

  @override
  String get backupAndRestore => 'Backup & Restore';

  @override
  String get processing => 'Processing...';

  @override
  String get backupAndRestoreSubtitle =>
      'Export database backup or restore from backup';

  @override
  String get cloudBackupWebDAV => 'Cloud Backup (WebDAV)';

  @override
  String get cloudBackupSubtitle => 'Backup to Nutstore or custom server';

  @override
  String get about => 'About';

  @override
  String get aboutAppTitle => 'About Daily Gig Journal';

  @override
  String get aboutAppSubtitle => 'Version 1.2.0 — Making every effort count';

  @override
  String get aboutAppName => 'Daily Gig Journal';

  @override
  String get aboutAppLegalese =>
      'Helping daily gig workers easily track work and income';

  @override
  String get aboutAppBody =>
      'Warmly recording each day\'s hard work, making efforts visible.';

  @override
  String get projectHomepage => 'Project Homepage';

  @override
  String get projectHomepageSubtitle => 'View source code in browser';

  @override
  String get errorLog => 'Error Log';

  @override
  String get errorLogSubtitle => 'View application runtime errors';

  @override
  String get checkUpdate => 'Check for Updates';

  @override
  String get checkUpdateSubtitle => 'Check if a new version is available';

  @override
  String get noUpdatesAvailable => 'You are on the latest version';

  @override
  String updateAvailable(String version) {
    return 'New version available: v$version';
  }

  @override
  String get checkUpdateFailed => 'Failed to check for updates';

  @override
  String get noErrorLogs => 'No error logs';

  @override
  String get errorLogTitle => 'Error Log';

  @override
  String get selectExportFormat => 'Select Export Format';

  @override
  String get exportDialogContent =>
      'Export all work notes to a file. Please choose a format:';

  @override
  String get csv => 'CSV';

  @override
  String get json => 'JSON';

  @override
  String get exportShareSubject => 'Daily Gig Journal Data Export';

  @override
  String get exportShareText => 'Exported work notes from Daily Gig Journal';

  @override
  String get exportFailed => 'Export failed';

  @override
  String get backupRestoreDialogTitle => 'Backup & Restore';

  @override
  String get backupRestoreDialogContent =>
      'Backup: Export database to file\nRestore: Restore data from backup file (will overwrite current data)';

  @override
  String get backup => 'Backup';

  @override
  String get restore => 'Restore';

  @override
  String get backupFilePrefix => 'DailyGigJournal_Backup_';

  @override
  String get backupShareSubject => 'Daily Gig Journal Data Backup';

  @override
  String get backupShareText => 'Daily Gig Journal database backup file';

  @override
  String get backupFailed => 'Backup failed';

  @override
  String get dbFileNotExist => 'Database file does not exist';

  @override
  String get restoreSuccess =>
      'Restore successful! Please restart the app to load data';

  @override
  String get restoreFailed => 'Restore failed';

  @override
  String get language => 'Language';

  @override
  String get chinese => '中文';

  @override
  String get english => 'English';

  @override
  String get traditionalChinese => '繁體中文';

  @override
  String get cloudBackup => 'Cloud Backup';

  @override
  String get instructions => 'Instructions';

  @override
  String get webdavInfo => 'Supports standard WebDAV servers like Nutstore';

  @override
  String get jianguoyunInfo =>
      'Nutstore users: Generate an app password in Account Info → Security Options';

  @override
  String get backupPathInfo =>
      'Backup files will be stored in the daily_gig_journal directory on cloud';

  @override
  String get serverConfig => 'Server Configuration';

  @override
  String get serverAddress => 'Server Address';

  @override
  String get accountLabel => 'Account (Nutstore: registration email)';

  @override
  String get passwordLabel => 'Password (Nutstore: use app password)';

  @override
  String get appPasswordHint => 'App password (not login password)';

  @override
  String get testing => 'Testing...';

  @override
  String get testConnection => 'Test Connection';

  @override
  String get actions => 'Actions';

  @override
  String get backingUp => 'Backing up...';

  @override
  String get backupToCloud => 'Backup to Cloud';

  @override
  String get restoring => 'Restoring...';

  @override
  String get restoreFromCloud => 'Restore from Cloud';

  @override
  String get autoBackup => 'Auto Backup';

  @override
  String get autoBackupTitle => 'Auto backup on save/delete';

  @override
  String get autoBackupSubtitle =>
      'When enabled, automatically backs up to cloud on every add, edit, or delete';

  @override
  String get confirmRestore => 'Confirm Restore';

  @override
  String get confirmRestoreButton => 'Confirm Restore';

  @override
  String get confirmRestoreDialogContent =>
      'Restoring will overwrite all current data. This action cannot be undone.\n建议先备份当前数据再执行恢复。';

  @override
  String get restoreSuccessCloud =>
      'Restore successful! Please restart the app to load restored data';

  @override
  String get restoreFailedCloud => 'Restore failed';

  @override
  String get backupFailedCloud => 'Backup failed';

  @override
  String get selectBackupFile => 'Select Backup File';

  @override
  String get selectBackupFileSubtitle =>
      'Tap a file to restore that date\'s backup';

  @override
  String get fetchingFileList => 'Fetching backup file list...';

  @override
  String get noBackupFiles => 'No backup files found on cloud';

  @override
  String get fetchFileListFailed => 'Failed to fetch file list';

  @override
  String get calendarTab => 'Calendar';

  @override
  String get statisticsTab => 'Statistics';

  @override
  String get settingsTab => 'Settings';

  @override
  String get basicInfo => 'Basic Info';

  @override
  String get workTitle => 'Work Title';

  @override
  String get workTitleHint => 'e.g.: Exhibition assistance, Flyering, Tutoring';

  @override
  String get workLocation => 'Work Location';

  @override
  String get workLocationHint =>
      'e.g.: Exhibition Center Hall A, Liberation Road';

  @override
  String get contactPerson => 'Contact Person';

  @override
  String get contactPersonHint => 'e.g.: Zhang San, Manager Li';

  @override
  String get workTime => 'Work Time';

  @override
  String get startTime => 'Start Time';

  @override
  String get endTime => 'End Time';

  @override
  String get incomeDetails => 'Income Details';

  @override
  String get hourlyRate => 'Hourly Rate (¥)';

  @override
  String get workHours => 'Work Hours (h)';

  @override
  String get dailyWage => 'Daily Wage (¥)';

  @override
  String get wageHelperText =>
      'Enter hourly rate to auto-calculate daily wage, or enter daily wage to back-calculate hourly rate';

  @override
  String get estimatedIncome => 'Estimated Income';

  @override
  String get workTimes => 'work times';

  @override
  String get saveMethod => 'Save Method';

  @override
  String get saveWithImage => 'Include image and annotations';

  @override
  String get saveAnnotationOnly => 'Insert annotations only';

  @override
  String get draftSaved => 'Draft saved';

  @override
  String get saveDraftFailed => 'Failed to save draft';

  @override
  String get draftLoaded => 'Draft loaded';

  @override
  String get loadDraftFailed => 'Failed to load draft';

  @override
  String get layerPanel => 'Layer Panel';

  @override
  String get addPhoto => '+ Add Photo';

  @override
  String get noLayers => 'No layers';

  @override
  String get importImageFailed => 'Failed to import image';

  @override
  String get saveFailedCanvas => 'Save failed';

  @override
  String get moveModeHint =>
      'Drag selected layer to target position, tap \"Move\" again to confirm';

  @override
  String get cropModeHint => 'Drag to select crop area, tap ✓ to confirm';

  @override
  String get undo => 'Undo';

  @override
  String get imageTool => 'Image';

  @override
  String get layerTool => 'Layer';

  @override
  String get moveTool => 'Move';

  @override
  String get cropTool => 'Crop';

  @override
  String get clearTool => 'Clear';

  @override
  String get monday => 'Monday';

  @override
  String get tuesday => 'Tuesday';

  @override
  String get wednesday => 'Wednesday';

  @override
  String get thursday => 'Thursday';

  @override
  String get friday => 'Friday';

  @override
  String get saturday => 'Saturday';

  @override
  String get sunday => 'Sunday';

  @override
  String get yearSuffix => '-';

  @override
  String get monthSuffix => '-';

  @override
  String get hoursSuffix => 'h';

  @override
  String get minutesSuffix => 'm';
}
