import 'package:auto_route/auto_route.dart';
import 'package:flashcards/bloc/authorization/auth/auth_bloc.dart';
import 'package:flashcards/bloc/authorization/auth/auth_event.dart';
import 'package:flashcards/bloc/authorization/delete_user/delete_user_cubit.dart';
import 'package:flashcards/bloc/authorization/delete_user/delete_user_state.dart';
import 'package:flashcards/config/router/router.dart';
import 'package:flashcards/data/repositories/users/auth_repository.dart';
import 'package:flashcards/data/repositories/users/profile_repository.dart';
import 'package:flashcards/ui/constants/styles.dart';
import 'package:flashcards/ui/theme/theme_extensions.dart';
import 'package:flashcards/ui/widgets/auth/reauth_section.dart';
import 'package:flashcards/ui/widgets/core/bloc_buttons/bloc_button.dart';
import 'package:flashcards/ui/widgets/core/bloc_text_field.dart';
import 'package:flashcards/ui/widgets/core/card_factory.dart';
import 'package:flashcards/ui/widgets/core/loading_overlay_listener.dart';
import 'package:flashcards/utils/firebase_error_mapper.dart';
import 'package:flashcards/ui/widgets/core/desktop_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flashcards/l10n/app_localizations.dart';

@RoutePage()
class DeleteProfilePage extends StatelessWidget {
  const DeleteProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DeleteUserCubit(
        profileRepo: context.read<ProfileRepository>(),
        resetSignOutReason: context.read<AuthBloc>().resetSignOutReason,
        setSignOutReason: context.read<AuthBloc>().setSignOutReason,
      ),
      child: _DeleteProfileView(),
    );
  }
}

class _DeleteProfileView extends StatefulWidget {
  const _DeleteProfileView({super.key});

  @override
  State<_DeleteProfileView> createState() => _DeleteProfileViewState();
}

class _DeleteProfileViewState extends State<_DeleteProfileView> {
  final _passCont = TextEditingController();

  @override
  void dispose() {
    _passCont.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    void onDelete() {
      context.read<DeleteUserCubit>().deleteUser(_passCont.text);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.deleteProfilePage_deleteAccount,
        ),
        leading: IconButton(
          onPressed: () => context.router.pop(),
          icon: Icon(Icons.arrow_back),
        ),
      ),
      body: ReadableWidth(
        maxWidth: 820,
        child: LoadingOverlayListener<DeleteUserCubit, DeleteUserState>(
          isLoading: (state) => state is DeleteUserLoading,
          loadingText: "Deleting all your data, be patient",
          child: BlocListener<DeleteUserCubit, DeleteUserState>(
            listener: (context, state) {
              switch (state) {
                case DeleteUserError(:final error):
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        mapFirebaseError(
                          error: error,
                          context: context,
                        ).message,
                      ),
                    ),
                  );
                  break;
                // case DeleteUserSuccessful():
                //   context.router.replaceAll([DeleteAccountSuccessfulRoute()]);
                //   break;
                default:
                  break;
              }
            },
            child: SingleChildScrollView(
              child: Container(
                height: MediaQuery.of(context).size.height - 110,
                margin: const EdgeInsets.only(top: 25),
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalScreenPadding,
                ),
                child: Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CardFactory.error(
                          isThreeLine: true,
                          subtitle: Text(
                            AppLocalizations.of(
                              context,
                            )!.deleteProfilePage_areYouSure,
                          ),
                        ),
                        const SizedBox(height: 20),
                        CardFactory.info(
                          title: Text("Subscriptions are not deleted"),
                          isThreeLine: true,
                          subtitle: Text(
                            "Deleting your account will remove all your data "
                            "(profile, progress, sets and exams). \n\nHowever, "
                            "any active subscription linked to your email will remain. "
                            "If you create a new account using the same email address "
                            "your subscriptions "
                            "will still be valid and automatically applied.",
                          ),
                        ),
                        const SizedBox(height: 40),
                        Text("Please enter your password for security reasons"),
                        const SizedBox(height: 10),
                        BlocTextField<DeleteUserCubit, DeleteUserState>(
                          errorSelector: (state) => null,
                          obscureText: true,
                          labelText: "Password",
                          textEditingController: _passCont,
                        ),
                      ],
                    ),
                    Positioned(
                      bottom: bottomSpacingOnFloatingButtons,
                      left: 0,
                      right: 0,
                      child: BlocButton<DeleteUserCubit, DeleteUserState>.small(
                        backgroundColor: context.colors.error,
                        textString: AppLocalizations.of(
                          context,
                        )!.deleteProfilePage_deleteAccount,
                        onPressed: (context) => onDelete(),
                        isLoadingState: (state) => false,
                        isDisabledState: (state) =>
                            state is DeleteUserLoading ||
                            state is DeleteUserRequiresReauth,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
