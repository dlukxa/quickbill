import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_bn.dart';
import 'app_localizations_dv.dart';
import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_si.dart';
import 'app_localizations_ta.dart';

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
    Locale('bn'),
    Locale('dv'),
    Locale('en'),
    Locale('hi'),
    Locale('si'),
    Locale('ta')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'QuickBill'**
  String get appTitle;

  /// No description provided for @newBill.
  ///
  /// In en, this message translates to:
  /// **'NEW BILL'**
  String get newBill;

  /// No description provided for @stock.
  ///
  /// In en, this message translates to:
  /// **'Stock'**
  String get stock;

  /// No description provided for @customers.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get customers;

  /// No description provided for @suppliers.
  ///
  /// In en, this message translates to:
  /// **'Suppliers'**
  String get suppliers;

  /// No description provided for @reports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reports;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search products...'**
  String get searchHint;

  /// No description provided for @completeSale.
  ///
  /// In en, this message translates to:
  /// **'COMPLETE SALE'**
  String get completeSale;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'TOTAL'**
  String get total;

  /// No description provided for @subtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get subtotal;

  /// No description provided for @discount.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get discount;

  /// No description provided for @changeToGive.
  ///
  /// In en, this message translates to:
  /// **'CHANGE TO GIVE'**
  String get changeToGive;

  /// No description provided for @paidAmount.
  ///
  /// In en, this message translates to:
  /// **'Paid Amount'**
  String get paidAmount;

  /// No description provided for @todaySales.
  ///
  /// In en, this message translates to:
  /// **'TODAY\'S SALES'**
  String get todaySales;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @shopDetails.
  ///
  /// In en, this message translates to:
  /// **'Shop Details'**
  String get shopDetails;

  /// No description provided for @shopName.
  ///
  /// In en, this message translates to:
  /// **'Shop Name'**
  String get shopName;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumber;

  /// No description provided for @address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// No description provided for @receiptSettings.
  ///
  /// In en, this message translates to:
  /// **'Receipt Settings'**
  String get receiptSettings;

  /// No description provided for @receiptFooter.
  ///
  /// In en, this message translates to:
  /// **'Receipt Footer'**
  String get receiptFooter;

  /// No description provided for @stockAlerts.
  ///
  /// In en, this message translates to:
  /// **'Stock Alerts'**
  String get stockAlerts;

  /// No description provided for @lowStockThreshold.
  ///
  /// In en, this message translates to:
  /// **'Low Stock Threshold'**
  String get lowStockThreshold;

  /// No description provided for @backupSync.
  ///
  /// In en, this message translates to:
  /// **'Backup & Sync'**
  String get backupSync;

  /// No description provided for @autoSync.
  ///
  /// In en, this message translates to:
  /// **'Auto Sync'**
  String get autoSync;

  /// No description provided for @backupData.
  ///
  /// In en, this message translates to:
  /// **'Backup Data'**
  String get backupData;

  /// No description provided for @restoreData.
  ///
  /// In en, this message translates to:
  /// **'Restore Data'**
  String get restoreData;

  /// No description provided for @csvManagement.
  ///
  /// In en, this message translates to:
  /// **'CSV Data Management'**
  String get csvManagement;

  /// No description provided for @exportSales.
  ///
  /// In en, this message translates to:
  /// **'Export Sales History'**
  String get exportSales;

  /// No description provided for @exportInventory.
  ///
  /// In en, this message translates to:
  /// **'Export Inventory'**
  String get exportInventory;

  /// No description provided for @exportCustomers.
  ///
  /// In en, this message translates to:
  /// **'Export Customers'**
  String get exportCustomers;

  /// No description provided for @importProducts.
  ///
  /// In en, this message translates to:
  /// **'Import Products (CSV)'**
  String get importProducts;

  /// No description provided for @helpSupport.
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get helpSupport;

  /// No description provided for @tutorial.
  ///
  /// In en, this message translates to:
  /// **'Tutorial'**
  String get tutorial;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @editShopName.
  ///
  /// In en, this message translates to:
  /// **'Edit Shop Name'**
  String get editShopName;

  /// No description provided for @editPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Edit Phone Number'**
  String get editPhoneNumber;

  /// No description provided for @editAddress.
  ///
  /// In en, this message translates to:
  /// **'Edit Address'**
  String get editAddress;

  /// No description provided for @editReceiptFooter.
  ///
  /// In en, this message translates to:
  /// **'Edit Receipt Footer'**
  String get editReceiptFooter;

  /// No description provided for @printReceipt.
  ///
  /// In en, this message translates to:
  /// **'Print Receipt'**
  String get printReceipt;

  /// No description provided for @logoutCashier.
  ///
  /// In en, this message translates to:
  /// **'Logout Cashier'**
  String get logoutCashier;

  /// No description provided for @manageEmployees.
  ///
  /// In en, this message translates to:
  /// **'Manage Employees'**
  String get manageEmployees;

  /// No description provided for @discounts.
  ///
  /// In en, this message translates to:
  /// **'Discounts'**
  String get discounts;

  /// No description provided for @addDiscount.
  ///
  /// In en, this message translates to:
  /// **'Add Discount'**
  String get addDiscount;

  /// No description provided for @activeDiscounts.
  ///
  /// In en, this message translates to:
  /// **'Active Discounts'**
  String get activeDiscounts;

  /// No description provided for @scheduledDiscounts.
  ///
  /// In en, this message translates to:
  /// **'Scheduled Discounts'**
  String get scheduledDiscounts;

  /// No description provided for @clearance.
  ///
  /// In en, this message translates to:
  /// **'Clearance'**
  String get clearance;

  /// No description provided for @soldOutDiscountHint.
  ///
  /// In en, this message translates to:
  /// **'Applies until product is sold out'**
  String get soldOutDiscountHint;

  /// No description provided for @percentage.
  ///
  /// In en, this message translates to:
  /// **'Percentage'**
  String get percentage;

  /// No description provided for @fixedAmount.
  ///
  /// In en, this message translates to:
  /// **'Fixed Amount'**
  String get fixedAmount;

  /// No description provided for @startDate.
  ///
  /// In en, this message translates to:
  /// **'Start Date'**
  String get startDate;

  /// No description provided for @endDate.
  ///
  /// In en, this message translates to:
  /// **'End Date'**
  String get endDate;

  /// No description provided for @selectProduct.
  ///
  /// In en, this message translates to:
  /// **'Select Product'**
  String get selectProduct;

  /// No description provided for @discountValue.
  ///
  /// In en, this message translates to:
  /// **'Discount Value'**
  String get discountValue;

  /// No description provided for @cashierLogin.
  ///
  /// In en, this message translates to:
  /// **'Cashier Login'**
  String get cashierLogin;

  /// No description provided for @enterPin.
  ///
  /// In en, this message translates to:
  /// **'Enter PIN'**
  String get enterPin;

  /// No description provided for @invalidPin.
  ///
  /// In en, this message translates to:
  /// **'Invalid PIN'**
  String get invalidPin;

  /// No description provided for @employees.
  ///
  /// In en, this message translates to:
  /// **'Employees'**
  String get employees;

  /// No description provided for @addEmployee.
  ///
  /// In en, this message translates to:
  /// **'Add Employee'**
  String get addEmployee;

  /// No description provided for @editEmployee.
  ///
  /// In en, this message translates to:
  /// **'Edit Employee'**
  String get editEmployee;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @pin.
  ///
  /// In en, this message translates to:
  /// **'PIN'**
  String get pin;

  /// No description provided for @role.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get role;

  /// No description provided for @admin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get admin;

  /// No description provided for @cashier.
  ///
  /// In en, this message translates to:
  /// **'Cashier'**
  String get cashier;

  /// No description provided for @catBeverages.
  ///
  /// In en, this message translates to:
  /// **'Beverages'**
  String get catBeverages;

  /// No description provided for @catRiceGrains.
  ///
  /// In en, this message translates to:
  /// **'Rice & Grains'**
  String get catRiceGrains;

  /// No description provided for @catDalPulses.
  ///
  /// In en, this message translates to:
  /// **'Dal & Pulses'**
  String get catDalPulses;

  /// No description provided for @catOilsFats.
  ///
  /// In en, this message translates to:
  /// **'Cooking Oils & Fats'**
  String get catOilsFats;

  /// No description provided for @catSpicesSeasonings.
  ///
  /// In en, this message translates to:
  /// **'Spices & Seasonings'**
  String get catSpicesSeasonings;

  /// No description provided for @catCannedFoods.
  ///
  /// In en, this message translates to:
  /// **'Canned & Preserved Foods'**
  String get catCannedFoods;

  /// No description provided for @catSnacksBiscuits.
  ///
  /// In en, this message translates to:
  /// **'Snacks & Biscuits'**
  String get catSnacksBiscuits;

  /// No description provided for @catConfectionerySweets.
  ///
  /// In en, this message translates to:
  /// **'Confectionery & Sweets'**
  String get catConfectionerySweets;

  /// No description provided for @catBabyProducts.
  ///
  /// In en, this message translates to:
  /// **'Baby & Infant Products'**
  String get catBabyProducts;

  /// No description provided for @catPersonalCare.
  ///
  /// In en, this message translates to:
  /// **'Personal Care'**
  String get catPersonalCare;

  /// No description provided for @catHouseholdCleaning.
  ///
  /// In en, this message translates to:
  /// **'Household Cleaning'**
  String get catHouseholdCleaning;

  /// No description provided for @catStationeryOffice.
  ///
  /// In en, this message translates to:
  /// **'Stationery & Office'**
  String get catStationeryOffice;

  /// No description provided for @catTobacco.
  ///
  /// In en, this message translates to:
  /// **'Cigarettes & Tobacco'**
  String get catTobacco;

  /// No description provided for @catFuel.
  ///
  /// In en, this message translates to:
  /// **'Firewood & Fuel'**
  String get catFuel;

  /// No description provided for @catHardwareTools.
  ///
  /// In en, this message translates to:
  /// **'Hardware & Tools'**
  String get catHardwareTools;

  /// No description provided for @catFarmingGarden.
  ///
  /// In en, this message translates to:
  /// **'Farming & Garden'**
  String get catFarmingGarden;

  /// No description provided for @catPetSupplies.
  ///
  /// In en, this message translates to:
  /// **'Pet Food & Supplies'**
  String get catPetSupplies;

  /// No description provided for @catElectricalLighting.
  ///
  /// In en, this message translates to:
  /// **'Electrical & Lighting'**
  String get catElectricalLighting;

  /// No description provided for @catAutomotive.
  ///
  /// In en, this message translates to:
  /// **'Automotive'**
  String get catAutomotive;

  /// No description provided for @catOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get catOther;

  /// No description provided for @shareViaWhatsApp.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp'**
  String get shareViaWhatsApp;

  /// No description provided for @shareViaSMS.
  ///
  /// In en, this message translates to:
  /// **'SMS'**
  String get shareViaSMS;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome Back'**
  String get welcomeBack;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// No description provided for @signInPrompt.
  ///
  /// In en, this message translates to:
  /// **'Sign in to your account'**
  String get signInPrompt;

  /// No description provided for @signUpPrompt.
  ///
  /// In en, this message translates to:
  /// **'Enter your details to register'**
  String get signUpPrompt;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @verifyOtp.
  ///
  /// In en, this message translates to:
  /// **'VERIFY OTP'**
  String get verifyOtp;

  /// No description provided for @sendOtp.
  ///
  /// In en, this message translates to:
  /// **'SEND OTP'**
  String get sendOtp;

  /// No description provided for @logIn.
  ///
  /// In en, this message translates to:
  /// **'LOG IN'**
  String get logIn;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'SIGN UP'**
  String get signUp;

  /// No description provided for @newHerePrompt.
  ///
  /// In en, this message translates to:
  /// **'New here? Create Account'**
  String get newHerePrompt;

  /// No description provided for @backToLogin.
  ///
  /// In en, this message translates to:
  /// **'Back to Log In'**
  String get backToLogin;

  /// No description provided for @continueOffline.
  ///
  /// In en, this message translates to:
  /// **'Continue Offline (Local Storage)'**
  String get continueOffline;

  /// No description provided for @staffLogin.
  ///
  /// In en, this message translates to:
  /// **'STAFF LOGIN'**
  String get staffLogin;

  /// No description provided for @verificationCode.
  ///
  /// In en, this message translates to:
  /// **'Verification Code'**
  String get verificationCode;

  /// No description provided for @otpSent.
  ///
  /// In en, this message translates to:
  /// **'OTP Sent!'**
  String get otpSent;

  /// No description provided for @enterPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Please enter phone number'**
  String get enterPhoneNumber;

  /// No description provided for @enterOtp.
  ///
  /// In en, this message translates to:
  /// **'Please enter OTP'**
  String get enterOtp;

  /// No description provided for @fillAllFields.
  ///
  /// In en, this message translates to:
  /// **'Please fill in all fields'**
  String get fillAllFields;

  /// No description provided for @authFailed.
  ///
  /// In en, this message translates to:
  /// **'Authentication failed. Please try again.'**
  String get authFailed;

  /// No description provided for @whoAreYou.
  ///
  /// In en, this message translates to:
  /// **'Who are you?'**
  String get whoAreYou;

  /// No description provided for @selectProfilePrompt.
  ///
  /// In en, this message translates to:
  /// **'Select your profile to continue'**
  String get selectProfilePrompt;

  /// No description provided for @noProfilesFound.
  ///
  /// In en, this message translates to:
  /// **'No profiles found'**
  String get noProfilesFound;

  /// No description provided for @owner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get owner;

  /// No description provided for @staff.
  ///
  /// In en, this message translates to:
  /// **'Staff'**
  String get staff;

  /// No description provided for @scanQrCode.
  ///
  /// In en, this message translates to:
  /// **'Scan QR Code'**
  String get scanQrCode;

  /// No description provided for @enterStaffCode.
  ///
  /// In en, this message translates to:
  /// **'Enter 6-Digit Code'**
  String get enterStaffCode;

  /// No description provided for @staffLoginInstructions.
  ///
  /// In en, this message translates to:
  /// **'Ask the owner to generate a login code for you.'**
  String get staffLoginInstructions;

  /// No description provided for @typeCode.
  ///
  /// In en, this message translates to:
  /// **'TYPE CODE'**
  String get typeCode;

  /// No description provided for @scanQr.
  ///
  /// In en, this message translates to:
  /// **'SCAN QR'**
  String get scanQr;

  /// No description provided for @codeValidityNote.
  ///
  /// In en, this message translates to:
  /// **'The code is valid for 2 minutes only.'**
  String get codeValidityNote;

  /// No description provided for @expenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get expenses;

  /// No description provided for @purchases.
  ///
  /// In en, this message translates to:
  /// **'PURCHASES'**
  String get purchases;

  /// No description provided for @returns.
  ///
  /// In en, this message translates to:
  /// **'Returns'**
  String get returns;

  /// No description provided for @syncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing data...'**
  String get syncing;

  /// No description provided for @syncError.
  ///
  /// In en, this message translates to:
  /// **'Sync Error'**
  String get syncError;

  /// No description provided for @restoring.
  ///
  /// In en, this message translates to:
  /// **'Restoring data...'**
  String get restoring;

  /// No description provided for @syncActive.
  ///
  /// In en, this message translates to:
  /// **'Cloud Sync Active'**
  String get syncActive;

  /// No description provided for @synced.
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get synced;

  /// No description provided for @ago.
  ///
  /// In en, this message translates to:
  /// **'ago'**
  String get ago;

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get justNow;

  /// No description provided for @minShort.
  ///
  /// In en, this message translates to:
  /// **'m'**
  String get minShort;

  /// No description provided for @hourShort.
  ///
  /// In en, this message translates to:
  /// **'h'**
  String get hourShort;

  /// No description provided for @dayShort.
  ///
  /// In en, this message translates to:
  /// **'d'**
  String get dayShort;

  /// No description provided for @selectBranch.
  ///
  /// In en, this message translates to:
  /// **'Select Branch'**
  String get selectBranch;

  /// No description provided for @teamManagement.
  ///
  /// In en, this message translates to:
  /// **'Team Management'**
  String get teamManagement;

  /// No description provided for @staffMembers.
  ///
  /// In en, this message translates to:
  /// **'Staff Members'**
  String get staffMembers;

  /// No description provided for @manageEmployeesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage employees and permissions'**
  String get manageEmployeesSubtitle;

  /// No description provided for @multiBranchManagement.
  ///
  /// In en, this message translates to:
  /// **'Multi-Branch Management'**
  String get multiBranchManagement;

  /// No description provided for @branches.
  ///
  /// In en, this message translates to:
  /// **'Branches'**
  String get branches;

  /// No description provided for @manageBranchesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage business locations'**
  String get manageBranchesSubtitle;

  /// No description provided for @barcodeScanner.
  ///
  /// In en, this message translates to:
  /// **'Barcode Scanner'**
  String get barcodeScanner;

  /// No description provided for @connectBarcodeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Connect Bluetooth scanner'**
  String get connectBarcodeSubtitle;

  /// No description provided for @bluetoothPrinter.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth Thermal Printer'**
  String get bluetoothPrinter;

  /// No description provided for @connected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// No description provided for @notConnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get notConnected;

  /// No description provided for @scan.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get scan;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @autoSyncSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sync data when online'**
  String get autoSyncSubtitle;

  /// No description provided for @exportDatabase.
  ///
  /// In en, this message translates to:
  /// **'Export database'**
  String get exportDatabase;

  /// No description provided for @importDatabaseFile.
  ///
  /// In en, this message translates to:
  /// **'Import database file'**
  String get importDatabaseFile;

  /// No description provided for @exportSalesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Export all sales to CSV'**
  String get exportSalesSubtitle;

  /// No description provided for @exportInventorySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Export product list to CSV'**
  String get exportInventorySubtitle;

  /// No description provided for @exportCustomersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Export customer list to CSV'**
  String get exportCustomersSubtitle;

  /// No description provided for @importProductsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Bulk upload from product list'**
  String get importProductsSubtitle;

  /// No description provided for @importSuccess.
  ///
  /// In en, this message translates to:
  /// **'Successfully imported {count} products'**
  String importSuccess(Object count);

  /// No description provided for @dangerZone.
  ///
  /// In en, this message translates to:
  /// **'Danger Zone'**
  String get dangerZone;

  /// No description provided for @clearAllData.
  ///
  /// In en, this message translates to:
  /// **'Clear All Data'**
  String get clearAllData;

  /// No description provided for @clearDataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Completely wipe the local database. This cannot be undone.'**
  String get clearDataSubtitle;

  /// No description provided for @wipeAllDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Wipe All Data?'**
  String get wipeAllDataTitle;

  /// No description provided for @wipeAllDataContent.
  ///
  /// In en, this message translates to:
  /// **'This will delete all products, sales, customers, and batches. Are you absolutely sure?'**
  String get wipeAllDataContent;

  /// No description provided for @wipeEverything.
  ///
  /// In en, this message translates to:
  /// **'WIPE EVERYTHING'**
  String get wipeEverything;

  /// No description provided for @databaseCleared.
  ///
  /// In en, this message translates to:
  /// **'Database cleared successfully'**
  String get databaseCleared;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// No description provided for @deleteAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete your account and all associated data.'**
  String get deleteAccountSubtitle;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Account?'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountWarning.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone. All your shop data, inventory, and sales records will be permanently deleted from the cloud.'**
  String get deleteAccountWarning;

  /// No description provided for @deleteAccountConfirm.
  ///
  /// In en, this message translates to:
  /// **'DELETE MY ACCOUNT'**
  String get deleteAccountConfirm;

  /// No description provided for @notSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get notSet;

  /// No description provided for @lowStockAlertSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Alert when stock < {threshold}'**
  String lowStockAlertSubtitle(Object threshold);

  /// No description provided for @printer.
  ///
  /// In en, this message translates to:
  /// **'Printer'**
  String get printer;

  /// No description provided for @loginMethodDisabled.
  ///
  /// In en, this message translates to:
  /// **'This login method is currently disabled. Please contact support.'**
  String get loginMethodDisabled;

  /// No description provided for @accessDenied.
  ///
  /// In en, this message translates to:
  /// **'Access Denied: Permission required'**
  String get accessDenied;

  /// No description provided for @ownerAccessRequired.
  ///
  /// In en, this message translates to:
  /// **'Access Denied: Owner access required'**
  String get ownerAccessRequired;

  /// No description provided for @stockOverview.
  ///
  /// In en, this message translates to:
  /// **'Stock Overview'**
  String get stockOverview;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @lowStock.
  ///
  /// In en, this message translates to:
  /// **'Low Stock'**
  String get lowStock;

  /// No description provided for @outOfStock.
  ///
  /// In en, this message translates to:
  /// **'Out of Stock'**
  String get outOfStock;

  /// No description provided for @noProductsFound.
  ///
  /// In en, this message translates to:
  /// **'No products found'**
  String get noProductsFound;

  /// No description provided for @stockLabel.
  ///
  /// In en, this message translates to:
  /// **'Stock: {count} {unit}'**
  String stockLabel(Object count, Object unit);

  /// No description provided for @batchTracked.
  ///
  /// In en, this message translates to:
  /// **'BATCH TRACKED'**
  String get batchTracked;

  /// No description provided for @restock.
  ///
  /// In en, this message translates to:
  /// **'Restock'**
  String get restock;

  /// No description provided for @trainMlModel.
  ///
  /// In en, this message translates to:
  /// **'Train ML Model'**
  String get trainMlModel;

  /// No description provided for @transactionHistory.
  ///
  /// In en, this message translates to:
  /// **'Transaction History'**
  String get transactionHistory;

  /// No description provided for @predictedStockout.
  ///
  /// In en, this message translates to:
  /// **'Predicted stockout in {days} days'**
  String predictedStockout(Object days);

  /// No description provided for @dailyVelocity.
  ///
  /// In en, this message translates to:
  /// **'Sales: {velocity}/day'**
  String dailyVelocity(Object velocity);

  /// No description provided for @currentStock.
  ///
  /// In en, this message translates to:
  /// **'Current stock: {count}'**
  String currentStock(Object count);

  /// No description provided for @newStock.
  ///
  /// In en, this message translates to:
  /// **'New stock: {count}'**
  String newStock(Object count);

  /// No description provided for @stockUpdated.
  ///
  /// In en, this message translates to:
  /// **'Stock updated'**
  String get stockUpdated;

  /// No description provided for @addStock.
  ///
  /// In en, this message translates to:
  /// **'Add Stock'**
  String get addStock;

  /// No description provided for @manualRestockNote.
  ///
  /// In en, this message translates to:
  /// **'Manual Restock'**
  String get manualRestockNote;

  /// No description provided for @errorLoadingProducts.
  ///
  /// In en, this message translates to:
  /// **'Error loading products'**
  String get errorLoadingProducts;

  /// No description provided for @enterQuantityHint.
  ///
  /// In en, this message translates to:
  /// **'Enter quantity ({unit})'**
  String enterQuantityHint(Object unit);

  /// No description provided for @notEnoughStock.
  ///
  /// In en, this message translates to:
  /// **'Not enough stock! Available: {qty}'**
  String notEnoughStock(Object qty);

  /// No description provided for @discountLabel.
  ///
  /// In en, this message translates to:
  /// **'Discount: {name}'**
  String discountLabel(Object name);

  /// No description provided for @maxDiscountAllowed.
  ///
  /// In en, this message translates to:
  /// **'Max allowed: {percent}%'**
  String maxDiscountAllowed(Object percent);

  /// No description provided for @enterDiscountAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter discount amount'**
  String get enterDiscountAmount;

  /// No description provided for @limitExceeded.
  ///
  /// In en, this message translates to:
  /// **'Limit exceeded! Max allowed: {amount} ({percent}%)'**
  String limitExceeded(Object amount, Object percent);

  /// No description provided for @invalidDiscount.
  ///
  /// In en, this message translates to:
  /// **'Invalid discount amount!'**
  String get invalidDiscount;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @billDiscount.
  ///
  /// In en, this message translates to:
  /// **'Bill Discount'**
  String get billDiscount;

  /// No description provided for @enterTotalDiscount.
  ///
  /// In en, this message translates to:
  /// **'Enter total discount'**
  String get enterTotalDiscount;

  /// No description provided for @clearCartTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear Cart?'**
  String get clearCartTitle;

  /// No description provided for @clearCartContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove all items?'**
  String get clearCartContent;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @selectCustomer.
  ///
  /// In en, this message translates to:
  /// **'Select Customer'**
  String get selectCustomer;

  /// No description provided for @balanceLabel.
  ///
  /// In en, this message translates to:
  /// **'Balance: {amount}'**
  String balanceLabel(Object amount);

  /// No description provided for @quickItem.
  ///
  /// In en, this message translates to:
  /// **'Quick Item (No Inventory)'**
  String get quickItem;

  /// No description provided for @addedToCart.
  ///
  /// In en, this message translates to:
  /// **'{name} added to cart'**
  String addedToCart(Object name);

  /// No description provided for @cartEmpty.
  ///
  /// In en, this message translates to:
  /// **'Cart is empty'**
  String get cartEmpty;

  /// No description provided for @searchToAdd.
  ///
  /// In en, this message translates to:
  /// **'Search for products to add'**
  String get searchToAdd;

  /// No description provided for @quick.
  ///
  /// In en, this message translates to:
  /// **'QUICK'**
  String get quick;

  /// No description provided for @batchLabel.
  ///
  /// In en, this message translates to:
  /// **'Batch: {batch}'**
  String batchLabel(Object batch);

  /// No description provided for @itemDiscountTooltip.
  ///
  /// In en, this message translates to:
  /// **'Item Discount'**
  String get itemDiscountTooltip;

  /// No description provided for @itemName.
  ///
  /// In en, this message translates to:
  /// **'Item Name'**
  String get itemName;

  /// No description provided for @price.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get price;

  /// No description provided for @update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// No description provided for @enterItemName.
  ///
  /// In en, this message translates to:
  /// **'Please enter item name'**
  String get enterItemName;

  /// No description provided for @enterValidPrice.
  ///
  /// In en, this message translates to:
  /// **'Please enter valid price'**
  String get enterValidPrice;

  /// No description provided for @enterValidQuantity.
  ///
  /// In en, this message translates to:
  /// **'Please enter valid quantity'**
  String get enterValidQuantity;

  /// No description provided for @addToCart.
  ///
  /// In en, this message translates to:
  /// **'ADD TO CART'**
  String get addToCart;

  /// No description provided for @paymentLessError.
  ///
  /// In en, this message translates to:
  /// **'Payment amount is less than total'**
  String get paymentLessError;

  /// No description provided for @saleComplete.
  ///
  /// In en, this message translates to:
  /// **'Sale Complete!'**
  String get saleComplete;

  /// No description provided for @change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// No description provided for @printReceipt80mm.
  ///
  /// In en, this message translates to:
  /// **'Print Receipt (80mm)'**
  String get printReceipt80mm;

  /// No description provided for @printInvoiceA4.
  ///
  /// In en, this message translates to:
  /// **'Print Invoice (A4)'**
  String get printInvoiceA4;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @paymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment Method'**
  String get paymentMethod;

  /// No description provided for @cashPayment.
  ///
  /// In en, this message translates to:
  /// **'Cash Payment'**
  String get cashPayment;

  /// No description provided for @quickAmounts.
  ///
  /// In en, this message translates to:
  /// **'Quick Amounts'**
  String get quickAmounts;

  /// No description provided for @exact.
  ///
  /// In en, this message translates to:
  /// **'Exact'**
  String get exact;

  /// No description provided for @insufficientPayment.
  ///
  /// In en, this message translates to:
  /// **'INSUFFICIENT PAYMENT'**
  String get insufficientPayment;

  /// No description provided for @customerDebtNote.
  ///
  /// In en, this message translates to:
  /// **'Note: Full amount will be added to customer debt.'**
  String get customerDebtNote;

  /// No description provided for @customModelNotFound.
  ///
  /// In en, this message translates to:
  /// **'Custom model not found in assets. Falling back to generic detection.'**
  String get customModelNotFound;

  /// No description provided for @aiSuggestion.
  ///
  /// In en, this message translates to:
  /// **'AI SUGGESTION'**
  String get aiSuggestion;

  /// No description provided for @scaleWeightLabel.
  ///
  /// In en, this message translates to:
  /// **'SCALE: {weight} {unit}'**
  String scaleWeightLabel(Object unit, Object weight);

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'ADD'**
  String get add;

  /// No description provided for @toggleSimulation.
  ///
  /// In en, this message translates to:
  /// **'Toggle Simulation Mode'**
  String get toggleSimulation;

  /// No description provided for @toggleCustomMl.
  ///
  /// In en, this message translates to:
  /// **'Toggle Custom ML'**
  String get toggleCustomMl;

  /// No description provided for @alignBarcodeHint.
  ///
  /// In en, this message translates to:
  /// **'Align barcode within the frame'**
  String get alignBarcodeHint;

  /// No description provided for @recentScans.
  ///
  /// In en, this message translates to:
  /// **'RECENT SCANS'**
  String get recentScans;

  /// No description provided for @itemsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String itemsCount(Object count);

  /// No description provided for @scanToBuildBill.
  ///
  /// In en, this message translates to:
  /// **'Scan items to build bill'**
  String get scanToBuildBill;

  /// No description provided for @doneScanning.
  ///
  /// In en, this message translates to:
  /// **'DONE SCANNING'**
  String get doneScanning;

  /// No description provided for @addWeightToBill.
  ///
  /// In en, this message translates to:
  /// **'Add {name}'**
  String addWeightToBill(Object name);

  /// No description provided for @enterWeightHint.
  ///
  /// In en, this message translates to:
  /// **'Enter weight in {unit}'**
  String enterWeightHint(Object unit);

  /// No description provided for @switchUser.
  ///
  /// In en, this message translates to:
  /// **'Switch User'**
  String get switchUser;

  /// No description provided for @restoringData.
  ///
  /// In en, this message translates to:
  /// **'Restoring Data...'**
  String get restoringData;

  /// No description provided for @restoringDataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Downloading your business data from cloud.'**
  String get restoringDataSubtitle;

  /// No description provided for @inventoryManagementRequired.
  ///
  /// In en, this message translates to:
  /// **'Access Denied: Inventory Management required'**
  String get inventoryManagementRequired;

  /// No description provided for @reportsViewRequired.
  ///
  /// In en, this message translates to:
  /// **'Access Denied: Reports View required'**
  String get reportsViewRequired;

  /// No description provided for @returnProcessingRequired.
  ///
  /// In en, this message translates to:
  /// **'Access Denied: Return Processing required'**
  String get returnProcessingRequired;

  /// No description provided for @smartRestockUrgency.
  ///
  /// In en, this message translates to:
  /// **'SMART RESTOCK URGENCY'**
  String get smartRestockUrgency;

  /// No description provided for @createPo.
  ///
  /// In en, this message translates to:
  /// **'CREATE PO'**
  String get createPo;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'VIEW ALL'**
  String get viewAll;

  /// No description provided for @pleaseAddSupplierFirst.
  ///
  /// In en, this message translates to:
  /// **'Please add a supplier first'**
  String get pleaseAddSupplierFirst;

  /// No description provided for @poCreatedFor.
  ///
  /// In en, this message translates to:
  /// **'Purchase Order created for {name}'**
  String poCreatedFor(Object name);

  /// No description provided for @outInDays.
  ///
  /// In en, this message translates to:
  /// **'Out in {days} days'**
  String outInDays(Object days);

  /// No description provided for @reorder.
  ///
  /// In en, this message translates to:
  /// **'REORDER'**
  String get reorder;

  /// No description provided for @refundedToday.
  ///
  /// In en, this message translates to:
  /// **'{amount} refunded today'**
  String refundedToday(Object amount);

  /// No description provided for @billsGenerated.
  ///
  /// In en, this message translates to:
  /// **'{count} bills generated'**
  String billsGenerated(Object count);

  /// No description provided for @billGenerated.
  ///
  /// In en, this message translates to:
  /// **'{count} bill generated'**
  String billGenerated(Object count);

  /// No description provided for @searchCustomerHint.
  ///
  /// In en, this message translates to:
  /// **'Search customer by name or phone...'**
  String get searchCustomerHint;

  /// No description provided for @segmentChampion.
  ///
  /// In en, this message translates to:
  /// **'Champion'**
  String get segmentChampion;

  /// No description provided for @segmentLoyalist.
  ///
  /// In en, this message translates to:
  /// **'Loyalist'**
  String get segmentLoyalist;

  /// No description provided for @segmentBigSpender.
  ///
  /// In en, this message translates to:
  /// **'Big Spender'**
  String get segmentBigSpender;

  /// No description provided for @segmentAtRisk.
  ///
  /// In en, this message translates to:
  /// **'At Risk'**
  String get segmentAtRisk;

  /// No description provided for @segmentNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get segmentNew;

  /// No description provided for @segmentLost.
  ///
  /// In en, this message translates to:
  /// **'Lost'**
  String get segmentLost;

  /// No description provided for @segmentRegular.
  ///
  /// In en, this message translates to:
  /// **'Regular'**
  String get segmentRegular;

  /// No description provided for @noCustomersFound.
  ///
  /// In en, this message translates to:
  /// **'No customers found matching search/filter'**
  String get noCustomersFound;

  /// No description provided for @newCustomer.
  ///
  /// In en, this message translates to:
  /// **'NEW CUSTOMER'**
  String get newCustomer;

  /// No description provided for @noCustomersYet.
  ///
  /// In en, this message translates to:
  /// **'No customers yet'**
  String get noCustomersYet;

  /// No description provided for @addCustomerHint.
  ///
  /// In en, this message translates to:
  /// **'Tap \"+\" to add a loyal customer'**
  String get addCustomerHint;

  /// No description provided for @debtLabel.
  ///
  /// In en, this message translates to:
  /// **'DEBT'**
  String get debtLabel;

  /// No description provided for @editCustomer.
  ///
  /// In en, this message translates to:
  /// **'Edit Customer'**
  String get editCustomer;

  /// No description provided for @addNewCustomer.
  ///
  /// In en, this message translates to:
  /// **'Add New Customer'**
  String get addNewCustomer;

  /// No description provided for @customerUpdatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Customer updated successfully'**
  String get customerUpdatedSuccessfully;

  /// No description provided for @customerAddedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Customer added successfully'**
  String get customerAddedSuccessfully;

  /// No description provided for @fullNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Full Name *'**
  String get fullNameLabel;

  /// No description provided for @phoneNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumberLabel;

  /// No description provided for @phoneHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., 0771234567'**
  String get phoneHint;

  /// No description provided for @addressLabel.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get addressLabel;

  /// No description provided for @optionalHint.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get optionalHint;

  /// No description provided for @updateCustomer.
  ///
  /// In en, this message translates to:
  /// **'UPDATE CUSTOMER'**
  String get updateCustomer;

  /// No description provided for @addCustomer.
  ///
  /// In en, this message translates to:
  /// **'ADD CUSTOMER'**
  String get addCustomer;

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// No description provided for @payments.
  ///
  /// In en, this message translates to:
  /// **'PAYMENTS'**
  String get payments;

  /// No description provided for @recordPayment.
  ///
  /// In en, this message translates to:
  /// **'RECORD PAYMENT'**
  String get recordPayment;

  /// No description provided for @totalUdari.
  ///
  /// In en, this message translates to:
  /// **'TOTAL UDARI'**
  String get totalUdari;

  /// No description provided for @lastVisit.
  ///
  /// In en, this message translates to:
  /// **'LAST VISIT'**
  String get lastVisit;

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} days ago'**
  String daysAgo(Object count);

  /// No description provided for @noPurchasesRecorded.
  ///
  /// In en, this message translates to:
  /// **'No purchases recorded'**
  String get noPurchasesRecorded;

  /// No description provided for @noPaymentsRecorded.
  ///
  /// In en, this message translates to:
  /// **'No payments recorded'**
  String get noPaymentsRecorded;

  /// No description provided for @receivedAmount.
  ///
  /// In en, this message translates to:
  /// **'Received {amount}'**
  String receivedAmount(Object amount);

  /// No description provided for @recordRepayment.
  ///
  /// In en, this message translates to:
  /// **'Record Repayment'**
  String get recordRepayment;

  /// No description provided for @currentDebt.
  ///
  /// In en, this message translates to:
  /// **'Current Debt: {amount}'**
  String currentDebt(Object amount);

  /// No description provided for @amountReceivedLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount Received (\$)'**
  String get amountReceivedLabel;

  /// No description provided for @noteOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'Note (Optional)'**
  String get noteOptionalLabel;

  /// No description provided for @partialPaymentHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Partial payment'**
  String get partialPaymentHint;

  /// No description provided for @savePayment.
  ///
  /// In en, this message translates to:
  /// **'SAVE PAYMENT'**
  String get savePayment;

  /// No description provided for @whatsappDebtReminder.
  ///
  /// In en, this message translates to:
  /// **'Hello {name}, this is a reminder regarding your outstanding balance of {amount} at QuickBill POS. Thank you!'**
  String whatsappDebtReminder(Object amount, Object name);

  /// No description provided for @whatsappGenericGreeting.
  ///
  /// In en, this message translates to:
  /// **'Hello {name}, thank you for shopping with us at QuickBill POS!'**
  String whatsappGenericGreeting(Object name);

  /// No description provided for @editProduct.
  ///
  /// In en, this message translates to:
  /// **'Edit Product'**
  String get editProduct;

  /// No description provided for @addNewProduct.
  ///
  /// In en, this message translates to:
  /// **'Add New Product'**
  String get addNewProduct;

  /// No description provided for @productUpdatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Product updated successfully'**
  String get productUpdatedSuccessfully;

  /// No description provided for @productAddedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Product added successfully'**
  String get productAddedSuccessfully;

  /// No description provided for @addPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add Photo'**
  String get addPhoto;

  /// No description provided for @productNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Product Name *'**
  String get productNameLabel;

  /// No description provided for @productNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Rice (1kg)'**
  String get productNameHint;

  /// No description provided for @productNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Product name is required'**
  String get productNameRequired;

  /// No description provided for @barcodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Barcode'**
  String get barcodeLabel;

  /// No description provided for @barcodeScanned.
  ///
  /// In en, this message translates to:
  /// **'Barcode scanned: {barcode}'**
  String barcodeScanned(Object barcode);

  /// No description provided for @sellingPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Selling Price *'**
  String get sellingPriceLabel;

  /// No description provided for @priceRequired.
  ///
  /// In en, this message translates to:
  /// **'Price required'**
  String get priceRequired;

  /// No description provided for @invalidPrice.
  ///
  /// In en, this message translates to:
  /// **'Invalid price'**
  String get invalidPrice;

  /// No description provided for @costPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Cost Price'**
  String get costPriceLabel;

  /// No description provided for @trackBatchesLabel.
  ///
  /// In en, this message translates to:
  /// **'Track Batches'**
  String get trackBatchesLabel;

  /// No description provided for @trackBatchesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage stock via batches (expiry, unique codes)'**
  String get trackBatchesSubtitle;

  /// No description provided for @batchStockNote.
  ///
  /// In en, this message translates to:
  /// **'Stock will be managed per batch. Add batches via \"Manage Batches\" after saving.'**
  String get batchStockNote;

  /// No description provided for @stockQuantityLabel.
  ///
  /// In en, this message translates to:
  /// **'Stock Quantity *'**
  String get stockQuantityLabel;

  /// No description provided for @stockRequired.
  ///
  /// In en, this message translates to:
  /// **'Stock required'**
  String get stockRequired;

  /// No description provided for @invalidQuantity.
  ///
  /// In en, this message translates to:
  /// **'Invalid quantity'**
  String get invalidQuantity;

  /// No description provided for @minStockAlertLabel.
  ///
  /// In en, this message translates to:
  /// **'Min Stock Alert'**
  String get minStockAlertLabel;

  /// No description provided for @updateProduct.
  ///
  /// In en, this message translates to:
  /// **'UPDATE PRODUCT'**
  String get updateProduct;

  /// No description provided for @addProduct.
  ///
  /// In en, this message translates to:
  /// **'ADD PRODUCT'**
  String get addProduct;

  /// No description provided for @photoLibrary.
  ///
  /// In en, this message translates to:
  /// **'Photo Library'**
  String get photoLibrary;

  /// No description provided for @camera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get camera;

  /// No description provided for @errorPickingImage.
  ///
  /// In en, this message translates to:
  /// **'Error picking image'**
  String get errorPickingImage;

  /// No description provided for @editBatch.
  ///
  /// In en, this message translates to:
  /// **'Edit Batch: {name}'**
  String editBatch(Object name);

  /// No description provided for @addBatch.
  ///
  /// In en, this message translates to:
  /// **'Add Batch: {name}'**
  String addBatch(Object name);

  /// No description provided for @batchUpdatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Batch updated successfully'**
  String get batchUpdatedSuccessfully;

  /// No description provided for @batchAddedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Batch added successfully'**
  String get batchAddedSuccessfully;

  /// No description provided for @batchNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Batch Number *'**
  String get batchNumberLabel;

  /// No description provided for @regenerateTooltip.
  ///
  /// In en, this message translates to:
  /// **'Regenerate'**
  String get regenerateTooltip;

  /// No description provided for @batchBarcodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Batch Barcode *'**
  String get batchBarcodeLabel;

  /// No description provided for @batchBarcodeHint.
  ///
  /// In en, this message translates to:
  /// **'Scan or enter unique ID'**
  String get batchBarcodeHint;

  /// No description provided for @barcodeScanCancelled.
  ///
  /// In en, this message translates to:
  /// **'Barcode scan cancelled'**
  String get barcodeScanCancelled;

  /// No description provided for @generateBarcode.
  ///
  /// In en, this message translates to:
  /// **'Generate Barcode'**
  String get generateBarcode;

  /// No description provided for @quantityLabel.
  ///
  /// In en, this message translates to:
  /// **'Quantity *'**
  String get quantityLabel;

  /// No description provided for @mustBeGreaterThanZero.
  ///
  /// In en, this message translates to:
  /// **'Must be > 0'**
  String get mustBeGreaterThanZero;

  /// No description provided for @expiryDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Expiry Date'**
  String get expiryDateLabel;

  /// No description provided for @factorySupplierLabel.
  ///
  /// In en, this message translates to:
  /// **'Factory / Supplier Code'**
  String get factorySupplierLabel;

  /// No description provided for @updateBatch.
  ///
  /// In en, this message translates to:
  /// **'UPDATE BATCH'**
  String get updateBatch;

  /// No description provided for @saveBatch.
  ///
  /// In en, this message translates to:
  /// **'SAVE BATCH'**
  String get saveBatch;

  /// No description provided for @suppliersTitle.
  ///
  /// In en, this message translates to:
  /// **'Suppliers'**
  String get suppliersTitle;

  /// No description provided for @searchSuppliersHint.
  ///
  /// In en, this message translates to:
  /// **'Search suppliers...'**
  String get searchSuppliersHint;

  /// No description provided for @newSupplier.
  ///
  /// In en, this message translates to:
  /// **'NEW SUPPLIER'**
  String get newSupplier;

  /// No description provided for @noSuppliersFound.
  ///
  /// In en, this message translates to:
  /// **'No suppliers found'**
  String get noSuppliersFound;

  /// No description provided for @editSupplier.
  ///
  /// In en, this message translates to:
  /// **'Edit Supplier'**
  String get editSupplier;

  /// No description provided for @addSupplier.
  ///
  /// In en, this message translates to:
  /// **'Add Supplier'**
  String get addSupplier;

  /// No description provided for @supplierUpdatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Supplier updated successfully'**
  String get supplierUpdatedSuccessfully;

  /// No description provided for @supplierAddedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Supplier added successfully'**
  String get supplierAddedSuccessfully;

  /// No description provided for @errorSavingSupplier.
  ///
  /// In en, this message translates to:
  /// **'Error saving supplier'**
  String get errorSavingSupplier;

  /// No description provided for @supplierNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Supplier Name'**
  String get supplierNameLabel;

  /// No description provided for @pleaseEnterName.
  ///
  /// In en, this message translates to:
  /// **'Please enter name'**
  String get pleaseEnterName;

  /// No description provided for @categoryHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Styling'**
  String get categoryHint;

  /// No description provided for @updateSupplier.
  ///
  /// In en, this message translates to:
  /// **'UPDATE SUPPLIER'**
  String get updateSupplier;

  /// No description provided for @saveSupplier.
  ///
  /// In en, this message translates to:
  /// **'SAVE SUPPLIER'**
  String get saveSupplier;

  /// No description provided for @deleteSupplier.
  ///
  /// In en, this message translates to:
  /// **'DELETE SUPPLIER'**
  String get deleteSupplier;

  /// No description provided for @deleteSupplierTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Supplier'**
  String get deleteSupplierTitle;

  /// No description provided for @deleteSupplierConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this supplier?'**
  String get deleteSupplierConfirm;

  /// No description provided for @purchaseOrders.
  ///
  /// In en, this message translates to:
  /// **'Purchase Orders'**
  String get purchaseOrders;

  /// No description provided for @newOrder.
  ///
  /// In en, this message translates to:
  /// **'New Order'**
  String get newOrder;

  /// No description provided for @noPurchaseOrdersFound.
  ///
  /// In en, this message translates to:
  /// **'No purchase orders found'**
  String get noPurchaseOrdersFound;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// No description provided for @received.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get received;

  /// No description provided for @receiveGoods.
  ///
  /// In en, this message translates to:
  /// **'RECEIVE GOODS'**
  String get receiveGoods;

  /// No description provided for @receiveOrderTitle.
  ///
  /// In en, this message translates to:
  /// **'Receive Order?'**
  String get receiveOrderTitle;

  /// No description provided for @receiveOrderContent.
  ///
  /// In en, this message translates to:
  /// **'This will add {count} items to your inventory.'**
  String receiveOrderContent(Object count);

  /// No description provided for @inventoryUpdatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Inventory updated successfully'**
  String get inventoryUpdatedSuccessfully;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @deletePurchaseTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Purchase?'**
  String get deletePurchaseTitle;

  /// No description provided for @deletePurchaseContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this purchase order? This action cannot be undone.'**
  String get deletePurchaseContent;

  /// No description provided for @purchaseOrderDeleted.
  ///
  /// In en, this message translates to:
  /// **'Purchase order deleted'**
  String get purchaseOrderDeleted;

  /// No description provided for @unknownSupplier.
  ///
  /// In en, this message translates to:
  /// **'Unknown Supplier'**
  String get unknownSupplier;

  /// No description provided for @noCategory.
  ///
  /// In en, this message translates to:
  /// **'No category'**
  String get noCategory;

  /// No description provided for @poDraft.
  ///
  /// In en, this message translates to:
  /// **'PO #Draft'**
  String get poDraft;

  /// No description provided for @newPurchaseTitle.
  ///
  /// In en, this message translates to:
  /// **'New Purchase (Restock)'**
  String get newPurchaseTitle;

  /// No description provided for @providedItems.
  ///
  /// In en, this message translates to:
  /// **'Provided Products/Services'**
  String get providedItems;

  /// No description provided for @providedItemsHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Beverages, Electronics, Fresh Produce'**
  String get providedItemsHint;

  /// No description provided for @provides.
  ///
  /// In en, this message translates to:
  /// **'Provides'**
  String get provides;

  /// No description provided for @notesInvoiceLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes / Invoice Number'**
  String get notesInvoiceLabel;

  /// No description provided for @markAsReceivedLabel.
  ///
  /// In en, this message translates to:
  /// **'Mark as Received'**
  String get markAsReceivedLabel;

  /// No description provided for @markAsReceivedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enable only if you have already received the stock'**
  String get markAsReceivedSubtitle;

  /// No description provided for @supplierSectionLabel.
  ///
  /// In en, this message translates to:
  /// **'SUPPLIER'**
  String get supplierSectionLabel;

  /// No description provided for @selectSupplier.
  ///
  /// In en, this message translates to:
  /// **'Select Supplier'**
  String get selectSupplier;

  /// No description provided for @purchaseItemsLabel.
  ///
  /// In en, this message translates to:
  /// **'PURCHASE ITEMS'**
  String get purchaseItemsLabel;

  /// No description provided for @addProductsToRestock.
  ///
  /// In en, this message translates to:
  /// **'Add products to record restock'**
  String get addProductsToRestock;

  /// No description provided for @totalPurchaseAmount.
  ///
  /// In en, this message translates to:
  /// **'Total Purchase Amount'**
  String get totalPurchaseAmount;

  /// No description provided for @completeUpdateStock.
  ///
  /// In en, this message translates to:
  /// **'COMPLETE & UPDATE STOCK'**
  String get completeUpdateStock;

  /// No description provided for @saveAsPendingOrder.
  ///
  /// In en, this message translates to:
  /// **'SAVE AS PENDING ORDER'**
  String get saveAsPendingOrder;

  /// No description provided for @selectSupplierTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Supplier'**
  String get selectSupplierTitle;

  /// No description provided for @selectProductToRestock.
  ///
  /// In en, this message translates to:
  /// **'Select Product to Restock'**
  String get selectProductToRestock;

  /// No description provided for @currentStockLabel.
  ///
  /// In en, this message translates to:
  /// **'Current Stock: {stock} {unit}'**
  String currentStockLabel(Object stock, Object unit);

  /// No description provided for @restockItem.
  ///
  /// In en, this message translates to:
  /// **'Restock: {name}'**
  String restockItem(Object name);

  /// No description provided for @quantityToAdd.
  ///
  /// In en, this message translates to:
  /// **'Quantity to Add ({unit})'**
  String quantityToAdd(Object unit);

  /// No description provided for @costPricePerUnit.
  ///
  /// In en, this message translates to:
  /// **'Cost Price per unit (\$)'**
  String get costPricePerUnit;

  /// No description provided for @batchDetails.
  ///
  /// In en, this message translates to:
  /// **'Batch Details'**
  String get batchDetails;

  /// No description provided for @batchNumberField.
  ///
  /// In en, this message translates to:
  /// **'Batch Number'**
  String get batchNumberField;

  /// No description provided for @addToList.
  ///
  /// In en, this message translates to:
  /// **'ADD TO LIST'**
  String get addToList;

  /// No description provided for @productNotFoundBarcode.
  ///
  /// In en, this message translates to:
  /// **'Product not found with barcode: {barcode}'**
  String productNotFoundBarcode(Object barcode);

  /// No description provided for @pleaseSelectSupplier.
  ///
  /// In en, this message translates to:
  /// **'Please select a supplier'**
  String get pleaseSelectSupplier;

  /// No description provided for @pleaseAddItem.
  ///
  /// In en, this message translates to:
  /// **'Please add at least one item'**
  String get pleaseAddItem;

  /// No description provided for @purchaseOrderUpdated.
  ///
  /// In en, this message translates to:
  /// **'Purchase order updated!'**
  String get purchaseOrderUpdated;

  /// No description provided for @purchaseRecordedStock.
  ///
  /// In en, this message translates to:
  /// **'Purchase recorded and stock updated!'**
  String get purchaseRecordedStock;

  /// No description provided for @purchaseOrderSavedPending.
  ///
  /// In en, this message translates to:
  /// **'Purchase order saved as Pending'**
  String get purchaseOrderSavedPending;

  /// No description provided for @batchesTitle.
  ///
  /// In en, this message translates to:
  /// **'Batches'**
  String get batchesTitle;

  /// No description provided for @addBatchFab.
  ///
  /// In en, this message translates to:
  /// **'Add Batch'**
  String get addBatchFab;

  /// No description provided for @noBatchesFound.
  ///
  /// In en, this message translates to:
  /// **'No batches found'**
  String get noBatchesFound;

  /// No description provided for @createFirstBatch.
  ///
  /// In en, this message translates to:
  /// **'Create First Batch'**
  String get createFirstBatch;

  /// No description provided for @expired.
  ///
  /// In en, this message translates to:
  /// **'EXPIRED'**
  String get expired;

  /// No description provided for @expiresSoon.
  ///
  /// In en, this message translates to:
  /// **'EXP SOON'**
  String get expiresSoon;

  /// No description provided for @batchStockLabel.
  ///
  /// In en, this message translates to:
  /// **'Stock: {stock} {unit}'**
  String batchStockLabel(Object stock, Object unit);

  /// No description provided for @expiresLabel.
  ///
  /// In en, this message translates to:
  /// **'Expires: {date}'**
  String expiresLabel(Object date);

  /// No description provided for @editDetails.
  ///
  /// In en, this message translates to:
  /// **'Edit Details'**
  String get editDetails;

  /// No description provided for @deleteBatch.
  ///
  /// In en, this message translates to:
  /// **'Delete Batch'**
  String get deleteBatch;

  /// No description provided for @deleteBatchTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Batch?'**
  String get deleteBatchTitle;

  /// No description provided for @deleteBatchContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete batch {batchNumber}? This will remove it from inventory.'**
  String deleteBatchContent(Object batchNumber);

  /// No description provided for @batchDeleted.
  ///
  /// In en, this message translates to:
  /// **'Batch deleted'**
  String get batchDeleted;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @addToBill.
  ///
  /// In en, this message translates to:
  /// **'Add to Bill'**
  String get addToBill;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// No description provided for @lightThemeEnabled.
  ///
  /// In en, this message translates to:
  /// **'Light theme enabled'**
  String get lightThemeEnabled;

  /// No description provided for @darkThemeEnabled.
  ///
  /// In en, this message translates to:
  /// **'Dark theme enabled'**
  String get darkThemeEnabled;

  /// No description provided for @printerSection.
  ///
  /// In en, this message translates to:
  /// **'Printer'**
  String get printerSection;

  /// No description provided for @aiWelcomeMessage.
  ///
  /// In en, this message translates to:
  /// **'Hello! I am your QuickBill AI Assistant.\nHow can I help you grow your business today?'**
  String get aiWelcomeMessage;

  /// No description provided for @aiQuerySalesToday.
  ///
  /// In en, this message translates to:
  /// **'What were my sales today?'**
  String get aiQuerySalesToday;

  /// No description provided for @aiQueryLowStock.
  ///
  /// In en, this message translates to:
  /// **'Are any items low on stock?'**
  String get aiQueryLowStock;

  /// No description provided for @aiQueryInventory.
  ///
  /// In en, this message translates to:
  /// **'Show my inventory'**
  String get aiQueryInventory;

  /// No description provided for @aiWarmingUp.
  ///
  /// In en, this message translates to:
  /// **'I\'m still warming up my Advanced engine. Please give me just a few more seconds to get ready! ⏳'**
  String get aiWarmingUp;

  /// No description provided for @aiThinkingMessage.
  ///
  /// In en, this message translates to:
  /// **'⚡ Thinking...'**
  String get aiThinkingMessage;

  /// No description provided for @aiErrorPrefix.
  ///
  /// In en, this message translates to:
  /// **'Error: '**
  String get aiErrorPrefix;

  /// No description provided for @aiAdvancedActiveMessage.
  ///
  /// In en, this message translates to:
  /// **'🎉 Advanced AI is now active!'**
  String get aiAdvancedActiveMessage;

  /// No description provided for @aiScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'QuickBill AI ✨'**
  String get aiScreenTitle;

  /// No description provided for @aiLiteMode.
  ///
  /// In en, this message translates to:
  /// **'🪶 Lite'**
  String get aiLiteMode;

  /// No description provided for @aiAdvancedMode.
  ///
  /// In en, this message translates to:
  /// **'⚡ Advanced'**
  String get aiAdvancedMode;

  /// No description provided for @aiErrorStatus.
  ///
  /// In en, this message translates to:
  /// **'⚠️ Error'**
  String get aiErrorStatus;

  /// No description provided for @aiInitializingStatus.
  ///
  /// In en, this message translates to:
  /// **'⏳ Initializing...'**
  String get aiInitializingStatus;

  /// No description provided for @aiUpgradeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Advanced AI'**
  String get aiUpgradeTooltip;

  /// No description provided for @aiLightweightWarning.
  ///
  /// In en, this message translates to:
  /// **'Lightweight mode active. Tap ☁️ above to download Gemma AI for smarter answers.'**
  String get aiLightweightWarning;

  /// No description provided for @aiThinkingStatus.
  ///
  /// In en, this message translates to:
  /// **'AI is thinking...'**
  String get aiThinkingStatus;

  /// No description provided for @aiMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Message QuickBill AI...'**
  String get aiMessageHint;

  /// No description provided for @aiInitializingEngine.
  ///
  /// In en, this message translates to:
  /// **'⚡ Initializing high-performance engine...'**
  String get aiInitializingEngine;

  /// No description provided for @aiEngineErrorPrefix.
  ///
  /// In en, this message translates to:
  /// **'⚠️ AI Engine Error:\n'**
  String get aiEngineErrorPrefix;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @redownloadModel.
  ///
  /// In en, this message translates to:
  /// **'Redownload Model'**
  String get redownloadModel;

  /// No description provided for @downloadCancelled.
  ///
  /// In en, this message translates to:
  /// **'Download cancelled.'**
  String get downloadCancelled;

  /// No description provided for @permissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Permission denied!\n\nPlease update your Firebase Storage Rules to allow public read access to the \"models\" folder.'**
  String get permissionDenied;

  /// No description provided for @modelNotFound.
  ///
  /// In en, this message translates to:
  /// **'Model file not found in Firebase Storage. Please ensure \"gemma-3-270m-it-int8.task\" exists in the \"models\" folder.'**
  String get modelNotFound;

  /// No description provided for @downloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed: {error}'**
  String downloadFailed(Object error);

  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String importFailed(Object error);

  /// No description provided for @fixPermissionsTitle.
  ///
  /// In en, this message translates to:
  /// **'🔧 How to fix Permissions'**
  String get fixPermissionsTitle;

  /// No description provided for @fixPermissionsContent1.
  ///
  /// In en, this message translates to:
  /// **'The \"412\" error means Firebase lacks internal permission to serve the file.'**
  String get fixPermissionsContent1;

  /// No description provided for @fixPermissionsContent2.
  ///
  /// In en, this message translates to:
  /// **'1. Go to Firebase Console > Storage.'**
  String get fixPermissionsContent2;

  /// No description provided for @fixPermissionsContent3.
  ///
  /// In en, this message translates to:
  /// **'2. If you see a prompt to \"Link bucket\", click it.'**
  String get fixPermissionsContent3;

  /// No description provided for @fixPermissionsContent4.
  ///
  /// In en, this message translates to:
  /// **'3. Check IAM settings in Google Cloud Console.'**
  String get fixPermissionsContent4;

  /// No description provided for @fixPermissionsContent5.
  ///
  /// In en, this message translates to:
  /// **'4. Ensure \"Firebase Storage Service Agent\" has \"Storage Object Viewer\" role.'**
  String get fixPermissionsContent5;

  /// No description provided for @fixPermissionsContent6.
  ///
  /// In en, this message translates to:
  /// **'Alternative: Download the .task file manually and use the \"Import\" button.'**
  String get fixPermissionsContent6;

  /// No description provided for @gotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get gotIt;

  /// No description provided for @upgradeToAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Advanced AI'**
  String get upgradeToAdvanced;

  /// No description provided for @downloadModelDesc.
  ///
  /// In en, this message translates to:
  /// **'Download the Gemma 3 270M model (~150-200 MB) for smarter, conversational answers. No cloud required after download.'**
  String get downloadModelDesc;

  /// No description provided for @howToFix.
  ///
  /// In en, this message translates to:
  /// **'How to fix this?'**
  String get howToFix;

  /// No description provided for @downloadingPercentage.
  ///
  /// In en, this message translates to:
  /// **'Downloading: {progress}%'**
  String downloadingPercentage(Object progress);

  /// No description provided for @cancelDownload.
  ///
  /// In en, this message translates to:
  /// **'Cancel Download'**
  String get cancelDownload;

  /// No description provided for @downloadComplete.
  ///
  /// In en, this message translates to:
  /// **'Download Complete!'**
  String get downloadComplete;

  /// No description provided for @downloadGemmaBtn.
  ///
  /// In en, this message translates to:
  /// **'Download Gemma AI (~150 MB)'**
  String get downloadGemmaBtn;

  /// No description provided for @importTaskFileBtn.
  ///
  /// In en, this message translates to:
  /// **'Import .task File Manually'**
  String get importTaskFileBtn;

  /// No description provided for @clearErrorBtn.
  ///
  /// In en, this message translates to:
  /// **'Clear Error'**
  String get clearErrorBtn;

  /// No description provided for @maybeLaterBtn.
  ///
  /// In en, this message translates to:
  /// **'Maybe later'**
  String get maybeLaterBtn;

  /// No description provided for @reportsDashboard.
  ///
  /// In en, this message translates to:
  /// **'Reports Dashboard'**
  String get reportsDashboard;

  /// No description provided for @globalView.
  ///
  /// In en, this message translates to:
  /// **'Global'**
  String get globalView;

  /// No description provided for @revenue.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get revenue;

  /// No description provided for @netProfit.
  ///
  /// In en, this message translates to:
  /// **'Net Profit'**
  String get netProfit;

  /// No description provided for @salesTrend.
  ///
  /// In en, this message translates to:
  /// **'Sales Trend'**
  String get salesTrend;

  /// No description provided for @salesByCategory.
  ///
  /// In en, this message translates to:
  /// **'Sales by Category'**
  String get salesByCategory;

  /// No description provided for @inventorySnapshot.
  ///
  /// In en, this message translates to:
  /// **'Inventory Snapshot'**
  String get inventorySnapshot;

  /// No description provided for @totalStockValueRetail.
  ///
  /// In en, this message translates to:
  /// **'Total Stock Value (Retail)'**
  String get totalStockValueRetail;

  /// No description provided for @totalStockValueCost.
  ///
  /// In en, this message translates to:
  /// **'Total Stock Value (Cost)'**
  String get totalStockValueCost;

  /// No description provided for @potentialProfit.
  ///
  /// In en, this message translates to:
  /// **'Potential Profit'**
  String get potentialProfit;

  /// No description provided for @topSellingProducts.
  ///
  /// In en, this message translates to:
  /// **'Top Selling Products'**
  String get topSellingProducts;

  /// No description provided for @highValueCustomers.
  ///
  /// In en, this message translates to:
  /// **'High-Value Customers'**
  String get highValueCustomers;

  /// No description provided for @detailedReports.
  ///
  /// In en, this message translates to:
  /// **'Detailed Reports'**
  String get detailedReports;

  /// No description provided for @profitabilityAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Profitability Analytics'**
  String get profitabilityAnalytics;

  /// No description provided for @profitabilityAnalyticsDesc.
  ///
  /// In en, this message translates to:
  /// **'Margins, expenses & profitability deep-dive'**
  String get profitabilityAnalyticsDesc;

  /// No description provided for @salesReport.
  ///
  /// In en, this message translates to:
  /// **'Sales Report'**
  String get salesReport;

  /// No description provided for @salesReportDesc.
  ///
  /// In en, this message translates to:
  /// **'Detailed transaction history'**
  String get salesReportDesc;

  /// No description provided for @profitLoss.
  ///
  /// In en, this message translates to:
  /// **'Profit & Loss'**
  String get profitLoss;

  /// No description provided for @profitLossDesc.
  ///
  /// In en, this message translates to:
  /// **'Revenue vs Cost of Goods Sold'**
  String get profitLossDesc;

  /// No description provided for @inventoryAudit.
  ///
  /// In en, this message translates to:
  /// **'Inventory Audit'**
  String get inventoryAudit;

  /// No description provided for @inventoryAuditDesc.
  ///
  /// In en, this message translates to:
  /// **'Valuation and stock status'**
  String get inventoryAuditDesc;

  /// No description provided for @refundReport.
  ///
  /// In en, this message translates to:
  /// **'Refund Report'**
  String get refundReport;

  /// No description provided for @refundReportDesc.
  ///
  /// In en, this message translates to:
  /// **'Itemized sales returns'**
  String get refundReportDesc;

  /// No description provided for @employeePerformance.
  ///
  /// In en, this message translates to:
  /// **'Employee Performance'**
  String get employeePerformance;

  /// No description provided for @employeePerformanceDesc.
  ///
  /// In en, this message translates to:
  /// **'Sales and hours by staff'**
  String get employeePerformanceDesc;

  /// No description provided for @peakHours.
  ///
  /// In en, this message translates to:
  /// **'Peak Hours'**
  String get peakHours;

  /// No description provided for @peakHoursDesc.
  ///
  /// In en, this message translates to:
  /// **'Heatmap of busiest days & hours'**
  String get peakHoursDesc;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @thisWeek.
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get thisWeek;

  /// No description provided for @thisMonth.
  ///
  /// In en, this message translates to:
  /// **'This Month'**
  String get thisMonth;

  /// No description provided for @threeMonths.
  ///
  /// In en, this message translates to:
  /// **'3 Months'**
  String get threeMonths;

  /// No description provided for @thisYear.
  ///
  /// In en, this message translates to:
  /// **'This Year'**
  String get thisYear;

  /// No description provided for @showingPeriod.
  ///
  /// In en, this message translates to:
  /// **'Showing: {start} - {end}'**
  String showingPeriod(Object start, Object end);

  /// No description provided for @globalPeriod.
  ///
  /// In en, this message translates to:
  /// **'GLOBAL VIEW: {start} - {end}'**
  String globalPeriod(Object start, Object end);

  /// No description provided for @totalInventoryValue.
  ///
  /// In en, this message translates to:
  /// **'TOTAL INVENTORY VALUE'**
  String get totalInventoryValue;

  /// No description provided for @totalItems.
  ///
  /// In en, this message translates to:
  /// **'Total Items'**
  String get totalItems;

  /// No description provided for @categories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categories;

  /// No description provided for @productValuation.
  ///
  /// In en, this message translates to:
  /// **'Product Valuation'**
  String get productValuation;

  /// No description provided for @value.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get value;

  /// No description provided for @profitLossStatement.
  ///
  /// In en, this message translates to:
  /// **'Profit & Loss Statement'**
  String get profitLossStatement;

  /// No description provided for @discountsGiven.
  ///
  /// In en, this message translates to:
  /// **'Discounts Given'**
  String get discountsGiven;

  /// No description provided for @refunds.
  ///
  /// In en, this message translates to:
  /// **'Refunds'**
  String get refunds;

  /// No description provided for @cogs.
  ///
  /// In en, this message translates to:
  /// **'Cost of Goods Sold (COGS)'**
  String get cogs;

  /// No description provided for @grossProfit.
  ///
  /// In en, this message translates to:
  /// **'Gross Profit'**
  String get grossProfit;

  /// No description provided for @profitCalculationNote.
  ///
  /// In en, this message translates to:
  /// **'Profit is calculated based on the cost price of items at the time of sale.'**
  String get profitCalculationNote;

  /// No description provided for @forPeriod.
  ///
  /// In en, this message translates to:
  /// **'For: {start} - {end}'**
  String forPeriod(Object start, Object end);

  /// No description provided for @detailedSalesReport.
  ///
  /// In en, this message translates to:
  /// **'Detailed Sales Report'**
  String get detailedSalesReport;

  /// No description provided for @noSalesPeriod.
  ///
  /// In en, this message translates to:
  /// **'No sales found for this period'**
  String get noSalesPeriod;

  /// No description provided for @transactionsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} transactions'**
  String transactionsCount(Object count);

  /// No description provided for @exportCsv.
  ///
  /// In en, this message translates to:
  /// **'Export CSV'**
  String get exportCsv;

  /// No description provided for @exportPdf.
  ///
  /// In en, this message translates to:
  /// **'Export PDF'**
  String get exportPdf;

  /// No description provided for @customerLabel.
  ///
  /// In en, this message translates to:
  /// **'Customer: {name}'**
  String customerLabel(Object name);

  /// No description provided for @billNo.
  ///
  /// In en, this message translates to:
  /// **'Bill No: {number}'**
  String billNo(Object number);

  /// No description provided for @dateLabel.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get dateLabel;

  /// No description provided for @timeLabel.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get timeLabel;

  /// No description provided for @paymentLabel.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get paymentLabel;

  /// No description provided for @phoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phoneLabel;

  /// No description provided for @itemsHeading.
  ///
  /// In en, this message translates to:
  /// **'ITEMS'**
  String get itemsHeading;

  /// No description provided for @receipt80mm.
  ///
  /// In en, this message translates to:
  /// **'Receipt (80mm)'**
  String get receipt80mm;

  /// No description provided for @invoiceA4.
  ///
  /// In en, this message translates to:
  /// **'Invoice (A4)'**
  String get invoiceA4;

  /// No description provided for @returnRefundItems.
  ///
  /// In en, this message translates to:
  /// **'Return / Refund Items'**
  String get returnRefundItems;

  /// No description provided for @aiPredictiveInsights.
  ///
  /// In en, this message translates to:
  /// **'AI PREDICTIVE INSIGHTS 🤖'**
  String get aiPredictiveInsights;

  /// No description provided for @profitWaterfall.
  ///
  /// In en, this message translates to:
  /// **'PROFIT WATERFALL'**
  String get profitWaterfall;

  /// No description provided for @profitabilityTrend.
  ///
  /// In en, this message translates to:
  /// **'PROFITABILITY TREND'**
  String get profitabilityTrend;

  /// No description provided for @categoryProfitability.
  ///
  /// In en, this message translates to:
  /// **'CATEGORY PROFITABILITY'**
  String get categoryProfitability;

  /// No description provided for @topProfitContributors.
  ///
  /// In en, this message translates to:
  /// **'TOP PROFIT CONTRIBUTORS'**
  String get topProfitContributors;

  /// No description provided for @grossMargin.
  ///
  /// In en, this message translates to:
  /// **'Gross Margin'**
  String get grossMargin;

  /// No description provided for @netMargin.
  ///
  /// In en, this message translates to:
  /// **'Net Margin'**
  String get netMargin;

  /// No description provided for @expenseRatio.
  ///
  /// In en, this message translates to:
  /// **'Expense Ratio'**
  String get expenseRatio;

  /// No description provided for @operatingExpenses.
  ///
  /// In en, this message translates to:
  /// **'Operating Expenses'**
  String get operatingExpenses;

  /// No description provided for @marginPercent.
  ///
  /// In en, this message translates to:
  /// **'Margin: {margin}%'**
  String marginPercent(Object margin);

  /// No description provided for @soldUnits.
  ///
  /// In en, this message translates to:
  /// **'Sold: {quantity} units'**
  String soldUnits(Object quantity);

  /// No description provided for @noTrendData.
  ///
  /// In en, this message translates to:
  /// **'No trend data'**
  String get noTrendData;

  /// No description provided for @countLabel.
  ///
  /// In en, this message translates to:
  /// **'Count'**
  String get countLabel;

  /// No description provided for @busiest.
  ///
  /// In en, this message translates to:
  /// **'Busiest'**
  String get busiest;

  /// No description provided for @quietest.
  ///
  /// In en, this message translates to:
  /// **'Quietest'**
  String get quietest;

  /// No description provided for @activityHeatmap.
  ///
  /// In en, this message translates to:
  /// **'ACTIVITY HEATMAP'**
  String get activityHeatmap;

  /// No description provided for @top5PeakSlots.
  ///
  /// In en, this message translates to:
  /// **'TOP 5 PEAK SLOTS'**
  String get top5PeakSlots;

  /// No description provided for @noSalesDataPeriod.
  ///
  /// In en, this message translates to:
  /// **'No sales data in this period'**
  String get noSalesDataPeriod;

  /// No description provided for @low.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get low;

  /// No description provided for @high.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get high;

  /// No description provided for @noRefundsExport.
  ///
  /// In en, this message translates to:
  /// **'No refunds to export'**
  String get noRefundsExport;

  /// No description provided for @noRefundsPeriod.
  ///
  /// In en, this message translates to:
  /// **'No refunds found for this period'**
  String get noRefundsPeriod;

  /// No description provided for @totalRefunded.
  ///
  /// In en, this message translates to:
  /// **'TOTAL REFUNDED'**
  String get totalRefunded;

  /// No description provided for @returnedToStock.
  ///
  /// In en, this message translates to:
  /// **'Returned to Stock'**
  String get returnedToStock;

  /// No description provided for @damagedWaste.
  ///
  /// In en, this message translates to:
  /// **'Damaged / Waste'**
  String get damagedWaste;

  /// No description provided for @reasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason: {reason}'**
  String reasonLabel(Object reason);

  /// No description provided for @returnedItemsHeading.
  ///
  /// In en, this message translates to:
  /// **'RETURNED ITEMS'**
  String get returnedItemsHeading;

  /// No description provided for @performanceReport.
  ///
  /// In en, this message translates to:
  /// **'Performance Report'**
  String get performanceReport;

  /// No description provided for @noPerformanceData.
  ///
  /// In en, this message translates to:
  /// **'No performance data available'**
  String get noPerformanceData;

  /// No description provided for @billsLabel.
  ///
  /// In en, this message translates to:
  /// **'Bills'**
  String get billsLabel;

  /// No description provided for @hoursLabel.
  ///
  /// In en, this message translates to:
  /// **'Hours'**
  String get hoursLabel;

  /// No description provided for @avgBillLabel.
  ///
  /// In en, this message translates to:
  /// **'Avg/Bill'**
  String get avgBillLabel;

  /// No description provided for @expenseManagement.
  ///
  /// In en, this message translates to:
  /// **'Expense Management'**
  String get expenseManagement;

  /// No description provided for @noExpensesRecorded.
  ///
  /// In en, this message translates to:
  /// **'No expenses recorded yet.'**
  String get noExpensesRecorded;

  /// No description provided for @logExpense.
  ///
  /// In en, this message translates to:
  /// **'Log Expense'**
  String get logExpense;

  /// No description provided for @logNewExpense.
  ///
  /// In en, this message translates to:
  /// **'Log New Expense'**
  String get logNewExpense;

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// No description provided for @noteOptional.
  ///
  /// In en, this message translates to:
  /// **'Note (Optional)'**
  String get noteOptional;

  /// No description provided for @saveExpense.
  ///
  /// In en, this message translates to:
  /// **'Save Expense'**
  String get saveExpense;

  /// No description provided for @deleteExpenseQuery.
  ///
  /// In en, this message translates to:
  /// **'Delete Expense?'**
  String get deleteExpenseQuery;

  /// No description provided for @deleteExpenseConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove this expense record?'**
  String get deleteExpenseConfirm;

  /// No description provided for @expRent.
  ///
  /// In en, this message translates to:
  /// **'Rent'**
  String get expRent;

  /// No description provided for @expElectricity.
  ///
  /// In en, this message translates to:
  /// **'Electricity'**
  String get expElectricity;

  /// No description provided for @expWater.
  ///
  /// In en, this message translates to:
  /// **'Water'**
  String get expWater;

  /// No description provided for @expSalary.
  ///
  /// In en, this message translates to:
  /// **'Salary'**
  String get expSalary;

  /// No description provided for @expTransport.
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get expTransport;

  /// No description provided for @expRepairs.
  ///
  /// In en, this message translates to:
  /// **'Repairs'**
  String get expRepairs;

  /// No description provided for @expMarketing.
  ///
  /// In en, this message translates to:
  /// **'Marketing'**
  String get expMarketing;

  /// No description provided for @expInventoryPurchase.
  ///
  /// In en, this message translates to:
  /// **'Inventory Purchase'**
  String get expInventoryPurchase;

  /// No description provided for @expGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get expGeneral;

  /// No description provided for @inventoryStockPrice.
  ///
  /// In en, this message translates to:
  /// **'Stock: {stock} {unit} • Price: {price}'**
  String inventoryStockPrice(Object stock, Object unit, Object price);

  /// No description provided for @shopTeamSettings.
  ///
  /// In en, this message translates to:
  /// **'Shop & Team Settings'**
  String get shopTeamSettings;

  /// No description provided for @shopTeamSettingsDesc.
  ///
  /// In en, this message translates to:
  /// **'Logo, contact details, staff & branch management'**
  String get shopTeamSettingsDesc;

  /// No description provided for @devicePrinting.
  ///
  /// In en, this message translates to:
  /// **'Device & Printing'**
  String get devicePrinting;

  /// No description provided for @devicePrintingDesc.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth receipt printer & barcode scanner settings'**
  String get devicePrintingDesc;

  /// No description provided for @preferencesAlerts.
  ///
  /// In en, this message translates to:
  /// **'Preferences & Alerts'**
  String get preferencesAlerts;

  /// No description provided for @preferencesAlertsDesc.
  ///
  /// In en, this message translates to:
  /// **'Language, region, theme mode & low stock limits'**
  String get preferencesAlertsDesc;

  /// No description provided for @dataBackups.
  ///
  /// In en, this message translates to:
  /// **'Data & Backups'**
  String get dataBackups;

  /// No description provided for @dataBackupsDesc.
  ///
  /// In en, this message translates to:
  /// **'Auto-sync, database backups, import/export & reset'**
  String get dataBackupsDesc;

  /// No description provided for @countryRegion.
  ///
  /// In en, this message translates to:
  /// **'Country/Region'**
  String get countryRegion;

  /// No description provided for @uploadingLogo.
  ///
  /// In en, this message translates to:
  /// **'Uploading logo...'**
  String get uploadingLogo;

  /// No description provided for @logoUpdated.
  ///
  /// In en, this message translates to:
  /// **'Logo updated successfully!'**
  String get logoUpdated;

  /// No description provided for @uploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed: {error}'**
  String uploadFailed(Object error);

  /// No description provided for @mainBranch.
  ///
  /// In en, this message translates to:
  /// **'Main Branch'**
  String get mainBranch;

  /// No description provided for @localization.
  ///
  /// In en, this message translates to:
  /// **'Localization'**
  String get localization;

  /// No description provided for @customer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get customer;

  /// No description provided for @entityCode.
  ///
  /// In en, this message translates to:
  /// **'Invoice Entity Code (QQQQ)'**
  String get entityCode;

  /// No description provided for @editEntityCode.
  ///
  /// In en, this message translates to:
  /// **'Edit Invoice Entity Code'**
  String get editEntityCode;

  /// No description provided for @entityCodeError.
  ///
  /// In en, this message translates to:
  /// **'Invalid code. Must be 1-15 alphanumeric characters without spaces.'**
  String get entityCodeError;

  /// No description provided for @damageAndWasteReport.
  ///
  /// In en, this message translates to:
  /// **'Damage & Waste'**
  String get damageAndWasteReport;

  /// No description provided for @damageAndWasteReportDesc.
  ///
  /// In en, this message translates to:
  /// **'Track lost inventory and damages'**
  String get damageAndWasteReportDesc;

  /// No description provided for @supplierReturnsReport.
  ///
  /// In en, this message translates to:
  /// **'Supplier Returns'**
  String get supplierReturnsReport;

  /// No description provided for @supplierReturnsReportDesc.
  ///
  /// In en, this message translates to:
  /// **'Track goods returned to suppliers'**
  String get supplierReturnsReportDesc;

  /// No description provided for @totalValueLost.
  ///
  /// In en, this message translates to:
  /// **'TOTAL VALUE LOST'**
  String get totalValueLost;

  /// No description provided for @totalReturnedValue.
  ///
  /// In en, this message translates to:
  /// **'TOTAL RETURNED VALUE'**
  String get totalReturnedValue;

  /// No description provided for @totalItemsWrittenOff.
  ///
  /// In en, this message translates to:
  /// **'{count} total items written off'**
  String totalItemsWrittenOff(Object count);

  /// No description provided for @totalItemsReturned.
  ///
  /// In en, this message translates to:
  /// **'{count} total items returned'**
  String totalItemsReturned(Object count);

  /// No description provided for @services.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get services;

  /// No description provided for @appointments.
  ///
  /// In en, this message translates to:
  /// **'Appointments'**
  String get appointments;

  /// No description provided for @staffSchedule.
  ///
  /// In en, this message translates to:
  /// **'Staff Schedule'**
  String get staffSchedule;

  /// No description provided for @customOrders.
  ///
  /// In en, this message translates to:
  /// **'Custom Orders'**
  String get customOrders;

  /// No description provided for @servicesCatalog.
  ///
  /// In en, this message translates to:
  /// **'Services Catalog'**
  String get servicesCatalog;

  /// No description provided for @addService.
  ///
  /// In en, this message translates to:
  /// **'Add Service'**
  String get addService;

  /// No description provided for @editService.
  ///
  /// In en, this message translates to:
  /// **'Edit Service'**
  String get editService;

  /// No description provided for @searchServicesHint.
  ///
  /// In en, this message translates to:
  /// **'Search services...'**
  String get searchServicesHint;

  /// No description provided for @noServicesFound.
  ///
  /// In en, this message translates to:
  /// **'No services found'**
  String get noServicesFound;

  /// No description provided for @noMatchingServices.
  ///
  /// In en, this message translates to:
  /// **'No matching services'**
  String get noMatchingServices;

  /// No description provided for @serviceName.
  ///
  /// In en, this message translates to:
  /// **'Service Name'**
  String get serviceName;

  /// No description provided for @durationMinutes.
  ///
  /// In en, this message translates to:
  /// **'Duration (Minutes)'**
  String get durationMinutes;

  /// No description provided for @requiresBooking.
  ///
  /// In en, this message translates to:
  /// **'Requires Booking'**
  String get requiresBooking;

  /// No description provided for @requiresBookingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Can be booked via Appointments'**
  String get requiresBookingSubtitle;

  /// No description provided for @bookable.
  ///
  /// In en, this message translates to:
  /// **'Bookable'**
  String get bookable;

  /// No description provided for @serviceUpdated.
  ///
  /// In en, this message translates to:
  /// **'Service updated successfully'**
  String get serviceUpdated;

  /// No description provided for @serviceAdded.
  ///
  /// In en, this message translates to:
  /// **'Service added successfully'**
  String get serviceAdded;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @bookAppointment.
  ///
  /// In en, this message translates to:
  /// **'Book Appointment'**
  String get bookAppointment;

  /// No description provided for @confirmBooking.
  ///
  /// In en, this message translates to:
  /// **'CONFIRM BOOKING'**
  String get confirmBooking;

  /// No description provided for @continueText.
  ///
  /// In en, this message translates to:
  /// **'CONTINUE'**
  String get continueText;

  /// No description provided for @backText.
  ///
  /// In en, this message translates to:
  /// **'BACK'**
  String get backText;

  /// No description provided for @customerDetails.
  ///
  /// In en, this message translates to:
  /// **'Customer Details'**
  String get customerDetails;

  /// No description provided for @selectService.
  ///
  /// In en, this message translates to:
  /// **'Select Service'**
  String get selectService;

  /// No description provided for @selectStaff.
  ///
  /// In en, this message translates to:
  /// **'Select Staff'**
  String get selectStaff;

  /// No description provided for @selectTimeSlot.
  ///
  /// In en, this message translates to:
  /// **'Select Time Slot'**
  String get selectTimeSlot;

  /// No description provided for @changeDate.
  ///
  /// In en, this message translates to:
  /// **'Change Date'**
  String get changeDate;

  /// No description provided for @noAvailableSlots.
  ///
  /// In en, this message translates to:
  /// **'No available slots for this date.'**
  String get noAvailableSlots;

  /// No description provided for @selectValidCustomer.
  ///
  /// In en, this message translates to:
  /// **'Please select a valid customer.'**
  String get selectValidCustomer;

  /// No description provided for @pleaseEnterCustomerName.
  ///
  /// In en, this message translates to:
  /// **'Please enter customer name'**
  String get pleaseEnterCustomerName;

  /// No description provided for @pleaseSelectService.
  ///
  /// In en, this message translates to:
  /// **'Please select a service'**
  String get pleaseSelectService;

  /// No description provided for @pleaseSelectStaff.
  ///
  /// In en, this message translates to:
  /// **'Please select a staff member'**
  String get pleaseSelectStaff;

  /// No description provided for @pleaseSelectTimeSlot.
  ///
  /// In en, this message translates to:
  /// **'Please select a time slot'**
  String get pleaseSelectTimeSlot;

  /// No description provided for @appointmentBooked.
  ///
  /// In en, this message translates to:
  /// **'Appointment booked successfully!'**
  String get appointmentBooked;

  /// No description provided for @failedToBookAppointment.
  ///
  /// In en, this message translates to:
  /// **'Failed to book appointment: {error}'**
  String failedToBookAppointment(Object error);

  /// No description provided for @noAppointmentsDay.
  ///
  /// In en, this message translates to:
  /// **'No appointments for this day.'**
  String get noAppointmentsDay;

  /// No description provided for @appointmentDetails.
  ///
  /// In en, this message translates to:
  /// **'Appointment Details'**
  String get appointmentDetails;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @noEmployeesFound.
  ///
  /// In en, this message translates to:
  /// **'No employees found.'**
  String get noEmployeesFound;

  /// No description provided for @noScheduleFound.
  ///
  /// In en, this message translates to:
  /// **'No schedule found.'**
  String get noScheduleFound;

  /// No description provided for @selectStaffMember.
  ///
  /// In en, this message translates to:
  /// **'Select Staff Member'**
  String get selectStaffMember;

  /// No description provided for @noOrdersStatus.
  ///
  /// In en, this message translates to:
  /// **'No orders {status}'**
  String noOrdersStatus(Object status);

  /// No description provided for @placed.
  ///
  /// In en, this message translates to:
  /// **'Placed'**
  String get placed;

  /// No description provided for @inProgressStatus.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get inProgressStatus;

  /// No description provided for @readyStatus.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get readyStatus;

  /// No description provided for @deliveredStatus.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get deliveredStatus;

  /// No description provided for @dueDate.
  ///
  /// In en, this message translates to:
  /// **'Due Date'**
  String get dueDate;

  /// No description provided for @depositPaid.
  ///
  /// In en, this message translates to:
  /// **'Deposit Paid'**
  String get depositPaid;

  /// No description provided for @depositAmount.
  ///
  /// In en, this message translates to:
  /// **'Deposit Amount'**
  String get depositAmount;

  /// No description provided for @balanceDue.
  ///
  /// In en, this message translates to:
  /// **'Balance Due'**
  String get balanceDue;

  /// No description provided for @notesMeasurements.
  ///
  /// In en, this message translates to:
  /// **'Measurements / Notes'**
  String get notesMeasurements;

  /// No description provided for @orderItems.
  ///
  /// In en, this message translates to:
  /// **'Order Items'**
  String get orderItems;

  /// No description provided for @noItemsAdded.
  ///
  /// In en, this message translates to:
  /// **'No items added.'**
  String get noItemsAdded;

  /// No description provided for @addItem.
  ///
  /// In en, this message translates to:
  /// **'Add Item'**
  String get addItem;

  /// No description provided for @unitPrice.
  ///
  /// In en, this message translates to:
  /// **'Unit Price'**
  String get unitPrice;

  /// No description provided for @quantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantity;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @selectDate.
  ///
  /// In en, this message translates to:
  /// **'Select Date'**
  String get selectDate;

  /// No description provided for @placeCustomOrder.
  ///
  /// In en, this message translates to:
  /// **'Place Custom Order'**
  String get placeCustomOrder;

  /// No description provided for @pleaseFillRequired.
  ///
  /// In en, this message translates to:
  /// **'Please fill all required fields and add at least one item.'**
  String get pleaseFillRequired;

  /// No description provided for @markInProgress.
  ///
  /// In en, this message translates to:
  /// **'Mark as In Progress'**
  String get markInProgress;

  /// No description provided for @markReady.
  ///
  /// In en, this message translates to:
  /// **'Mark as Ready for Pickup'**
  String get markReady;

  /// No description provided for @orderNumber.
  ///
  /// In en, this message translates to:
  /// **'Order #{id}'**
  String orderNumber(Object id);

  /// No description provided for @basicInformation.
  ///
  /// In en, this message translates to:
  /// **'Basic Information'**
  String get basicInformation;

  /// No description provided for @serviceNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Haircut'**
  String get serviceNameHint;

  /// No description provided for @invalidAmount.
  ///
  /// In en, this message translates to:
  /// **'Invalid amount'**
  String get invalidAmount;

  /// No description provided for @mustBeWholeNumber.
  ///
  /// In en, this message translates to:
  /// **'Must be a whole number'**
  String get mustBeWholeNumber;

  /// No description provided for @schedulePayment.
  ///
  /// In en, this message translates to:
  /// **'Schedule & Payment'**
  String get schedulePayment;

  /// No description provided for @customTime.
  ///
  /// In en, this message translates to:
  /// **'Selected Time'**
  String get customTime;

  /// No description provided for @selectCustomTime.
  ///
  /// In en, this message translates to:
  /// **'Select Custom Time'**
  String get selectCustomTime;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
        'bn',
        'dv',
        'en',
        'hi',
        'si',
        'ta'
      ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'bn':
      return AppLocalizationsBn();
    case 'dv':
      return AppLocalizationsDv();
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
    case 'si':
      return AppLocalizationsSi();
    case 'ta':
      return AppLocalizationsTa();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
