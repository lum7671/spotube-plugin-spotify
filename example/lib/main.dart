import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:example/localstorage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:hetu_script/hetu_script.dart';
import 'package:hetu_spotube_plugin/hetu_spotube_plugin.dart';
import 'package:hetu_std/hetu_std.dart';
import 'package:shared_preferences/shared_preferences.dart';

final getIt = GetIt.instance;

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  if (runWebViewTitleBarWidget(args)) {
    return;
  }

  HttpOverrides.global = MyHttpOverrides();

  final hetu = Hetu();
  getIt.registerSingleton<Hetu>(hetu);
  getIt.registerSingleton<SharedPreferences>(
    await SharedPreferences.getInstance(),
  );

  hetu.init();
  HetuStdLoader.loadBindings(hetu);

  await HetuStdLoader.loadBytecodeFlutter(hetu);
  await HetuSpotubePluginLoader.loadBytecodeFlutter(hetu);
  final byteCode = await rootBundle.load("assets/bytecode/plugin.out");
  await hetu.loadBytecode(
    bytes: byteCode.buffer.asUint8List(),
    moduleName: "plugin",
  );

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: Scaffold(body: MyHome()));
  }
}

class MyHome extends StatefulWidget {
  const MyHome({super.key});

  @override
  State<MyHome> createState() => _MyHomeState();
}

class _MyHomeState extends State<MyHome> {
  bool _isAuthenticated = false;
  String _authMessage = "인증 상태 확인 중...";

  @override
  void initState() {
    super.initState();
    final hetu = getIt<Hetu>();
    BuildContext? pageContext;
    HetuSpotubePluginLoader.loadBindings(
      hetu,
      localStorageImpl: SharedPreferencesLocalStorage(
        getIt<SharedPreferences>(),
      ),
      onNavigatorPush: (route) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) {
              pageContext = context;
              return Scaffold(
                appBar: AppBar(title: const Text('WebView')),
                body: route,
              );
            },
          ),
        );
      },
      onNavigatorPop: () {
        if (pageContext == null) {
          return;
        }
        Navigator.pop(pageContext!);
        // WebView가 닫힐 때 인증 상태 재확인
        Future.delayed(Duration(milliseconds: 500), () {
          _checkAuthStatus();
        });
      },
      onShowForm: (title, fields) async {
        return [];
      },
      createYoutubeEngine: () {
        // YouTube 엔진이 필요하지 않으므로 더미 구현 제공
        return YouTubeEngine(
          search: (query) async => [],
          getVideo: (videoId) async => {},
          streamManifest: (videoId) async => [],
        );
      },
    );

    // 🔧 Cookie 바인딩 문제 해결: Dart에서 Cookie를 JSON으로 변환하는 헬퍼 함수 추가
    hetu.interpreter.bindExternalFunction(
      'cookiesToJson',
      (HTEntity entity, {
        List<dynamic> positionalArgs = const [],
        Map<String, dynamic> namedArgs = const {},
        List<HTType> typeArgs = const [],
      }) {
        final cookies = positionalArgs[0] as List;
        return cookies.map((cookie) {
          return {
            'name': cookie.name,
            'value': cookie.value,
            'domain': cookie.domain,
            'path': cookie.path,
            'expiresDate': cookie.expiresDate,
            'isHttpOnly': cookie.isHttpOnly,
            'isSecure': cookie.isSecure,
            'isSessionOnly': cookie.isSessionOnly,
          };
        }).toList();
      },
      override: true,
    );

    // 🔧 LocalStorage 바인딩 문제 해결: Dart에서 직접 저장/읽기 헬퍼 함수 추가
    hetu.interpreter.bindExternalFunction(
      'saveCredentials',
      (HTEntity entity, {
        List<dynamic> positionalArgs = const [],
        Map<String, dynamic> namedArgs = const {},
        List<HTType> typeArgs = const [],
      }) async {
        final credentials = positionalArgs[0];
        final prefs = getIt<SharedPreferences>();
        
        try {
          // HTStruct를 Map으로 변환
          Map<String, dynamic> credentialsMap;
          if (credentials is Map) {
            credentialsMap = Map<String, dynamic>.from(credentials);
          } else {
            // HTStruct인 경우 JSON 인코딩을 통해 변환
            final jsonString = jsonEncode(credentials);
            credentialsMap = jsonDecode(jsonString) as Map<String, dynamic>;
          }
          
          final finalJsonString = jsonEncode(credentialsMap);
          debugPrint('[DART saveCredentials] Saving: ${finalJsonString.substring(0, min(100, finalJsonString.length))}...');
          
          final result = await prefs.setString('myspotify_plugin.credentials', finalJsonString);
          debugPrint('[DART saveCredentials] Save result: $result');
          
          return result;
        } catch (e) {
          debugPrint('[DART saveCredentials] Error: $e');
          debugPrint('[DART saveCredentials] Credentials type: ${credentials.runtimeType}');
          return false;
        }
      },
      override: true,
    );

    hetu.interpreter.bindExternalFunction(
      'loadCredentials',
      (HTEntity entity, {
        List<dynamic> positionalArgs = const [],
        Map<String, dynamic> namedArgs = const {},
        List<HTType> typeArgs = const [],
      }) async {
        final prefs = getIt<SharedPreferences>();
        
        try {
          final credentialsStr = prefs.getString('myspotify_plugin.credentials');
          
          if (credentialsStr == null) {
            debugPrint('[DART loadCredentials] No credentials found');
            return null;
          }
          
          debugPrint('[DART loadCredentials] Found credentials: ${credentialsStr.substring(0, min(100, credentialsStr.length))}...');
          
          final credentialsMap = jsonDecode(credentialsStr) as Map;
          return credentialsMap;
        } catch (e) {
          debugPrint('[DART loadCredentials] Error: $e');
          return null;
        }
      },
      override: true,
    );

    hetu.eval(r"""
    external fun cookiesToJson;
    external fun saveCredentials;
    external fun loadCredentials;
    import "module:plugin" as plugin;

    var SpotifyMetadataProviderPlugin = plugin.SpotifyMetadataProviderPlugin;
    var metadata = SpotifyMetadataProviderPlugin()
    """);

    // 초기 인증 상태 확인
    _checkAuthStatus();

    // 인증 상태 변경 감지 - authStateStream 구독
    _setupAuthStateListener();
  }

  void _setupAuthStateListener() async {
    try {
      final stream = await getIt<Hetu>().eval("metadata.auth.authStateStream");
      if (stream != null) {
        stream.listen((event) {
          debugPrint("[AUTH STATE CHANGE] $event");
          // 인증 상태가 변경되면 UI 업데이트
          _checkAuthStatus();
        });
      }
    } catch (e) {
      debugPrint("Failed to setup auth state listener: $e");
    }
  }

  Future<void> _checkAuthStatus() async {
    try {
      final result = await getIt<Hetu>().eval("metadata.getAuthStatus()");
      debugPrint("[CHECK AUTH STATUS] Result: $result");
      if (result is Map) {
        setState(() {
          _isAuthenticated = result['authenticated'] == true;  // 'isAuthenticated' -> 'authenticated'
          if (_isAuthenticated) {
            _authMessage = "인증됨";
          } else {
            _authMessage = "플러그인에 인증이 필요합니다";
          }
        });
        debugPrint("[CHECK AUTH STATUS] Updated UI: isAuthenticated=$_isAuthenticated");
      }
    } catch (e) {
      debugPrint("[CHECK AUTH STATUS] Error: $e");
      setState(() {
        _isAuthenticated = false;
        _authMessage = "인증 상태 확인 실패: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        children: [
          // 인증 상태 표시
          if (!_isAuthenticated)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                color: Colors.orange[100],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Icon(Icons.warning_amber, size: 48, color: Colors.orange[800]),
                      SizedBox(height: 8),
                      Text(
                        _authMessage,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Wrap(
            children: [
              ElevatedButton(
                onPressed: _isAuthenticated ? null : () async {
                  await getIt<Hetu>().eval("metadata.authenticate()");
                  await _checkAuthStatus(); // 인증 후 상태 다시 확인
                },
                child: Text(_isAuthenticated ? "인증됨" : "로그인"),
              ),
              if (_isAuthenticated)
                ElevatedButton(
                  onPressed: () async {
                    await getIt<Hetu>().eval("metadata.logout()");
                    await _checkAuthStatus(); // 로그아웃 후 상태 다시 확인
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: Text("로그아웃"),
                ),
              // 테스트용: 가짜 로그인 (웹 환경에서 WebView 없이 테스트)
              ElevatedButton(
                onPressed: () async {
                  debugPrint("[TEST] Simulating login...");
                  await getIt<Hetu>().eval(r"""
                    // 가짜 credentials 생성
                    var fakeCookies = [
                      {
                        "name": "sp_dc",
                        "value": "test_sp_dc_value",
                        "domain": ".spotify.com"
                      },
                      {
                        "name": "sp_key",
                        "value": "test_sp_key_value", 
                        "domain": ".spotify.com"
                      }
                    ]
                    metadata.auth.login(fakeCookies)
                  """);
                  debugPrint("[TEST] Fake login completed, checking status...");
                  await Future.delayed(Duration(seconds: 1));
                  await _checkAuthStatus();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: Text("🧪 테스트 로그인"),
              ),
              // 테스트용: 원본 Spotify 플러그인 credentials 시뮬레이션
              ElevatedButton(
                onPressed: () async {
                  debugPrint("[TEST] Creating fake original Spotify credentials...");
                  final prefs = getIt<SharedPreferences>();
                  
                  // 원본 Spotify 플러그인의 credentials 형식으로 저장
                  final originalCredentials = {
                    "cookie": [
                      {
                        "name": "sp_dc",
                        "value": "original_plugin_sp_dc_value",
                        "domain": ".spotify.com"
                      },
                      {
                        "name": "sp_key",
                        "value": "original_plugin_sp_key_value",
                        "domain": ".spotify.com"
                      }
                    ],
                    "accessToken": "fake_access_token",
                    "expiresAt": DateTime.now().add(Duration(hours: 1)).millisecondsSinceEpoch,
                  };
                  
                  await prefs.setString('spotify_credentials', 
                    jsonEncode(originalCredentials));
                  
                  debugPrint("[TEST] Original credentials saved to 'spotify_credentials'");
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ 원본 Spotify credentials 생성 완료!\n이제 "로그인" 버튼을 눌러보세요.'),
                      duration: Duration(seconds: 3),
                      backgroundColor: Colors.blue,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: Text("🔧 원본 플러그인 시뮬레이션"),
              ),
              // 테스트용: Dart에서 직접 저장
              ElevatedButton(
                onPressed: () async {
                  debugPrint("[DART TEST] Saving directly from Dart...");
                  final prefs = getIt<SharedPreferences>();
                  
                  final testData = {
                    'test': 'value',
                    'timestamp': DateTime.now().toIso8601String(),
                  };
                  
                  final jsonString = jsonEncode(testData);
                  debugPrint("[DART TEST] JSON string: $jsonString");
                  
                  final result = await prefs.setString('myspotify_plugin.credentials', jsonString);
                  debugPrint("[DART TEST] Save result: $result");
                  
                  // 바로 읽어보기
                  final readBack = prefs.getString('myspotify_plugin.credentials');
                  debugPrint("[DART TEST] Read back: $readBack");
                  
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('Dart 직접 저장 테스트'),
                      content: Text(result ? '✅ 저장 성공\n\n읽은 값:\n$readBack' : '❌ 저장 실패'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('닫기'),
                        ),
                      ],
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                child: Text("🧪 Dart 직접 저장"),
              ),
              // 테스트용: LocalStorage 상태 확인
              ElevatedButton(
                onPressed: () async {
                  debugPrint("[TEST] Checking LocalStorage...");
                  final prefs = getIt<SharedPreferences>();
                  
                  final originalCreds = prefs.getString('spotify_credentials');
                  final myCreds = prefs.getString('myspotify_plugin.credentials');
                  
                  debugPrint("[TEST] spotify_credentials: ${originalCreds?.substring(0, 100)}...");
                  debugPrint("[TEST] myspotify_plugin.credentials: ${myCreds?.substring(0, 100)}...");
                  
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('LocalStorage 상태'),
                      content: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('원본 Spotify:', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(originalCreds != null ? '✅ 존재함' : '❌ 없음'),
                            SizedBox(height: 16),
                            Text('MySpotify:', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(myCreds != null ? '✅ 존재함' : '❌ 없음'),
                          ],
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('닫기'),
                        ),
                        TextButton(
                          onPressed: () async {
                            await prefs.remove('spotify_credentials');
                            await prefs.remove('myspotify_plugin.credentials');
                            Navigator.pop(context);
                            _checkAuthStatus();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('🗑️ 모든 credentials 삭제됨')),
                            );
                          },
                          child: Text('모두 삭제', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                ),
                child: Text("📊 LocalStorage 확인"),
              ),
              ElevatedButton(
                onPressed: () async {
                  await getIt<Hetu>().eval("metadata.core.checkUpdate({version: '1.0.0'}.toJson())");
                },
                child: Text("Check Update"),
              ),
              ElevatedButton(
                onPressed: () async {
                  final result = await getIt<Hetu>().eval("metadata.core.support");
                  debugPrint(result.toString());
                },
                child: Text("Support"),
              ),
            ],
          ),
          Text("User"),
          Wrap(
            children: [
              ElevatedButton(
                onPressed: () async {
                  final result = await getIt<Hetu>().eval("metadata.user.me()");
                  debugPrint(result.toString());
                },
                child: Text("Get Me"),
              ),
              ElevatedButton(
                onPressed: () async {
                  final result = await getIt<Hetu>().eval(
                    "metadata.user.savedTracks()",
                  );
                  debugPrint(result.toString());
                },
                child: Text("Get User Saved Tracks"),
              ),
              ElevatedButton(
                onPressed: () async {
                  final result = await getIt<Hetu>().eval(
                    "metadata.user.savedPlaylists()",
                  );
                  debugPrint(result.toString());
                },
                child: Text("Get User Saved Playlists"),
              ),
              ElevatedButton(
                onPressed: () async {
                  final result = await getIt<Hetu>().eval(
                    "metadata.user.savedAlbums()",
                  );
                  debugPrint(result.toString());
                },
                child: Text("Get User Saved Albums"),
              ),
              ElevatedButton(
                onPressed: () async {
                  final result = await getIt<Hetu>().eval(
                    "metadata.user.savedArtists()",
                  );
                  debugPrint(result.toString());
                },
                child: Text("Get User Saved Artists"),
              ),
              ElevatedButton(
                onPressed: () async {
                  final result = await getIt<Hetu>().eval(
                    "metadata.user.isSavedTracks(['11dFghVXANMlKmJXsNCbNl'])",
                  );
                  debugPrint(result.toString());
                },
                child: Text("Is track saved?"),
              ),
              ElevatedButton(
                onPressed: () async {
                  final result = await getIt<Hetu>().eval(
                    "metadata.user.isSavedPlaylist('3cEYpjA9oz9GiPac4AsH4n')",
                  );
                  debugPrint(result.toString());
                },
                child: Text("Is playlist saved?"),
              ),
              ElevatedButton(
                onPressed: () async {
                  final result = await getIt<Hetu>().eval(
                    "metadata.user.isSavedAlbums(['4aawyAB9vmqN3uQ7FjRGTy'])",
                  );
                  debugPrint(result.toString());
                },
                child: Text("Is album saved?"),
              ),
              ElevatedButton(
                onPressed: () async {
                  final result = await getIt<Hetu>().eval(
                    "metadata.user.isSavedArtists(['0TnOYISbd1XYRBk9myaseg'])",
                  );
                  debugPrint(result.toString());
                },
                child: Text("Is artist saved?"),
              ),
            ],
          ),
          Text("Tracks"),
          Wrap(
            children: [
              ElevatedButton(
                onPressed: () async {
                  final result = await getIt<Hetu>().eval(
                    "metadata.track.getTrack('11dFghVXANMlKmJXsNCbNl')",
                  );
                  debugPrint(result.toString());
                },
                child: Text("Get Track"),
              ),
              ElevatedButton(
                onPressed: () async {
                  final result = await getIt<Hetu>().eval(
                    "metadata.track.radio('11dFghVXANMlKmJXsNCbNl')",
                  );
                  debugPrint(result.toString());
                },
                child: Text("Track Radio"),
              ),
              ElevatedButton(
                onPressed: () async {
                  final result = await getIt<Hetu>().eval(
                    "metadata.track.save(['11dFghVXANMlKmJXsNCbNl'])",
                  );
                  debugPrint(result.toString());
                },
                child: Text("Save Track"),
              ),
              ElevatedButton(
                onPressed: () async {
                  final result = await getIt<Hetu>().eval(
                    "metadata.track.unsave(['11dFghVXANMlKmJXsNCbNl'])",
                  );
                  debugPrint(result.toString());
                },
                child: Text("Unsave Track"),
              ),
            ],
          ),
          Text("Playlists"),
          Wrap(
            children: [
              ElevatedButton(
                onPressed: () async {
                  final result = await getIt<Hetu>().eval(
                    "metadata.playlist.getPlaylist('3cEYpjA9oz9GiPac4AsH4n')",
                  );
                  debugPrint(result.toString());
                },
                child: Text("Get Playlist"),
              ),
              ElevatedButton(
                onPressed: () async {
                  final result = await getIt<Hetu>().eval(
                    "metadata.playlist.tracks('3cEYpjA9oz9GiPac4AsH4n')",
                  );
                  debugPrint(result.toString());
                },
                child: Text("Get Playlist Tracks"),
              ),
              ElevatedButton(
                onPressed: () async {
                  final result = await getIt<Hetu>().eval("""
                    var myPlaylist
                    metadata.user.me().then((me) {
                      return metadata.playlist.create(
                        me["id"],
                        name: "Hetu Playlist",
                        description: "This is a playlist created by Hetu"
                      ).then((playlist){
                        myPlaylist = playlist
                        return playlist
                      })
                    })
                    """);
                  debugPrint(result.toString());
                },
                child: Text("Create Playlist"),
              ),
              ElevatedButton(
                onPressed: () async {
                  // Create playlist must be called first
                  final result = await getIt<Hetu>().eval("""
                    metadata.playlist.update(
                      myPlaylist["id"],
                      name: "Hetu Update Playlist",
                      description: "This playlist is updated by Hetu"
                    ).then((data)=> metadata.playlist.getPlaylist(myPlaylist["id"]))
                    """);
                  debugPrint(result.toString());
                },
                child: Text("Update Playlist"),
              ),
              ElevatedButton(
                onPressed: () async {
                  // Create playlist must be called first
                  final result = await getIt<Hetu>().eval(
                    'metadata.playlist.unsave(myPlaylist["id"])',
                  );
                  debugPrint(result.toString());
                },
                child: Text("Delete Playlist"),
              ),
              ElevatedButton(
                onPressed: () async {
                  final result = await getIt<Hetu>().eval(
                    'metadata.playlist.save("37i9dQZF1E4oJSdHZrVjxD")',
                  );
                  debugPrint(result.toString());
                },
                child: Text("Save Playlist"),
              ),
              ElevatedButton(
                onPressed: () async {
                  final result = await getIt<Hetu>().eval(
                    'metadata.playlist.unsave("37i9dQZF1E4oJSdHZrVjxD")',
                  );
                  debugPrint(result.toString());
                },
                child: Text("Unsave Playlist"),
              ),
              ElevatedButton(
                onPressed: () async {
                  // Create playlist must be called first
                  final result = await getIt<Hetu>().eval(
                    'metadata.playlist.addTracks(myPlaylist["id"], trackIds: ["5zCnGtCl5Ac5zlFHXaZmhy"])',
                  );
                  debugPrint(result.toString());
                },
                child: Text("Add Tracks"),
              ),
              ElevatedButton(
                onPressed: () async {
                  // Create playlist must be called first
                  final result = await getIt<Hetu>().eval(
                    'metadata.playlist.removeTracks(myPlaylist["id"], trackIds: ["5zCnGtCl5Ac5zlFHXaZmhy"])',
                  );
                  debugPrint(result.toString());
                },
                child: Text("Remove Tracks"),
              ),
            ],
          ),
          Text("Albums"),
          Wrap(
            children: [
              ElevatedButton(
                onPressed: () async {
                  final result = await getIt<Hetu>().eval(
                    "metadata.album.getAlbum('4aawyAB9vmqN3uQ7FjRGTy')",
                  );
                  debugPrint(result.toString());
                },
                child: Text("Get Album"),
              ),
              ElevatedButton(
                onPressed: () async {
                  final result = await getIt<Hetu>().eval(
                    "metadata.album.tracks('4aawyAB9vmqN3uQ7FjRGTy')",
                  );
                  debugPrint(result.toString());
                },
                child: Text("Get Album Tracks"),
              ),
              ElevatedButton(
                onPressed: () async {
                  final result = await getIt<Hetu>().eval(
                    "metadata.album.releases()",
                  );
                  debugPrint(result.toString());
                },
                child: Text("Releases"),
              ),
              ElevatedButton(
                onPressed: () async {
                  final result = await getIt<Hetu>().eval(
                    'metadata.album.save(["4aawyAB9vmqN3uQ7FjRGTy"])',
                  );
                  debugPrint(result.toString());
                },
                child: Text("Save Album"),
              ),
              ElevatedButton(
                onPressed: () async {
                  final result = await getIt<Hetu>().eval(
                    'metadata.album.unsave(["4aawyAB9vmqN3uQ7FjRGTy"])',
                  );
                  debugPrint(result.toString());
                },
                child: Text("Unsave Album"),
              ),
            ],
          ),
          Text("Artists"),
          Wrap(
            children: [
              ElevatedButton(
                onPressed: () async {
                  final result = await getIt<Hetu>().eval(
                    "metadata.artist.getArtist('0TnOYISbd1XYRBk9myaseg')",
                  );
                  debugPrint(result.toString());
                },
                child: Text("Get Artist"),
              ),
              ElevatedButton(
                onPressed: () async {
                  final result = await getIt<Hetu>().eval(
                    "metadata.artist.topTracks('0TnOYISbd1XYRBk9myaseg')",
                  );
                  debugPrint(result.toString());
                },
                child: Text("Artist Top Tracks"),
              ),
              ElevatedButton(
                onPressed: () async {
                  final result = await getIt<Hetu>().eval(
                    "metadata.artist.related('0TnOYISbd1XYRBk9myaseg')",
                  );
                  debugPrint(result.toString());
                },
                child: Text("Related artists"),
              ),
              ElevatedButton(
                onPressed: () async {
                  final result = await getIt<Hetu>().eval(
                    "metadata.artist.albums('0TnOYISbd1XYRBk9myaseg')",
                  );
                  debugPrint(result.toString());
                },
                child: Text("Artist albums"),
              ),
              ElevatedButton(
                onPressed: () async {
                  final result = await getIt<Hetu>().eval(
                    "metadata.artist.save(['0TnOYISbd1XYRBk9myaseg'])",
                  );
                  debugPrint(result.toString());
                },
                child: Text("Save Artist"),
              ),
              ElevatedButton(
                onPressed: () async {
                  final result = await getIt<Hetu>().eval(
                    "metadata.artist.unsave(['0TnOYISbd1XYRBk9myaseg'])",
                  );
                  debugPrint(result.toString());
                },
                child: Text("Unsave Artists"),
              ),
            ],
          ),
          Text("Search"),
          Wrap(
            children: [
              ElevatedButton(
                onPressed: () async {
                  final result = await getIt<Hetu>().eval(
                    "metadata.search.all('Twenty One Pilots')",
                  );
                  debugPrint(result.toString());
                },
                child: Text("Search Twenty One Pilots"),
              ),
              ElevatedButton(
                onPressed: () async {
                  final result = await getIt<Hetu>().eval(
                    "metadata.search.tracks('Twenty One Pilots')",
                  );
                  debugPrint(result.toString());
                },
                child: Text("Only Tracks"),
              ),
              ElevatedButton(
                onPressed: () async {
                  final result = await getIt<Hetu>().eval(
                    "metadata.search.albums('Twenty One Pilots')",
                  );
                  debugPrint(result.toString());
                },
                child: Text("Only albums"),
              ),
              ElevatedButton(
                onPressed: () async {
                  final result = await getIt<Hetu>().eval(
                    "metadata.search.artists('Twenty One Pilots')",
                  );
                  debugPrint(result.toString());
                },
                child: Text("Only artists"),
              ),
              ElevatedButton(
                onPressed: () async {
                  final result = await getIt<Hetu>().eval(
                    "metadata.search.playlists('Twenty One Pilots')",
                  );
                  debugPrint(result.toString());
                },
                child: Text("Only playlists"),
              ),
            ],
          ),
          Text("Browse"),
          Wrap(
            children: [
              ElevatedButton(
                onPressed: () async {
                  final result = await getIt<Hetu>().eval(
                    "metadata.browse.sections()",
                  );
                  debugPrint(result.toString());
                },
                child: Text("Browse sections"),
              ),
              ElevatedButton(
                onPressed: () async {
                  final result = await getIt<Hetu>().eval(
                    "metadata.browse.sectionItems('0JQ5DAnM3wGh0gz1MXnu3B')",
                  );
                  debugPrint(result.toString());
                },
                child: Text("Popular singles and albums"),
              ),
              ElevatedButton(
                onPressed: () async {
                  final result = await getIt<Hetu>().eval(
                    "metadata.browse.sectionItems('0JQ5DAuChZYPe9iDhh2mJz')",
                  );
                  debugPrint(result.toString());
                },
                child: Text("Today in Music"),
              ),
              ElevatedButton(
                onPressed: () async {
                  final result = await getIt<Hetu>().eval(
                    "metadata.browse.sectionItems('0JQ5DAnM3wGh0gz1MXnu3C')",
                  );
                  debugPrint(result.toString());
                },
                child: Text("Popular Artists"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
