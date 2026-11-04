import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

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
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @medicalStudent.
  ///
  /// In en, this message translates to:
  /// **'Medical Student'**
  String get medicalStudent;

  /// No description provided for @intern.
  ///
  /// In en, this message translates to:
  /// **'Intern'**
  String get intern;

  /// No description provided for @juniorResident.
  ///
  /// In en, this message translates to:
  /// **'Junior Resident'**
  String get juniorResident;

  /// No description provided for @seniorResident.
  ///
  /// In en, this message translates to:
  /// **'Senior Resident'**
  String get seniorResident;

  /// No description provided for @fellow.
  ///
  /// In en, this message translates to:
  /// **'Fellow'**
  String get fellow;

  /// No description provided for @consultant.
  ///
  /// In en, this message translates to:
  /// **'Consultant'**
  String get consultant;

  /// No description provided for @homePage_title.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homePage_title;

  /// No description provided for @registerPage_header.
  ///
  /// In en, this message translates to:
  /// **'Start your learning journey today!'**
  String get registerPage_header;

  /// No description provided for @basicText_name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get basicText_name;

  /// No description provided for @basicText_surname.
  ///
  /// In en, this message translates to:
  /// **'Surname'**
  String get basicText_surname;

  /// No description provided for @basicText_email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get basicText_email;

  /// No description provided for @basicText_phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get basicText_phoneNumber;

  /// No description provided for @basicText_educationLevel.
  ///
  /// In en, this message translates to:
  /// **'Education Level'**
  String get basicText_educationLevel;

  /// No description provided for @basicText_password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get basicText_password;

  /// No description provided for @basicText_repeatPassword.
  ///
  /// In en, this message translates to:
  /// **'Repeat password'**
  String get basicText_repeatPassword;

  /// No description provided for @basicText_register.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get basicText_register;

  /// No description provided for @basicText_alreadyAMember.
  ///
  /// In en, this message translates to:
  /// **'Already a member?'**
  String get basicText_alreadyAMember;

  /// No description provided for @basicText_signInNow.
  ///
  /// In en, this message translates to:
  /// **'Sign In Now'**
  String get basicText_signInNow;

  /// No description provided for @basicText_forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password'**
  String get basicText_forgotPassword;

  /// No description provided for @basicText_notAMember.
  ///
  /// In en, this message translates to:
  /// **'Not a Member?'**
  String get basicText_notAMember;

  /// No description provided for @basicText_sendEmail.
  ///
  /// In en, this message translates to:
  /// **'Send Email'**
  String get basicText_sendEmail;

  /// No description provided for @basicText_update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get basicText_update;

  /// No description provided for @basicText_tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get basicText_tryAgain;

  /// No description provided for @basicText_profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get basicText_profile;

  /// No description provided for @basicText_edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get basicText_edit;

  /// No description provided for @basicText_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get basicText_cancel;

  /// No description provided for @basicText_save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get basicText_save;

  /// No description provided for @basicText_other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get basicText_other;

  /// No description provided for @basicText_logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get basicText_logout;

  /// No description provided for @basicText_signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get basicText_signOut;

  /// No description provided for @basicText_goToLogin.
  ///
  /// In en, this message translates to:
  /// **'Go to Login'**
  String get basicText_goToLogin;

  /// No description provided for @registerPage_successfulRegister.
  ///
  /// In en, this message translates to:
  /// **'Congrats {displayName} you\'ve successfully registered!'**
  String registerPage_successfulRegister(String displayName);

  /// No description provided for @loginPage_welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back to FlashPedz, we\'ve missed you'**
  String get loginPage_welcomeBack;

  /// No description provided for @loginPage_welcomeBackMember.
  ///
  /// In en, this message translates to:
  /// **'Welcome back {displayName}!'**
  String loginPage_welcomeBackMember(String displayName);

  /// No description provided for @forgotPasswordPage_emailSent.
  ///
  /// In en, this message translates to:
  /// **'Verification email sent. Please check your inbox'**
  String get forgotPasswordPage_emailSent;

  /// No description provided for @forgotPasswordPage_enterEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter the email address associated with your account.'**
  String get forgotPasswordPage_enterEmail;

  /// No description provided for @verifyEmailPage_success.
  ///
  /// In en, this message translates to:
  /// **'Successfully sent email verification!'**
  String get verifyEmailPage_success;

  /// No description provided for @personalInformationPage_personalInformation.
  ///
  /// In en, this message translates to:
  /// **'Personal Information'**
  String get personalInformationPage_personalInformation;

  /// No description provided for @privacySecurityPage_title.
  ///
  /// In en, this message translates to:
  /// **'Privacy & Security'**
  String get privacySecurityPage_title;

  /// No description provided for @privacySecurityPage_changeEmail.
  ///
  /// In en, this message translates to:
  /// **'Change Email'**
  String get privacySecurityPage_changeEmail;

  /// No description provided for @privacySecurityPage_verified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get privacySecurityPage_verified;

  /// No description provided for @privacySecurityPage_changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get privacySecurityPage_changePassword;

  /// No description provided for @privacySecurityPage_hiddenPassword.
  ///
  /// In en, this message translates to:
  /// **'••••••••'**
  String get privacySecurityPage_hiddenPassword;

  /// No description provided for @privacySecurityPage_changePhone.
  ///
  /// In en, this message translates to:
  /// **'Change Phone Number'**
  String get privacySecurityPage_changePhone;

  /// No description provided for @privacySecurityPage_notVerified.
  ///
  /// In en, this message translates to:
  /// **'Not Verified'**
  String get privacySecurityPage_notVerified;

  /// No description provided for @privacySecurityPage_deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete your account'**
  String get privacySecurityPage_deleteAccount;

  /// No description provided for @privacySecurityPage_deleteAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Permanently remove your account'**
  String get privacySecurityPage_deleteAccountSubtitle;

  /// No description provided for @privacySecurityPage_pendingVerification.
  ///
  /// In en, this message translates to:
  /// **'Pending verification'**
  String get privacySecurityPage_pendingVerification;

  /// No description provided for @privacySecurityPage_changeEmailText.
  ///
  /// In en, this message translates to:
  /// **'To change your email, complete the process on the Change Email page. Verifying it elsewhere may cause issues. If you’ve changed your mind, you can safely ignore this.'**
  String get privacySecurityPage_changeEmailText;

  /// No description provided for @profilePage_errorMessage.
  ///
  /// In en, this message translates to:
  /// **'{errorMessage}'**
  String profilePage_errorMessage(String errorMessage);

  /// No description provided for @deleteAccountSuccessfulPage_message.
  ///
  /// In en, this message translates to:
  /// **'We\'re sad to see you go. Your account and all associated data have been successfully deleted.'**
  String get deleteAccountSuccessfulPage_message;

  /// No description provided for @deleteAccountSuccessfulPage_button.
  ///
  /// In en, this message translates to:
  /// **'Go to Login'**
  String get deleteAccountSuccessfulPage_button;

  /// No description provided for @authErrorContainer_verifyEmailSuccess.
  ///
  /// In en, this message translates to:
  /// **'Success! Now lets verify your email address'**
  String get authErrorContainer_verifyEmailSuccess;

  /// No description provided for @reauthSection_securityNotice.
  ///
  /// In en, this message translates to:
  /// **'For security reasons, please verify your identity.'**
  String get reauthSection_securityNotice;

  /// No description provided for @reauthSection_passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get reauthSection_passwordLabel;

  /// No description provided for @reauthSection_button.
  ///
  /// In en, this message translates to:
  /// **'Reauthenticate'**
  String get reauthSection_button;

  /// No description provided for @reauthSection_success.
  ///
  /// In en, this message translates to:
  /// **'Reauthentication successful. Your previous action will now be completed.'**
  String get reauthSection_success;

  /// No description provided for @reauthSection_info.
  ///
  /// In en, this message translates to:
  /// **'You may be asked to verify your identity.'**
  String get reauthSection_info;

  /// No description provided for @loadingProfileData_message.
  ///
  /// In en, this message translates to:
  /// **'Loading your profile...'**
  String get loadingProfileData_message;

  /// No description provided for @profileReaderBlocBuilder_neverLoaded.
  ///
  /// In en, this message translates to:
  /// **'Profile was never loaded.'**
  String get profileReaderBlocBuilder_neverLoaded;

  /// No description provided for @readProfileErrorScreen_errorMessage.
  ///
  /// In en, this message translates to:
  /// **'There was an error trying to load your profile.'**
  String get readProfileErrorScreen_errorMessage;

  /// No description provided for @personalInfoContent_updateSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Successfully updated your personal information!'**
  String get personalInfoContent_updateSuccessMessage;

  /// No description provided for @profileData_accountSettings.
  ///
  /// In en, this message translates to:
  /// **'Account Settings'**
  String get profileData_accountSettings;

  /// No description provided for @profileData_personalInformation.
  ///
  /// In en, this message translates to:
  /// **'Personal Information'**
  String get profileData_personalInformation;

  /// No description provided for @profileData_privacySecurity.
  ///
  /// In en, this message translates to:
  /// **'Privacy & Security'**
  String get profileData_privacySecurity;

  /// No description provided for @profileData_billingDetails.
  ///
  /// In en, this message translates to:
  /// **'Billing Details'**
  String get profileData_billingDetails;

  /// No description provided for @profileData_flashcards.
  ///
  /// In en, this message translates to:
  /// **'Flashcards'**
  String get profileData_flashcards;

  /// No description provided for @profileData_flashcardSettings.
  ///
  /// In en, this message translates to:
  /// **'Flashcard Settings'**
  String get profileData_flashcardSettings;

  /// No description provided for @profileData_bookmarkedFlashcards.
  ///
  /// In en, this message translates to:
  /// **'Bookmarked flashcards'**
  String get profileData_bookmarkedFlashcards;

  /// No description provided for @profileData_privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get profileData_privacyPolicy;

  /// No description provided for @verifyEmailActionButtons_changeEmail.
  ///
  /// In en, this message translates to:
  /// **'Change Email'**
  String get verifyEmailActionButtons_changeEmail;

  /// No description provided for @verifyEmailHeadline_sendingVerificationLink.
  ///
  /// In en, this message translates to:
  /// **'Sending verification link...'**
  String get verifyEmailHeadline_sendingVerificationLink;

  /// No description provided for @verifyEmailHeadline_refreshingApplicationState.
  ///
  /// In en, this message translates to:
  /// **'Refreshing application state...'**
  String get verifyEmailHeadline_refreshingApplicationState;

  /// No description provided for @verifyEmailHeadline_errorSendingVerificationLink.
  ///
  /// In en, this message translates to:
  /// **'Error sending verification link, please try again later'**
  String get verifyEmailHeadline_errorSendingVerificationLink;

  /// No description provided for @verifyEmailHeadline_verifyYourEmailAddress.
  ///
  /// In en, this message translates to:
  /// **'Verify your email address'**
  String get verifyEmailHeadline_verifyYourEmailAddress;

  /// No description provided for @verifyEmailInfoSection_emailSentMessage1.
  ///
  /// In en, this message translates to:
  /// **'Thank you for registering! A verification email has been sent to your inbox.'**
  String get verifyEmailInfoSection_emailSentMessage1;

  /// No description provided for @verifyEmailInfoSection_emailSentMessage2.
  ///
  /// In en, this message translates to:
  /// **'Please check your email and click on the verification link to activate your account.'**
  String get verifyEmailInfoSection_emailSentMessage2;

  /// No description provided for @verifyEmailInfoSection_twoEmailsDetectedMessage.
  ///
  /// In en, this message translates to:
  /// **'We\'ve sent verification links to both email addresses. \n The first link you click will determine which email is saved to your profile.'**
  String get verifyEmailInfoSection_twoEmailsDetectedMessage;

  /// No description provided for @verifyEmailResendLinkButton_successMessage.
  ///
  /// In en, this message translates to:
  /// **'Successfully sent email verification!'**
  String get verifyEmailResendLinkButton_successMessage;

  /// No description provided for @verifyEmailResendLinkButton_resendLinkButtonText.
  ///
  /// In en, this message translates to:
  /// **'Resend Link'**
  String get verifyEmailResendLinkButton_resendLinkButtonText;

  /// No description provided for @verifyEmailResendLinkButton_waitButtonText.
  ///
  /// In en, this message translates to:
  /// **'Wait...'**
  String get verifyEmailResendLinkButton_waitButtonText;

  /// No description provided for @error_requiresRecentLogin.
  ///
  /// In en, this message translates to:
  /// **'For security reasons, please reauthenticate to perform this action.'**
  String get error_requiresRecentLogin;

  /// No description provided for @error_invalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Invalid email format.'**
  String get error_invalidEmail;

  /// No description provided for @error_userDisabled.
  ///
  /// In en, this message translates to:
  /// **'User with that email is disabled.'**
  String get error_userDisabled;

  /// No description provided for @error_userNotFound.
  ///
  /// In en, this message translates to:
  /// **'No account found with that email.'**
  String get error_userNotFound;

  /// No description provided for @error_wrongPassword.
  ///
  /// In en, this message translates to:
  /// **'Incorrect password. Try again.'**
  String get error_wrongPassword;

  /// No description provided for @error_tooManyRequests.
  ///
  /// In en, this message translates to:
  /// **'You\'ve send too many requests, try again later'**
  String get error_tooManyRequests;

  /// No description provided for @error_tokenExpired.
  ///
  /// In en, this message translates to:
  /// **'Session expired, please log in again.'**
  String get error_tokenExpired;

  /// No description provided for @error_networkIssue.
  ///
  /// In en, this message translates to:
  /// **'There is a problem with the network, please check your internet connection'**
  String get error_networkIssue;

  /// No description provided for @error_invalidCredential.
  ///
  /// In en, this message translates to:
  /// **'Invalid credentials, please try again'**
  String get error_invalidCredential;

  /// No description provided for @error_operationNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'There is a problem with firebase auth, please contact the developer'**
  String get error_operationNotAllowed;

  /// No description provided for @error_emailAlreadyInUse.
  ///
  /// In en, this message translates to:
  /// **'That email is already in use, try another one.'**
  String get error_emailAlreadyInUse;

  /// No description provided for @error_authFailed.
  ///
  /// In en, this message translates to:
  /// **'Authentication failed. Please try again.'**
  String get error_authFailed;

  /// No description provided for @error_unexpected.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred. Please try again.'**
  String get error_unexpected;

  /// No description provided for @error_passwordRequirement.
  ///
  /// In en, this message translates to:
  /// **'Password does not meet security requirements.'**
  String get error_passwordRequirement;

  /// No description provided for @error_passwordNonAlphanumeric.
  ///
  /// In en, this message translates to:
  /// **'Password must contain a non-alphanumeric character.'**
  String get error_passwordNonAlphanumeric;

  /// No description provided for @error_passwordEightCharacters.
  ///
  /// In en, this message translates to:
  /// **'Password must contain at least 8 characters.'**
  String get error_passwordEightCharacters;

  /// No description provided for @error_passwordUpperCase.
  ///
  /// In en, this message translates to:
  /// **'Password must contain an upper case character.'**
  String get error_passwordUpperCase;

  /// No description provided for @error_passwordNumeric.
  ///
  /// In en, this message translates to:
  /// **'Password must contain a numeric character.'**
  String get error_passwordNumeric;

  /// No description provided for @error_loadingBookmarks.
  ///
  /// In en, this message translates to:
  /// **'Error loading bookmarks, try again'**
  String get error_loadingBookmarks;

  /// No description provided for @error_loadingOscePacks.
  ///
  /// In en, this message translates to:
  /// **'Error trying to load the OSCE packs 😔'**
  String get error_loadingOscePacks;

  /// No description provided for @error_loadingOsceResults.
  ///
  /// In en, this message translates to:
  /// **'Error trying to load the results 😔'**
  String get error_loadingOsceResults;

  /// No description provided for @error_loadingPacks.
  ///
  /// In en, this message translates to:
  /// **'Error trying to load the packs 😔'**
  String get error_loadingPacks;

  /// No description provided for @flashcardMainCard_packFinished.
  ///
  /// In en, this message translates to:
  /// **'Good job!'**
  String get flashcardMainCard_packFinished;

  /// No description provided for @flashcardMainButton_reveal.
  ///
  /// In en, this message translates to:
  /// **'Reveal'**
  String get flashcardMainButton_reveal;

  /// No description provided for @flashcardMainButton_skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get flashcardMainButton_skip;

  /// No description provided for @flashcardPageDialog_packFinishedForNow.
  ///
  /// In en, this message translates to:
  /// **'You are finished, for now'**
  String get flashcardPageDialog_packFinishedForNow;

  /// No description provided for @flashcardPageDialog_packEnded.
  ///
  /// In en, this message translates to:
  /// **'Congratulations! There are no flashcards from {subTextForDialog} that are due now, but you can come back later.\n\nKeep up the good work.'**
  String flashcardPageDialog_packEnded(String subTextForDialog);

  /// No description provided for @flashcardPageDialog_backHome.
  ///
  /// In en, this message translates to:
  /// **'Back to home page'**
  String get flashcardPageDialog_backHome;

  /// No description provided for @flashcardPageDialog_sessionFinishedForNow.
  ///
  /// In en, this message translates to:
  /// **'This study session is finished, for now'**
  String get flashcardPageDialog_sessionFinishedForNow;

  /// No description provided for @flashcardPageDialog_sessionEnded.
  ///
  /// In en, this message translates to:
  /// **'Congratulations! You completed this study session.'**
  String get flashcardPageDialog_sessionEnded;

  /// No description provided for @flashcardPageDialog_closeSession.
  ///
  /// In en, this message translates to:
  /// **'You can close this session, or you can continue learning.'**
  String get flashcardPageDialog_closeSession;

  /// No description provided for @flashcardPageDialog_continueLearning.
  ///
  /// In en, this message translates to:
  /// **'Continue learning'**
  String get flashcardPageDialog_continueLearning;

  /// No description provided for @flashcardPageDialog_endThisSession.
  ///
  /// In en, this message translates to:
  /// **'End this session?'**
  String get flashcardPageDialog_endThisSession;

  /// No description provided for @flashcardPageDialog_updateCardsPerSession.
  ///
  /// In en, this message translates to:
  /// **'You’ve reviewed {cardDifference} more cards than your target of {userCardsPerSession} cards per session.\n\nWould you like to update your session target to {newCardsPerSession} cards per session?\n\nYou can always change this in settings.'**
  String flashcardPageDialog_updateCardsPerSession(
    int cardDifference,
    int userCardsPerSession,
    int newCardsPerSession,
  );

  /// No description provided for @flashcardPageDialog_keepCurrent.
  ///
  /// In en, this message translates to:
  /// **'Keep current'**
  String get flashcardPageDialog_keepCurrent;

  /// No description provided for @flashcardPageDialog_updateTarget.
  ///
  /// In en, this message translates to:
  /// **'Update target'**
  String get flashcardPageDialog_updateTarget;

  /// No description provided for @flashcardRatingButtons_easyLabel.
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get flashcardRatingButtons_easyLabel;

  /// No description provided for @flashcardRatingButtons_easyTooltip.
  ///
  /// In en, this message translates to:
  /// **'I knew it instantly and confidently.'**
  String get flashcardRatingButtons_easyTooltip;

  /// No description provided for @flashcardRatingButtons_goodLabel.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get flashcardRatingButtons_goodLabel;

  /// No description provided for @flashcardRatingButtons_goodTooltip.
  ///
  /// In en, this message translates to:
  /// **'I remembered it, but I had to think for a moment.'**
  String get flashcardRatingButtons_goodTooltip;

  /// No description provided for @flashcardRatingButtons_hardLabel.
  ///
  /// In en, this message translates to:
  /// **'Hard'**
  String get flashcardRatingButtons_hardLabel;

  /// No description provided for @flashcardRatingButtons_hardTooltip.
  ///
  /// In en, this message translates to:
  /// **'I barely remembered this.'**
  String get flashcardRatingButtons_hardTooltip;

  /// No description provided for @flashcardRatingButtons_againLabel.
  ///
  /// In en, this message translates to:
  /// **'Again'**
  String get flashcardRatingButtons_againLabel;

  /// No description provided for @flashcardRatingButtons_againTooltip.
  ///
  /// In en, this message translates to:
  /// **'I forgot this or got it wrong.'**
  String get flashcardRatingButtons_againTooltip;

  /// No description provided for @flashcardTimerContainer.
  ///
  /// In en, this message translates to:
  /// **'Time: {time}'**
  String flashcardTimerContainer(String time);

  /// No description provided for @flashcardPage_packTitle.
  ///
  /// In en, this message translates to:
  /// **'Pack'**
  String get flashcardPage_packTitle;

  /// No description provided for @flashcardPage_packSubtext.
  ///
  /// In en, this message translates to:
  /// **'pack'**
  String get flashcardPage_packSubtext;

  /// No description provided for @flashcardPage_bookmarksTitle.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks'**
  String get flashcardPage_bookmarksTitle;

  /// No description provided for @flashcardPage_bookmarksSubtext.
  ///
  /// In en, this message translates to:
  /// **'bookmarks'**
  String get flashcardPage_bookmarksSubtext;

  /// No description provided for @reviewBookmarkPage_review.
  ///
  /// In en, this message translates to:
  /// **'Review Bookmarked Flashcards'**
  String get reviewBookmarkPage_review;

  /// No description provided for @reviewBookmarkPage_noBookmarks.
  ///
  /// In en, this message translates to:
  /// **'Looks like you didn\'t bookmark any flashcards yet.'**
  String get reviewBookmarkPage_noBookmarks;

  /// No description provided for @reviewBookmarkPage_numberOfBookmarks.
  ///
  /// In en, this message translates to:
  /// **'Number of bookmarks: {number}'**
  String reviewBookmarkPage_numberOfBookmarks(int number);

  /// No description provided for @reviewBookmarkPage_remove.
  ///
  /// In en, this message translates to:
  /// **'Remove bookmark'**
  String get reviewBookmarkPage_remove;

  /// No description provided for @reviewBookmarkPage_swipe.
  ///
  /// In en, this message translates to:
  /// **'Tap ⋮ on a card to remove its bookmark or add it to a set'**
  String get reviewBookmarkPage_swipe;

  /// No description provided for @osceListPage_title.
  ///
  /// In en, this message translates to:
  /// **'OSCEs'**
  String get osceListPage_title;

  /// No description provided for @osceListPage_fetching.
  ///
  /// In en, this message translates to:
  /// **'Fetching OSCE scenarios...'**
  String get osceListPage_fetching;

  /// No description provided for @osceListPage_noPacks.
  ///
  /// In en, this message translates to:
  /// **'Whoops, looks like there are no OSCE packs available'**
  String get osceListPage_noPacks;

  /// No description provided for @oscePage_title.
  ///
  /// In en, this message translates to:
  /// **'OSCE'**
  String get oscePage_title;

  /// No description provided for @oscePage_previous.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get oscePage_previous;

  /// No description provided for @oscePage_next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get oscePage_next;

  /// No description provided for @oscePage_submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get oscePage_submit;

  /// No description provided for @osceResultPage_title.
  ///
  /// In en, this message translates to:
  /// **'OSCE results'**
  String get osceResultPage_title;

  /// No description provided for @osceResultPage_fetching.
  ///
  /// In en, this message translates to:
  /// **'Fetching OSCE results...'**
  String get osceResultPage_fetching;

  /// No description provided for @osceSubmitPage_title.
  ///
  /// In en, this message translates to:
  /// **'OSCE Result'**
  String get osceSubmitPage_title;

  /// No description provided for @osceSubmitPage_success.
  ///
  /// In en, this message translates to:
  /// **'You successfully completed the OSCE!'**
  String get osceSubmitPage_success;

  /// No description provided for @osceSubmitPage_osceName.
  ///
  /// In en, this message translates to:
  /// **'OSCE Name: {name}'**
  String osceSubmitPage_osceName(String name);

  /// No description provided for @osceSubmitPage_unmarked.
  ///
  /// In en, this message translates to:
  /// **'Unmarked checks:'**
  String get osceSubmitPage_unmarked;

  /// No description provided for @osceSubmitPage_download.
  ///
  /// In en, this message translates to:
  /// **'Download PDF'**
  String get osceSubmitPage_download;

  /// No description provided for @osceSubmitPage_back.
  ///
  /// In en, this message translates to:
  /// **'Back to main menu'**
  String get osceSubmitPage_back;

  /// No description provided for @splashPageText.
  ///
  /// In en, this message translates to:
  /// **'Preparing your experience...'**
  String get splashPageText;

  /// No description provided for @packsPage_title.
  ///
  /// In en, this message translates to:
  /// **'Packs'**
  String get packsPage_title;

  /// No description provided for @packsPage_fetching.
  ///
  /// In en, this message translates to:
  /// **'Fetching flashcard packs...'**
  String get packsPage_fetching;

  /// No description provided for @packsPage_noPacks.
  ///
  /// In en, this message translates to:
  /// **'Whoops, looks like there are no packs available'**
  String get packsPage_noPacks;

  /// No description provided for @updateEmailSuccessfulPage_text.
  ///
  /// In en, this message translates to:
  /// **'🎉 All set! Your email address has been updated.\\nMake sure to use the new one next time you sign in.'**
  String get updateEmailSuccessfulPage_text;

  /// No description provided for @updateEmailSuccessfulPage_button.
  ///
  /// In en, this message translates to:
  /// **'Go to login'**
  String get updateEmailSuccessfulPage_button;

  /// No description provided for @changeEmailDuringVerificationPage_text.
  ///
  /// In en, this message translates to:
  /// **'Successfully sent new email verification at {email}'**
  String changeEmailDuringVerificationPage_text(String email);

  /// No description provided for @changeEmailPage_leaveWithoutVerifying.
  ///
  /// In en, this message translates to:
  /// **'Leave without verifying email?'**
  String get changeEmailPage_leaveWithoutVerifying;

  /// No description provided for @changeEmailPage_text.
  ///
  /// In en, this message translates to:
  /// **'To change your email, you must complete the verification while staying on this page.\\n\\nVerifying your email from another page may cause the app to behave unexpectedly.\\n\\nIf you’ve changed your mind, you can safely leave this page.'**
  String get changeEmailPage_text;

  /// No description provided for @changeEmailPage_stay.
  ///
  /// In en, this message translates to:
  /// **'Stay on this page'**
  String get changeEmailPage_stay;

  /// No description provided for @changeEmailPage_leaveAnyway.
  ///
  /// In en, this message translates to:
  /// **'Leave anyway'**
  String get changeEmailPage_leaveAnyway;

  /// No description provided for @deleteProfilePage_deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteProfilePage_deleteAccount;

  /// No description provided for @deleteProfilePage_areYouSure.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to permanently delete your account? \n\n This action cannot be undone and all your data will be lost.'**
  String get deleteProfilePage_areYouSure;

  /// No description provided for @updatePasswordPage_title.
  ///
  /// In en, this message translates to:
  /// **'Update Password'**
  String get updatePasswordPage_title;

  /// No description provided for @updatePasswordPage_update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get updatePasswordPage_update;

  /// No description provided for @updatePasswordPage_success.
  ///
  /// In en, this message translates to:
  /// **'Successfully updated password'**
  String get updatePasswordPage_success;

  /// No description provided for @updatePasswordPage_password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get updatePasswordPage_password;

  /// No description provided for @updatePasswordPage_repeatPassword.
  ///
  /// In en, this message translates to:
  /// **'Repeat password'**
  String get updatePasswordPage_repeatPassword;

  /// No description provided for @profileData_bookmarks.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks'**
  String get profileData_bookmarks;

  /// No description provided for @profileData_chooseEngage.
  ///
  /// In en, this message translates to:
  /// **'Choose how you\'d like to engage with your bookmarked cards.'**
  String get profileData_chooseEngage;

  /// No description provided for @profileData_review.
  ///
  /// In en, this message translates to:
  /// **'Review flashcards'**
  String get profileData_review;

  /// No description provided for @profileData_startTest.
  ///
  /// In en, this message translates to:
  /// **'Test yourself'**
  String get profileData_startTest;

  /// No description provided for @profileData_osces.
  ///
  /// In en, this message translates to:
  /// **'OSCES'**
  String get profileData_osces;

  /// No description provided for @profileData_osceResults.
  ///
  /// In en, this message translates to:
  /// **'OSCE Results'**
  String get profileData_osceResults;

  /// No description provided for @assignAdminPage_title.
  ///
  /// In en, this message translates to:
  /// **'Assign Admin Roles'**
  String get assignAdminPage_title;

  /// No description provided for @flashcardBuilderPage_title.
  ///
  /// In en, this message translates to:
  /// **'Flashcard Builder'**
  String get flashcardBuilderPage_title;

  /// No description provided for @osceBuilderPage_title.
  ///
  /// In en, this message translates to:
  /// **'OSCE Builder'**
  String get osceBuilderPage_title;

  /// No description provided for @reportFlashcardPage_success.
  ///
  /// In en, this message translates to:
  /// **'Flashcard reported successfully'**
  String get reportFlashcardPage_success;

  /// No description provided for @reportFlashcardPage_report.
  ///
  /// In en, this message translates to:
  /// **'Report Flashcard'**
  String get reportFlashcardPage_report;

  /// No description provided for @reportFlashcardPage_whyReporting.
  ///
  /// In en, this message translates to:
  /// **'Why are you reporting this flashcard'**
  String get reportFlashcardPage_whyReporting;

  /// No description provided for @reportFlashcardPage_submitReport.
  ///
  /// In en, this message translates to:
  /// **'Submit Report'**
  String get reportFlashcardPage_submitReport;

  /// No description provided for @reportFlashcardPage_additionalDetails.
  ///
  /// In en, this message translates to:
  /// **'Additional details (optional)'**
  String get reportFlashcardPage_additionalDetails;

  /// No description provided for @reportFlashcardPage_explain.
  ///
  /// In en, this message translates to:
  /// **'Explain your report here'**
  String get reportFlashcardPage_explain;

  /// No description provided for @reportReason_inappropriateContent.
  ///
  /// In en, this message translates to:
  /// **'Inappropriate content'**
  String get reportReason_inappropriateContent;

  /// No description provided for @reportReason_incorrectInformation.
  ///
  /// In en, this message translates to:
  /// **'Incorrect information'**
  String get reportReason_incorrectInformation;

  /// No description provided for @reportReason_poorTranslation.
  ///
  /// In en, this message translates to:
  /// **'Poor translation'**
  String get reportReason_poorTranslation;

  /// No description provided for @reportReason_duplicateFlashcard.
  ///
  /// In en, this message translates to:
  /// **'Duplicate flashcard'**
  String get reportReason_duplicateFlashcard;

  /// No description provided for @reportReason_other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get reportReason_other;
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
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
