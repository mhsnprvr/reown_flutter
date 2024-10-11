import 'package:appcheck/appcheck.dart';
import 'package:reown_appkit/modal/services/uri_service/i_url_utils.dart';
import 'package:reown_appkit/modal/services/uri_service/launch_url_exception.dart';
import 'package:reown_appkit/modal/utils/core_utils.dart';
import 'package:reown_appkit/modal/utils/platform_utils.dart';
import 'package:reown_appkit/reown_appkit.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;
import 'package:reown_appkit/modal/services/explorer_service/models/redirect.dart';

class UriService extends IUriService {
  UriService({required IReownCore core}) : _core = core;
  final IReownCore _core;

  @override
  Future<bool> isInstalled(String? uri, {String? id}) async {
    if (uri == null || uri.isEmpty) {
      return false;
    }

    // If the wallet is just a generic wc:// then it is not installed
    if (uri.contains('wc://')) {
      return false;
    }

    if (PlatformUtils.canDetectInstalledApps()) {
      final p = PlatformUtils.getPlatformExact();
      try {
        if (p == PlatformExact.android) {
          return await _androidAppCheck(uri);
        } else if (p == PlatformExact.ios) {
          // TODO change to ReownCoreUtils.canOpenUrl(uri)
          return await launcher.canLaunchUrl(Uri.parse(uri));
        }
      } on FormatException catch (e) {
        if (id != null) {
          _core.logger.i('[$runtimeType] $uri ($id): ${e.message}');
        } else {
          _core.logger.i('[$runtimeType] $uri: ${e.message}');
        }
      } catch (e) {
        rethrow;
      }
    }

    return false;
  }

  @override
  Future<bool> launchUrl(Uri url, {launcher.LaunchMode? mode}) async {
    return await _launchUrlFunc(
      url,
      mode: mode,
    );
  }

  @override
  Future<bool> openRedirect(
    WalletRedirect redirect, {
    String? wcURI,
    PlatformType? pType,
  }) async {
    //
    Uri? uriToOpen;
    try {
      final isMobile = (redirect.mobileOnly || pType == PlatformType.mobile);
      if (isMobile && redirect.mobile != null) {
        uriToOpen = CoreUtils.formatCustomSchemeUri(
          redirect.mobile,
          wcURI,
        );
      }
      //
      final isWeb = (redirect.webOnly || pType == PlatformType.web);
      if (isWeb && redirect.web != null) {
        uriToOpen = CoreUtils.formatWebUrl(
          redirect.web,
          wcURI,
        );
      }
      //
      final isDesktop = (redirect.desktopOnly || pType == PlatformType.desktop);
      if (isDesktop && redirect.desktop != null) {
        uriToOpen = CoreUtils.formatCustomSchemeUri(
          redirect.desktop,
          wcURI,
        );
      }
    } catch (e) {
      _core.logger.e('Error opening redirect', error: e);
      return false;
    }
    _core.logger.i('[$runtimeType] openRedirect $uriToOpen');
    return await _launchUrlFunc(
      uriToOpen!,
      mode: launcher.LaunchMode.externalApplication,
    );
  }

  Future<bool> _launchUrlFunc(Uri url, {launcher.LaunchMode? mode}) async {
    try {
      final success = await launcher.launchUrl(
        url,
        mode: mode ?? launcher.LaunchMode.platformDefault,
      );
      if (!success) {
        throw CanNotLaunchUrl();
      }
      return true;
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> _androidAppCheck(String uri) async {
    try {
      return await AppCheck().isAppEnabled(uri);
    } catch (e) {
      return false;
    }
  }
}
