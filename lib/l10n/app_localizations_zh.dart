// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '日程清单';

  @override
  String get backToToday => '回到今天';

  @override
  String get addTodayWork => '添加今日工作';

  @override
  String get loadFailed => '加载失败';

  @override
  String get nextWeek => '未来一周';

  @override
  String get nextWeekEmpty => '未来一周暂无工作安排';

  @override
  String get today => '今天';

  @override
  String get total => '合计';

  @override
  String get addWork => '添加工作';

  @override
  String get noWorkTitle => '当天还没有工作安排';

  @override
  String get noWorkSubtitle => '点击下方按钮添加工作';

  @override
  String get confirmDelete => '确认删除';

  @override
  String get cancel => '取消';

  @override
  String get delete => '删除';

  @override
  String get deleted => '已删除';

  @override
  String get deleteFailed => '删除失败';

  @override
  String get noTitle => '(无标题)';

  @override
  String get loadNoteFailed => '加载笔记失败';

  @override
  String get saveSuccess => '保存成功！';

  @override
  String get saveFailed => '保存失败';

  @override
  String get imageInserted => '图片已插入';

  @override
  String get insertImageFailed => '插入图片失败';

  @override
  String get selectImageFailed => '选择图片失败';

  @override
  String get takePhotoFailed => '拍照失败';

  @override
  String get cameraPermissionError => '无法使用相机，请在系统设置中允许相机权限';

  @override
  String get deleteNote => '删除笔记';

  @override
  String get save => '保存';

  @override
  String get remarks => '备注';

  @override
  String get remarksPlaceholder => '写写今天的工作内容和感受...';

  @override
  String get galleryImage => '相册图片';

  @override
  String get takePhoto => '拍照';

  @override
  String get drawingBoard => '画板';

  @override
  String get images => '图片';

  @override
  String get tapToViewFullImage => '点击可查看大图';

  @override
  String get wageStatistics => '工资统计';

  @override
  String get retry => '重试';

  @override
  String get statsHidden => '统计数据已隐藏';

  @override
  String get statsHiddenHint => '可在 设置 → 隐私设置 中关闭隐藏';

  @override
  String get noWageRecords => '还没有工资记录';

  @override
  String get noWageRecordsSubtitle => '添加工作笔记并填写工资后即可查看统计';

  @override
  String get recent6MonthsTrend => '近6个月收入趋势';

  @override
  String get noData => '暂无数据';

  @override
  String workCount(int count) {
    return '共$count次';
  }

  @override
  String get month => '月';

  @override
  String get privacySettings => '隐私设置';

  @override
  String get privacyDescription =>
      '隐私设置帮助你控制在应用中显示的敏感信息。开启隐藏后，相关数据将以\"***\"代替。';

  @override
  String get hideIncomeAmount => '隐藏收入金额';

  @override
  String get hideIncomeAmountSubtitle => '开启后，所有页面的收入金额将显示为\"***\"';

  @override
  String get hideStatisticsPage => '隐藏统计页面';

  @override
  String get hideStatisticsPageSubtitle => '开启后，统计Tab将显示为空状态，保护你的收入数据隐私';

  @override
  String get privacyHint => '隐私设置即时生效，无需重启应用';

  @override
  String get settings => '设置';

  @override
  String get appearance => '外观';

  @override
  String get followSystem => '跟随系统';

  @override
  String get followSystemSubtitle => '自动跟随系统亮色/暗色设置';

  @override
  String get lightMode => '浅色模式';

  @override
  String get lightModeSubtitle => '始终使用浅色主题';

  @override
  String get darkMode => '深色模式';

  @override
  String get darkModeSubtitle => '始终使用暗色主题';

  @override
  String get privacy => '隐私';

  @override
  String get privacyNavTitle => '隐私设置';

  @override
  String get privacyNavSubtitle => '控制收入金额和统计数据的显示';

  @override
  String get data => '数据';

  @override
  String get exportData => '导出数据';

  @override
  String get exporting => '正在导出...';

  @override
  String get exportDataSubtitle => '将全部工作笔记导出为文件';

  @override
  String get backupAndRestore => '备份与恢复';

  @override
  String get processing => '处理中...';

  @override
  String get backupAndRestoreSubtitle => '导出数据库备份或从备份恢复';

  @override
  String get cloudBackupWebDAV => '云备份 (WebDAV)';

  @override
  String get cloudBackupSubtitle => '备份到坚果云或自定义服务器';

  @override
  String get about => '关于';

  @override
  String get aboutAppTitle => '关于日程清单';

  @override
  String get aboutAppSubtitle => '版本 1.2.0 —— 让每一份付出都有记录';

  @override
  String get aboutAppName => '日程清单';

  @override
  String get aboutAppLegalese => '帮助日结兼职人员轻松记录工作与收入';

  @override
  String get aboutAppBody => '温暖地记录每一天的辛劳，让付出可视化。';

  @override
  String get projectHomepage => '项目主页';

  @override
  String get projectHomepageSubtitle => '在浏览器中查看源代码';

  @override
  String get errorLog => '错误日志';

  @override
  String get errorLogSubtitle => '查看应用运行时的错误记录';

  @override
  String get checkUpdate => '检查更新';

  @override
  String get checkUpdateSubtitle => '检查是否有新版本可用';

  @override
  String get noUpdatesAvailable => '当前已是最新版本';

  @override
  String updateAvailable(String version) {
    return '发现新版本：v$version';
  }

  @override
  String get checkUpdateFailed => '检查更新失败';

  @override
  String get noErrorLogs => '暂无错误记录';

  @override
  String get errorLogTitle => '错误日志';

  @override
  String get selectExportFormat => '选择导出格式';

  @override
  String get exportDialogContent => '将全部工作笔记导出为文件，请选择格式：';

  @override
  String get csv => 'CSV';

  @override
  String get json => 'JSON';

  @override
  String get exportShareSubject => '日程清单数据导出';

  @override
  String get exportShareText => '日程清单导出的工作笔记数据';

  @override
  String get exportFailed => '导出失败';

  @override
  String get backupRestoreDialogTitle => '备份与恢复';

  @override
  String get backupRestoreDialogContent =>
      '备份：将数据库导出为文件\n恢复：从备份文件恢复数据（会覆盖当前数据）';

  @override
  String get backup => '备份';

  @override
  String get restore => '恢复';

  @override
  String get backupFilePrefix => '日程清单_备份_';

  @override
  String get backupShareSubject => '日程清单数据备份';

  @override
  String get backupShareText => '日程清单数据库备份文件';

  @override
  String get backupFailed => '备份失败';

  @override
  String get dbFileNotExist => '数据库文件不存在';

  @override
  String get restoreSuccess => '恢复成功！请重启应用以加载数据';

  @override
  String get restoreFailed => '恢复失败';

  @override
  String get language => '语言';

  @override
  String get chinese => '中文';

  @override
  String get english => 'English';

  @override
  String get traditionalChinese => '繁體中文';

  @override
  String get cloudBackup => '云备份';

  @override
  String get instructions => '说明';

  @override
  String get webdavInfo => '支持坚果云等标准 WebDAV 服务器';

  @override
  String get jianguoyunInfo => '坚果云用户请在「账户信息 → 安全选项」中生成应用密码';

  @override
  String get backupPathInfo => '备份文件将存储在云盘 daily_gig_journal 目录下';

  @override
  String get serverConfig => '服务器配置';

  @override
  String get serverAddress => '服务器地址';

  @override
  String get accountLabel => '账号（坚果云为注册邮箱）';

  @override
  String get passwordLabel => '密码（坚果云需使用应用密码）';

  @override
  String get appPasswordHint => '应用密码（非登录密码）';

  @override
  String get testing => '测试中...';

  @override
  String get testConnection => '测试连接';

  @override
  String get actions => '操作';

  @override
  String get backingUp => '备份中...';

  @override
  String get backupToCloud => '备份到云盘';

  @override
  String get restoring => '恢复中...';

  @override
  String get restoreFromCloud => '从云盘恢复';

  @override
  String get autoBackup => '自动备份';

  @override
  String get autoBackupTitle => '保存/删除时自动备份';

  @override
  String get autoBackupSubtitle => '开启后，每次新增、修改或删除日程时自动备份到云盘';

  @override
  String get confirmRestore => '确认恢复';

  @override
  String get confirmRestoreButton => '确认恢复';

  @override
  String get confirmRestoreDialogContent =>
      '恢复数据将覆盖当前所有数据，此操作不可撤销。\n建议先备份当前数据再执行恢复。';

  @override
  String get restoreSuccessCloud => '恢复成功！请重启应用以加载恢复的数据';

  @override
  String get restoreFailedCloud => '恢复失败';

  @override
  String get backupFailedCloud => '备份失败';

  @override
  String get selectBackupFile => '选择备份文件';

  @override
  String get selectBackupFileSubtitle => '点击文件即可恢复该日期的备份';

  @override
  String get fetchingFileList => '正在获取备份文件列表...';

  @override
  String get noBackupFiles => '云端没有找到备份文件';

  @override
  String get fetchFileListFailed => '获取文件列表失败';

  @override
  String get calendarTab => '日历';

  @override
  String get statisticsTab => '统计';

  @override
  String get settingsTab => '设置';

  @override
  String get basicInfo => '基本信息';

  @override
  String get workTitle => '工作标题';

  @override
  String get workTitleHint => '例如：会展协助、发传单、家教';

  @override
  String get workLocation => '工作地点';

  @override
  String get workLocationHint => '例如：会展中心A馆、解放路步行街';

  @override
  String get contactPerson => '对接人';

  @override
  String get contactPersonHint => '例如：张三、李经理';

  @override
  String get workTime => '工作时间';

  @override
  String get startTime => '开始时间';

  @override
  String get endTime => '结束时间';

  @override
  String get incomeDetails => '收入详情';

  @override
  String get hourlyRate => '时薪 (¥)';

  @override
  String get workHours => '工作时长 (h)';

  @override
  String get dailyWage => '日工资 (¥)';

  @override
  String get wageHelperText => '填时薪自动算日工资，填日工资反推时薪';

  @override
  String get estimatedIncome => '预计收入';

  @override
  String get workTimes => '工作次';

  @override
  String get saveMethod => '保存方式';

  @override
  String get saveWithImage => '包含图片和批示';

  @override
  String get saveAnnotationOnly => '仅插入批示';

  @override
  String get draftSaved => '草稿已保存';

  @override
  String get saveDraftFailed => '保存草稿失败';

  @override
  String get draftLoaded => '草稿已加载';

  @override
  String get loadDraftFailed => '加载草稿失败';

  @override
  String get layerPanel => '图层面板';

  @override
  String get addPhoto => '+ 添加照片';

  @override
  String get noLayers => '暂无图层';

  @override
  String get importImageFailed => '导入图片失败';

  @override
  String get saveFailedCanvas => '保存失败';

  @override
  String get moveModeHint => '拖动选中图层到目标位置，再次点击\"移动\"确认';

  @override
  String get cropModeHint => '拖拽选择裁切区域，点击✓确认';

  @override
  String get undo => '撤销';

  @override
  String get imageTool => '图片';

  @override
  String get layerTool => '图层';

  @override
  String get moveTool => '移动';

  @override
  String get cropTool => '裁切';

  @override
  String get clearTool => '清空';

  @override
  String get monday => '星期一';

  @override
  String get tuesday => '星期二';

  @override
  String get wednesday => '星期三';

  @override
  String get thursday => '星期四';

  @override
  String get friday => '星期五';

  @override
  String get saturday => '星期六';

  @override
  String get sunday => '星期日';

  @override
  String get yearSuffix => '年';

  @override
  String get monthSuffix => '月';

  @override
  String get hoursSuffix => 'h';

  @override
  String get minutesSuffix => 'm';
}

/// The translations for Chinese, as used in Taiwan (`zh_TW`).
class AppLocalizationsZhTw extends AppLocalizationsZh {
  AppLocalizationsZhTw() : super('zh_TW');

  @override
  String get appTitle => '日程清單';

  @override
  String get backToToday => '回到今天';

  @override
  String get addTodayWork => '添加今日工作';

  @override
  String get loadFailed => '載入失敗';

  @override
  String get nextWeek => '未來一週';

  @override
  String get nextWeekEmpty => '未來一週暫無工作安排';

  @override
  String get today => '今天';

  @override
  String get total => '合計';

  @override
  String get addWork => '添加工作';

  @override
  String get noWorkTitle => '當天還沒有工作安排';

  @override
  String get noWorkSubtitle => '點擊下方按鈕添加工作';

  @override
  String get confirmDelete => '確認刪除';

  @override
  String get cancel => '取消';

  @override
  String get delete => '刪除';

  @override
  String get deleted => '已刪除';

  @override
  String get deleteFailed => '刪除失敗';

  @override
  String get noTitle => '(無標題)';

  @override
  String get loadNoteFailed => '載入筆記失敗';

  @override
  String get saveSuccess => '儲存成功！';

  @override
  String get saveFailed => '儲存失敗';

  @override
  String get imageInserted => '圖片已插入';

  @override
  String get insertImageFailed => '插入圖片失敗';

  @override
  String get selectImageFailed => '選擇圖片失敗';

  @override
  String get takePhotoFailed => '拍照失敗';

  @override
  String get cameraPermissionError => '無法使用相機，請在系統設定中允許相機權限';

  @override
  String get deleteNote => '刪除筆記';

  @override
  String get save => '儲存';

  @override
  String get remarks => '備註';

  @override
  String get remarksPlaceholder => '寫寫今天的工作內容和感受...';

  @override
  String get galleryImage => '相簿圖片';

  @override
  String get takePhoto => '拍照';

  @override
  String get drawingBoard => '畫板';

  @override
  String get images => '圖片';

  @override
  String get tapToViewFullImage => '點擊可查看大圖';

  @override
  String get wageStatistics => '工資統計';

  @override
  String get retry => '重試';

  @override
  String get statsHidden => '統計資料已隱藏';

  @override
  String get statsHiddenHint => '可在 設定 → 隱私設定 中關閉隱藏';

  @override
  String get noWageRecords => '還沒有工資記錄';

  @override
  String get noWageRecordsSubtitle => '添加工作筆記並填寫工資後即可查看統計';

  @override
  String get recent6MonthsTrend => '近6個月收入趨勢';

  @override
  String get noData => '暫無資料';

  @override
  String workCount(int count) {
    return '共$count次';
  }

  @override
  String get month => '月';

  @override
  String get privacySettings => '隱私設定';

  @override
  String get privacyDescription =>
      '隱私設定幫助你控制在應用中顯示的敏感資訊。開啟隱藏後，相關資料將以\"***\"代替。';

  @override
  String get hideIncomeAmount => '隱藏收入金額';

  @override
  String get hideIncomeAmountSubtitle => '開啟後，所有頁面的收入金額將顯示為\"***\"';

  @override
  String get hideStatisticsPage => '隱藏統計頁面';

  @override
  String get hideStatisticsPageSubtitle => '開啟後，統計Tab將顯示為空狀態，保護你的收入資料隱私';

  @override
  String get privacyHint => '隱私設定即時生效，無需重新啟動應用';

  @override
  String get settings => '設定';

  @override
  String get appearance => '外觀';

  @override
  String get followSystem => '跟隨系統';

  @override
  String get followSystemSubtitle => '自動跟隨系統亮色/暗色設定';

  @override
  String get lightMode => '淺色模式';

  @override
  String get lightModeSubtitle => '始終使用淺色主題';

  @override
  String get darkMode => '深色模式';

  @override
  String get darkModeSubtitle => '始終使用暗色主題';

  @override
  String get privacy => '隱私';

  @override
  String get privacyNavTitle => '隱私設定';

  @override
  String get privacyNavSubtitle => '控制收入金額和統計資料的顯示';

  @override
  String get data => '資料';

  @override
  String get exportData => '匯出資料';

  @override
  String get exporting => '正在匯出...';

  @override
  String get exportDataSubtitle => '將全部工作筆記匯出為檔案';

  @override
  String get backupAndRestore => '備份與還原';

  @override
  String get processing => '處理中...';

  @override
  String get backupAndRestoreSubtitle => '匯出資料庫備份或從備份還原';

  @override
  String get cloudBackupWebDAV => '雲端備份 (WebDAV)';

  @override
  String get cloudBackupSubtitle => '備份到堅果雲或自訂伺服器';

  @override
  String get about => '關於';

  @override
  String get aboutAppTitle => '關於日程清單';

  @override
  String get aboutAppSubtitle => '版本 1.2.0 —— 讓每一份付出都有記錄';

  @override
  String get aboutAppName => '日程清單';

  @override
  String get aboutAppLegalese => '幫助日結兼職人員輕鬆記錄工作與收入';

  @override
  String get aboutAppBody => '溫暖地記錄每一天的辛勞，讓付出可視化。';

  @override
  String get projectHomepage => '項目主頁';

  @override
  String get projectHomepageSubtitle => '在瀏覽器中檢視原始碼';

  @override
  String get errorLog => '錯誤日誌';

  @override
  String get errorLogSubtitle => '檢視應用程式執行時的錯誤記錄';

  @override
  String get checkUpdate => '檢查更新';

  @override
  String get checkUpdateSubtitle => '檢查是否有新版本可用';

  @override
  String get noUpdatesAvailable => '目前已經是最新版本';

  @override
  String updateAvailable(String version) {
    return '發現新版本：v$version';
  }

  @override
  String get checkUpdateFailed => '檢查更新失敗';

  @override
  String get noErrorLogs => '暫無錯誤記錄';

  @override
  String get errorLogTitle => '錯誤日誌';

  @override
  String get selectExportFormat => '選擇匯出格式';

  @override
  String get exportDialogContent => '將全部工作筆記匯出為檔案，請選擇格式：';

  @override
  String get csv => 'CSV';

  @override
  String get json => 'JSON';

  @override
  String get exportShareSubject => '日程清單資料匯出';

  @override
  String get exportShareText => '日程清單匯出的工作筆記資料';

  @override
  String get exportFailed => '匯出失敗';

  @override
  String get backupRestoreDialogTitle => '備份與還原';

  @override
  String get backupRestoreDialogContent =>
      '備份：將資料庫匯出為檔案\n還原：從備份檔案還原資料（會覆蓋目前資料）';

  @override
  String get backup => '備份';

  @override
  String get restore => '還原';

  @override
  String get backupFilePrefix => '日程清單_備份_';

  @override
  String get backupShareSubject => '日程清單資料備份';

  @override
  String get backupShareText => '日程清單資料庫備份檔案';

  @override
  String get backupFailed => '備份失敗';

  @override
  String get dbFileNotExist => '資料庫檔案不存在';

  @override
  String get restoreSuccess => '還原成功！請重新啟動應用以載入資料';

  @override
  String get restoreFailed => '還原失敗';

  @override
  String get language => '語言';

  @override
  String get chinese => '中文';

  @override
  String get english => 'English';

  @override
  String get traditionalChinese => '繁體中文';

  @override
  String get cloudBackup => '雲端備份';

  @override
  String get instructions => '說明';

  @override
  String get webdavInfo => '支援堅果雲等標準 WebDAV 伺服器';

  @override
  String get jianguoyunInfo => '堅果雲用戶請在「帳戶資訊 → 安全選項」中產生應用密碼';

  @override
  String get backupPathInfo => '備份檔案將儲存在雲盤 daily_gig_journal 目錄下';

  @override
  String get serverConfig => '伺服器設定';

  @override
  String get serverAddress => '伺服器位址';

  @override
  String get accountLabel => '帳號（堅果雲為註冊信箱）';

  @override
  String get passwordLabel => '密碼（堅果雲需使用應用密碼）';

  @override
  String get appPasswordHint => '應用密碼（非登入密碼）';

  @override
  String get testing => '測試中...';

  @override
  String get testConnection => '測試連線';

  @override
  String get actions => '操作';

  @override
  String get backingUp => '備份中...';

  @override
  String get backupToCloud => '備份到雲盤';

  @override
  String get restoring => '還原中...';

  @override
  String get restoreFromCloud => '從雲盤還原';

  @override
  String get autoBackup => '自動備份';

  @override
  String get autoBackupTitle => '儲存/刪除時自動備份';

  @override
  String get autoBackupSubtitle => '開啟後，每次新增、修改或刪除日程時自動備份到雲盤';

  @override
  String get confirmRestore => '確認還原';

  @override
  String get confirmRestoreButton => '確認還原';

  @override
  String get confirmRestoreDialogContent =>
      '還原資料將覆蓋目前所有資料，此操作不可撤銷。\n建議先備份目前資料再執行還原。';

  @override
  String get restoreSuccessCloud => '還原成功！請重新啟動應用以載入還原的資料';

  @override
  String get restoreFailedCloud => '還原失敗';

  @override
  String get backupFailedCloud => '備份失敗';

  @override
  String get selectBackupFile => '選擇備份檔案';

  @override
  String get selectBackupFileSubtitle => '點擊檔案即可還原該日期的備份';

  @override
  String get fetchingFileList => '正在取得備份檔案列表...';

  @override
  String get noBackupFiles => '雲端沒有找到備份檔案';

  @override
  String get fetchFileListFailed => '取得檔案列表失敗';

  @override
  String get calendarTab => '日曆';

  @override
  String get statisticsTab => '統計';

  @override
  String get settingsTab => '設定';

  @override
  String get basicInfo => '基本資訊';

  @override
  String get workTitle => '工作標題';

  @override
  String get workTitleHint => '例如：展覽協助、發傳單、家教';

  @override
  String get workLocation => '工作地點';

  @override
  String get workLocationHint => '例如：展覽中心A館、解放路步行街';

  @override
  String get contactPerson => '對接人';

  @override
  String get contactPersonHint => '例如：張三、李經理';

  @override
  String get workTime => '工作時間';

  @override
  String get startTime => '開始時間';

  @override
  String get endTime => '結束時間';

  @override
  String get incomeDetails => '收入詳情';

  @override
  String get hourlyRate => '時薪 (NT\$)';

  @override
  String get workHours => '工作時長 (h)';

  @override
  String get dailyWage => '日工資 (NT\$)';

  @override
  String get wageHelperText => '填時薪自動算日工資，填日工資反推時薪';

  @override
  String get estimatedIncome => '預計收入';

  @override
  String get workTimes => '工作次';

  @override
  String get saveMethod => '儲存方式';

  @override
  String get saveWithImage => '包含圖片和批示';

  @override
  String get saveAnnotationOnly => '僅插入批示';

  @override
  String get draftSaved => '草稿已儲存';

  @override
  String get saveDraftFailed => '儲存草稿失敗';

  @override
  String get draftLoaded => '草稿已載入';

  @override
  String get loadDraftFailed => '載入草稿失敗';

  @override
  String get layerPanel => '圖層面板';

  @override
  String get addPhoto => '+ 添加照片';

  @override
  String get noLayers => '暫無圖層';

  @override
  String get importImageFailed => '匯入圖片失敗';

  @override
  String get saveFailedCanvas => '儲存失敗';

  @override
  String get moveModeHint => '拖動選取圖層到目標位置，再次點擊\"移動\"確認';

  @override
  String get cropModeHint => '拖拽選取裁切區域，點擊✓確認';

  @override
  String get undo => '撤銷';

  @override
  String get imageTool => '圖片';

  @override
  String get layerTool => '圖層';

  @override
  String get moveTool => '移動';

  @override
  String get cropTool => '裁切';

  @override
  String get clearTool => '清空';

  @override
  String get monday => '星期一';

  @override
  String get tuesday => '星期二';

  @override
  String get wednesday => '星期三';

  @override
  String get thursday => '星期四';

  @override
  String get friday => '星期五';

  @override
  String get saturday => '星期六';

  @override
  String get sunday => '星期日';

  @override
  String get yearSuffix => '年';

  @override
  String get monthSuffix => '月';

  @override
  String get hoursSuffix => 'h';

  @override
  String get minutesSuffix => 'm';
}
