// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get medicalStudent => 'Medical Student';

  @override
  String get intern => 'Intern';

  @override
  String get juniorResident => 'Junior Resident';

  @override
  String get seniorResident => 'Senior Resident';

  @override
  String get fellow => 'Fellow';

  @override
  String get consultant => 'Consultant';

  @override
  String get homePage_title => 'Home';

  @override
  String get registerPage_header => 'Start your learning journey today!';

  @override
  String get basicText_name => 'Name';

  @override
  String get basicText_surname => 'Surname';

  @override
  String get basicText_email => 'Email';

  @override
  String get basicText_phoneNumber => 'Phone Number';

  @override
  String get basicText_educationLevel => 'Education Level';

  @override
  String get basicText_password => 'Password';

  @override
  String get basicText_repeatPassword => 'Repeat password';

  @override
  String get basicText_register => 'Register';

  @override
  String get basicText_alreadyAMember => 'Already a member?';

  @override
  String get basicText_signInNow => 'Sign In Now';

  @override
  String get basicText_forgotPassword => 'Forgot password';

  @override
  String get basicText_notAMember => 'Not a Member?';

  @override
  String get basicText_sendEmail => 'Send Email';

  @override
  String get basicText_update => 'Update';

  @override
  String get basicText_tryAgain => 'Try again';

  @override
  String get basicText_profile => 'Profile';

  @override
  String get basicText_edit => 'Edit';

  @override
  String get basicText_cancel => 'Cancel';

  @override
  String get basicText_save => 'Save';

  @override
  String get basicText_other => 'Other';

  @override
  String get basicText_logout => 'Logout';

  @override
  String get basicText_signOut => 'Sign Out';

  @override
  String get basicText_goToLogin => 'Go to Login';

  @override
  String registerPage_successfulRegister(String displayName) {
    return 'Congrats $displayName you\'ve successfully registered!';
  }

  @override
  String get loginPage_welcomeBack =>
      'Welcome back to FlashPedz, we\'ve missed you';

  @override
  String loginPage_welcomeBackMember(String displayName) {
    return 'Welcome back $displayName!';
  }

  @override
  String get forgotPasswordPage_emailSent =>
      'Verification email sent. Please check your inbox';

  @override
  String get forgotPasswordPage_enterEmail =>
      'Please enter the email address associated with your account.';

  @override
  String get verifyEmailPage_success => 'Successfully sent email verification!';

  @override
  String get personalInformationPage_personalInformation =>
      'Personal Information';

  @override
  String get privacySecurityPage_title => 'Privacy & Security';

  @override
  String get privacySecurityPage_changeEmail => 'Change Email';

  @override
  String get privacySecurityPage_verified => 'Verified';

  @override
  String get privacySecurityPage_changePassword => 'Change Password';

  @override
  String get privacySecurityPage_hiddenPassword => '••••••••';

  @override
  String get privacySecurityPage_changePhone => 'Change Phone Number';

  @override
  String get privacySecurityPage_notVerified => 'Not Verified';

  @override
  String get privacySecurityPage_deleteAccount => 'Delete your account';

  @override
  String get privacySecurityPage_deleteAccountSubtitle =>
      'Permanently remove your account';

  @override
  String get privacySecurityPage_pendingVerification => 'Pending verification';

  @override
  String get privacySecurityPage_changeEmailText =>
      'To change your email, complete the process on the Change Email page. Verifying it elsewhere may cause issues. If you’ve changed your mind, you can safely ignore this.';

  @override
  String profilePage_errorMessage(String errorMessage) {
    return '$errorMessage';
  }

  @override
  String get deleteAccountSuccessfulPage_message =>
      'We\'re sad to see you go. Your account and all associated data have been successfully deleted.';

  @override
  String get deleteAccountSuccessfulPage_button => 'Go to Login';

  @override
  String get authErrorContainer_verifyEmailSuccess =>
      'Success! Now lets verify your email address';

  @override
  String get reauthSection_securityNotice =>
      'For security reasons, please verify your identity.';

  @override
  String get reauthSection_passwordLabel => 'Password';

  @override
  String get reauthSection_button => 'Reauthenticate';

  @override
  String get reauthSection_success =>
      'Reauthentication successful. Your previous action will now be completed.';

  @override
  String get reauthSection_info => 'You may be asked to verify your identity.';

  @override
  String get loadingProfileData_message => 'Loading your profile...';

  @override
  String get profileReaderBlocBuilder_neverLoaded =>
      'Profile was never loaded.';

  @override
  String get readProfileErrorScreen_errorMessage =>
      'There was an error trying to load your profile.';

  @override
  String get personalInfoContent_updateSuccessMessage =>
      'Successfully updated your personal information!';

  @override
  String get profileData_accountSettings => 'Account Settings';

  @override
  String get profileData_personalInformation => 'Personal Information';

  @override
  String get profileData_privacySecurity => 'Privacy & Security';

  @override
  String get profileData_billingDetails => 'Billing Details';

  @override
  String get profileData_flashcards => 'Flashcards';

  @override
  String get profileData_flashcardSettings => 'Flashcard Settings';

  @override
  String get profileData_bookmarkedFlashcards => 'Bookmarked flashcards';

  @override
  String get profileData_privacyPolicy => 'Privacy Policy';

  @override
  String get verifyEmailActionButtons_changeEmail => 'Change Email';

  @override
  String get verifyEmailHeadline_sendingVerificationLink =>
      'Sending verification link...';

  @override
  String get verifyEmailHeadline_refreshingApplicationState =>
      'Refreshing application state...';

  @override
  String get verifyEmailHeadline_errorSendingVerificationLink =>
      'Error sending verification link, please try again later';

  @override
  String get verifyEmailHeadline_verifyYourEmailAddress =>
      'Verify your email address';

  @override
  String get verifyEmailInfoSection_emailSentMessage1 =>
      'Thank you for registering! A verification email has been sent to your inbox.';

  @override
  String get verifyEmailInfoSection_emailSentMessage2 =>
      'Please check your email and click on the verification link to activate your account.';

  @override
  String get verifyEmailInfoSection_twoEmailsDetectedMessage =>
      'We\'ve sent verification links to both email addresses. \n The first link you click will determine which email is saved to your profile.';

  @override
  String get verifyEmailResendLinkButton_successMessage =>
      'Successfully sent email verification!';

  @override
  String get verifyEmailResendLinkButton_resendLinkButtonText => 'Resend Link';

  @override
  String get verifyEmailResendLinkButton_waitButtonText => 'Wait...';

  @override
  String get error_requiresRecentLogin =>
      'For security reasons, please reauthenticate to perform this action.';

  @override
  String get error_invalidEmail => 'Invalid email format.';

  @override
  String get error_userDisabled => 'User with that email is disabled.';

  @override
  String get error_userNotFound => 'No account found with that email.';

  @override
  String get error_wrongPassword => 'Incorrect password. Try again.';

  @override
  String get error_tooManyRequests =>
      'You\'ve send too many requests, try again later';

  @override
  String get error_tokenExpired => 'Session expired, please log in again.';

  @override
  String get error_networkIssue =>
      'There is a problem with the network, please check your internet connection';

  @override
  String get error_invalidCredential => 'Invalid credentials, please try again';

  @override
  String get error_operationNotAllowed =>
      'There is a problem with firebase auth, please contact the developer';

  @override
  String get error_emailAlreadyInUse =>
      'That email is already in use, try another one.';

  @override
  String get error_authFailed => 'Authentication failed. Please try again.';

  @override
  String get error_unexpected =>
      'An unexpected error occurred. Please try again.';

  @override
  String get error_passwordRequirement =>
      'Password does not meet security requirements.';

  @override
  String get error_passwordNonAlphanumeric =>
      'Password must contain a non-alphanumeric character.';

  @override
  String get error_passwordEightCharacters =>
      'Password must contain at least 8 characters.';

  @override
  String get error_passwordUpperCase =>
      'Password must contain an upper case character.';

  @override
  String get error_passwordNumeric =>
      'Password must contain a numeric character.';

  @override
  String get error_loadingBookmarks => 'Error loading bookmarks, try again';

  @override
  String get error_loadingOscePacks => 'Error trying to load the OSCE packs 😔';

  @override
  String get error_loadingOsceResults => 'Error trying to load the results 😔';

  @override
  String get error_loadingPacks => 'Error trying to load the packs 😔';

  @override
  String get flashcardMainCard_packFinished => 'Good job!';

  @override
  String get flashcardMainButton_reveal => 'Reveal';

  @override
  String get flashcardMainButton_skip => 'Skip';

  @override
  String get flashcardPageDialog_packFinishedForNow =>
      'You are finished, for now';

  @override
  String flashcardPageDialog_packEnded(String subTextForDialog) {
    return 'Congratulations! There are no flashcards from $subTextForDialog that are due now, but you can come back later.\n\nKeep up the good work.';
  }

  @override
  String get flashcardPageDialog_backHome => 'Back to home page';

  @override
  String get flashcardPageDialog_sessionFinishedForNow =>
      'This study session is finished, for now';

  @override
  String get flashcardPageDialog_sessionEnded =>
      'Congratulations! You completed this study session.';

  @override
  String get flashcardPageDialog_closeSession =>
      'You can close this session, or you can continue learning.';

  @override
  String get flashcardPageDialog_continueLearning => 'Continue learning';

  @override
  String get flashcardPageDialog_endThisSession => 'End this session?';

  @override
  String flashcardPageDialog_updateCardsPerSession(
    int cardDifference,
    int userCardsPerSession,
    int newCardsPerSession,
  ) {
    return 'You’ve reviewed $cardDifference more cards than your target of $userCardsPerSession cards per session.\n\nWould you like to update your session target to $newCardsPerSession cards per session?\n\nYou can always change this in settings.';
  }

  @override
  String get flashcardPageDialog_keepCurrent => 'Keep current';

  @override
  String get flashcardPageDialog_updateTarget => 'Update target';

  @override
  String get flashcardRatingButtons_easyLabel => 'Easy';

  @override
  String get flashcardRatingButtons_easyTooltip =>
      'I knew it instantly and confidently.';

  @override
  String get flashcardRatingButtons_goodLabel => 'Good';

  @override
  String get flashcardRatingButtons_goodTooltip =>
      'I remembered it, but I had to think for a moment.';

  @override
  String get flashcardRatingButtons_hardLabel => 'Hard';

  @override
  String get flashcardRatingButtons_hardTooltip => 'I barely remembered this.';

  @override
  String get flashcardRatingButtons_againLabel => 'Again';

  @override
  String get flashcardRatingButtons_againTooltip =>
      'I forgot this or got it wrong.';

  @override
  String flashcardTimerContainer(String time) {
    return 'Time: $time';
  }

  @override
  String get flashcardPage_packTitle => 'Pack';

  @override
  String get flashcardPage_packSubtext => 'pack';

  @override
  String get flashcardPage_bookmarksTitle => 'Bookmarks';

  @override
  String get flashcardPage_bookmarksSubtext => 'bookmarks';

  @override
  String get reviewBookmarkPage_review => 'Review Bookmarked Flashcards';

  @override
  String get reviewBookmarkPage_noBookmarks =>
      'Looks like you didn\'t bookmark any flashcards yet.';

  @override
  String reviewBookmarkPage_numberOfBookmarks(int number) {
    return 'Number of bookmarks: $number';
  }

  @override
  String get reviewBookmarkPage_remove => 'Remove bookmark';

  @override
  String get reviewBookmarkPage_swipe =>
      'Tap ⋮ on a card to remove its bookmark or add it to a set';

  @override
  String get osceListPage_title => 'OSCEs';

  @override
  String get osceListPage_fetching => 'Fetching OSCE scenarios...';

  @override
  String get osceListPage_noPacks =>
      'Whoops, looks like there are no OSCE packs available';

  @override
  String get oscePage_title => 'OSCE';

  @override
  String get oscePage_previous => 'Previous';

  @override
  String get oscePage_next => 'Next';

  @override
  String get oscePage_submit => 'Submit';

  @override
  String get osceResultPage_title => 'OSCE results';

  @override
  String get osceResultPage_fetching => 'Fetching OSCE results...';

  @override
  String get osceSubmitPage_title => 'OSCE Result';

  @override
  String get osceSubmitPage_success => 'You successfully completed the OSCE!';

  @override
  String osceSubmitPage_osceName(String name) {
    return 'OSCE Name: $name';
  }

  @override
  String get osceSubmitPage_unmarked => 'Unmarked checks:';

  @override
  String get osceSubmitPage_download => 'Download PDF';

  @override
  String get osceSubmitPage_back => 'Back to main menu';

  @override
  String get splashPageText => 'Preparing your experience...';

  @override
  String get packsPage_title => 'Packs';

  @override
  String get packsPage_fetching => 'Fetching flashcard packs...';

  @override
  String get packsPage_noPacks =>
      'Whoops, looks like there are no packs available';

  @override
  String get updateEmailSuccessfulPage_text =>
      '🎉 All set! Your email address has been updated.\\nMake sure to use the new one next time you sign in.';

  @override
  String get updateEmailSuccessfulPage_button => 'Go to login';

  @override
  String changeEmailDuringVerificationPage_text(String email) {
    return 'Successfully sent new email verification at $email';
  }

  @override
  String get changeEmailPage_leaveWithoutVerifying =>
      'Leave without verifying email?';

  @override
  String get changeEmailPage_text =>
      'To change your email, you must complete the verification while staying on this page.\\n\\nVerifying your email from another page may cause the app to behave unexpectedly.\\n\\nIf you’ve changed your mind, you can safely leave this page.';

  @override
  String get changeEmailPage_stay => 'Stay on this page';

  @override
  String get changeEmailPage_leaveAnyway => 'Leave anyway';

  @override
  String get deleteProfilePage_deleteAccount => 'Delete Account';

  @override
  String get deleteProfilePage_areYouSure =>
      'Are you sure you want to permanently delete your account? \n\n This action cannot be undone and all your data will be lost.';

  @override
  String get updatePasswordPage_title => 'Update Password';

  @override
  String get updatePasswordPage_update => 'Update';

  @override
  String get updatePasswordPage_success => 'Successfully updated password';

  @override
  String get updatePasswordPage_password => 'Password';

  @override
  String get updatePasswordPage_repeatPassword => 'Repeat password';

  @override
  String get profileData_bookmarks => 'Bookmarks';

  @override
  String get profileData_chooseEngage =>
      'Choose how you\'d like to engage with your bookmarked cards.';

  @override
  String get profileData_review => 'Review flashcards';

  @override
  String get profileData_startTest => 'Test yourself';

  @override
  String get profileData_osces => 'OSCES';

  @override
  String get profileData_osceResults => 'OSCE Results';

  @override
  String get assignAdminPage_title => 'Assign Admin Roles';

  @override
  String get flashcardBuilderPage_title => 'Flashcard Builder';

  @override
  String get osceBuilderPage_title => 'OSCE Builder';

  @override
  String get reportFlashcardPage_success => 'Flashcard reported successfully';

  @override
  String get reportFlashcardPage_report => 'Report Flashcard';

  @override
  String get reportFlashcardPage_whyReporting =>
      'Why are you reporting this flashcard';

  @override
  String get reportFlashcardPage_submitReport => 'Submit Report';

  @override
  String get reportFlashcardPage_additionalDetails =>
      'Additional details (optional)';

  @override
  String get reportFlashcardPage_explain => 'Explain your report here';

  @override
  String get reportReason_inappropriateContent => 'Inappropriate content';

  @override
  String get reportReason_incorrectInformation => 'Incorrect information';

  @override
  String get reportReason_poorTranslation => 'Poor translation';

  @override
  String get reportReason_duplicateFlashcard => 'Duplicate flashcard';

  @override
  String get reportReason_other => 'Other';
}
