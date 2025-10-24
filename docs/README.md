# Spotube Plugin Spotify - 프로젝트 문서

## 📋 프로젝트 개요

**Spotube Plugin Spotify**는 Spotube 애플리케이션을 위한 Spotify 메타데이터 제공 플러그인입니다. Hetu 스크립트 언어로 작성되었으며, Spotify GraphQL API를 통해 음악 데이터를 가져옵니다.

- **버전**: 0.1.4
- **작성자**: Sonic Liberation
- **저장소**: <https://github.com/sonic-liberation/spotube-plugin-spotify>
- **플러그인 API 버전**: 1.0.0

## 🏗️ 아키텍처

### 진입점 (Entry Point)

- **클래스**: `SpotifyMetadataProviderPlugin`
- **파일**: `src/plugin.ht`

### 주요 구성 요소

```plaintext
SpotifyMetadataProviderPlugin
├── api: SpotifyGqlApi (GraphQL 클라이언트)
├── auth: SpotifyAuthEndpoint (인증 관리)
└── Endpoints:
    ├── album: AlbumEndpoint
    ├── artist: ArtistEndpoint
    ├── browse: BrowseEndpoint
    ├── playlist: PlaylistEndpoint
    ├── search: SearchEndpoint
    ├── track: TrackEndpoint
    ├── user: UserEndpoint
    └── core: CorePlugin
```

## 🔑 주요 기능

### 1. 인증 (Authentication)

**파일**: `src/segments/auth.ht`

#### 특징

- **WebView 기반 로그인**: Spotify 계정 페이지를 통한 인증
- **토큰 자동 갱신**: 만료 전 자동으로 액세스 토큰 갱신
- **로컬 저장소 관리**: 인증 정보 영구 저장
- **TOTP (Time-based One-Time Password)** 보안

#### 주요 메서드

- `authenticate()`: WebView를 통한 사용자 인증
- `login(cookies)`: 쿠키를 통한 로그인
- `refreshCredentials()`: 인증 정보 갱신
- `logout()`: 로그아웃 및 저장된 인증 정보 삭제
- `isAuthenticated()`: 인증 상태 확인
- `isExpired()`: 토큰 만료 여부 확인

#### 인증 데이터 구조

```json
credentials: {
  cookies: [Cookie],
  accessToken: string,
  expiration: int (milliseconds)
}
```

### 2. 검색 (Search)

**파일**: `src/segments/search.ht`

#### 지원 카테고리

- `all`: 전체 검색 (트랙, 앨범, 아티스트, 플레이리스트)
- `tracks`: 트랙 검색
- `albums`: 앨범 검색
- `artists`: 아티스트 검색
- `playlists`: 플레이리스트 검색

#### API 메서드

- `all(query)`: 모든 카테고리 통합 검색
- `albums(query, offset, limit)`: 앨범 검색 (페이지네이션)
- `artists(query, offset, limit)`: 아티스트 검색 (페이지네이션)
- `tracks(query, offset, limit)`: 트랙 검색 (페이지네이션)
- `playlists(query, offset, limit)`: 플레이리스트 검색 (페이지네이션)

### 3. 트랙 (Track)

**파일**: `src/segments/track.ht`

#### 주요 메서드

- `getTrack(id)`: 트랙 상세 정보 조회
- `save(trackIds)`: 트랙을 라이브러리에 저장
- `unsave(trackIds)`: 라이브러리에서 트랙 제거
- `radio(trackId)`: 트랙 기반 라디오 플레이리스트 생성

### 4. 앨범 (Album)

**파일**: `src/segments/album.ht`

#### 주요 메서드

- `getAlbum(id)`: 앨범 상세 정보 조회
- `tracks(id, offset, limit)`: 앨범의 트랙 목록 조회
- `releases(offset, limit)`: 새 앨범 릴리즈 조회
- `save(albumIds)`: 앨범을 라이브러리에 저장
- `unsave(albumIds)`: 라이브러리에서 앨범 제거

### 5. 플레이리스트 (Playlist)

**파일**: `src/segments/playlist.ht`

#### 주요 메서드

- `getPlaylist(id)`: 플레이리스트 상세 정보 조회
- `tracks(id, offset, limit)`: 플레이리스트의 트랙 목록 조회
- `create(userId, name, description, public, collaborative)`: 새 플레이리스트 생성
- `update(playlistId, ...)`: 플레이리스트 정보 업데이트
- `deletePlaylist(playlistId)`: 플레이리스트 삭제
- `addTracks(playlistId, trackIds, position)`: 트랙 추가
- `removeTracks(playlistId, trackIds)`: 트랙 제거
- `save(playlistId)`: 플레이리스트 팔로우
- `unsave(playlistId)`: 플레이리스트 언팔로우

### 6. 아티스트 (Artist)

**파일**: `src/segments/artist.ht`

### 7. 브라우징 (Browse)

**파일**: `src/segments/browse.ht`

### 8. 사용자 (User)

**파일**: `src/segments/user.ht`

### 9. 코어 기능 (Core)

**파일**: `src/segments/core.ht`

#### 주요 기능

- **플러그인 업데이트 확인**: GitHub Releases를 통한 자동 업데이트 확인
- **버전 관리**: Semantic Versioning (major.minor.patch)
- **지원 정보 제공**: 아티스트 지원 메시지

#### 주요 메서드

- `checkUpdate(currentConfig)`: 업데이트 가능 여부 확인
- `support`: 지원 정보 문자열 반환

## 🔄 데이터 변환 (Converters)

**파일**: `src/converter/converter.ht`

### 변환 메서드

- `paginated()`: 페이지네이션 데이터 구조 변환
- `fullTracks()`: 전체 트랙 정보 변환
- `fullAlbums()`: 전체 앨범 정보 변환
- `simpleAlbums()`: 간단한 앨범 정보 변환
- `fullArtists()`: 전체 아티스트 정보 변환
- `simpleArtists()`: 간단한 아티스트 정보 변환
- `simpleUser()`: 간단한 사용자 정보 변환
- `simplePlaylistsFromLibraryV3()`: 간단한 플레이리스트 정보 변환
- `fullPlaylists()`: 전체 플레이리스트 정보 변환

### 페이지네이션 구조

```json
{
  limit: int,
  nextOffset: int?,
  hasMore: bool,
  total: int,
  items: [...]
}
```

## 🔧 빌드 및 배포

### 빌드 명령어

```bash
# 플러그인 컴파일
make compile

# 플러그인 아카이브 생성 (.smplug 파일)
make archive
```

### 빌드 산출물

- `build/plugin.out`: 컴파일된 Hetu 바이트코드
- `build/plugin.smplug`: 배포 가능한 플러그인 패키지 (ZIP 아카이브)

### 패키지 구성

```plaintext
plugin.smplug (ZIP)
├── plugin.json (메타데이터)
├── plugin.out (바이트코드)
└── logo.png (플러그인 아이콘)
```

## 📦 의존성

### 내부 의존성

- **hetu_otp_util**: TOTP 생성을 위한 OTP 유틸리티
- **hetu_spotify_gql_client**: Spotify GraphQL API 클라이언트

### 필요한 API 권한

- `webview`: 인증을 위한 WebView 접근
- `localstorage`: 인증 정보 저장
- `timezone`: 시간 기반 인증

## 🔐 보안 고려사항

### 인증 보안

1. **TOTP 기반 토큰 생성**: 시간 기반 일회용 비밀번호 사용
2. **Nuance 동적 로딩**: GitHub에서 최신 보안 시드 가져오기
3. **쿠키 기반 인증**: Spotify `sp_dc` 쿠키 사용
4. **자동 토큰 갱신**: 만료 전 자동 재발급

### 데이터 보호

- 로컬 저장소를 통한 인증 정보 암호화 저장
- 민감한 정보 (쿠키, 토큰)의 메모리 내 관리

## 🎯 사용 예시

### 인증 흐름

```javascript
// 플러그인 초기화
var plugin = SpotifyMetadataProviderPlugin()

// 인증 상태 확인
if (!plugin.auth.isAuthenticated()) {
  // 인증 시작
  await plugin.auth.authenticate()
}
```

### 검색 예시

```javascript
// 전체 검색
var results = await plugin.search.all("Queen")

// 트랙만 검색 (페이지네이션)
var tracks = await plugin.search.tracks("Bohemian Rhapsody", 
  offset: 0, 
  limit: 20
)
```

### 플레이리스트 관리

```javascript
// 플레이리스트 생성
var playlist = await plugin.playlist.create(
  userId: "myUserId",
  name: "My Awesome Playlist",
  description: "Created with Spotube Plugin",
  public: true,
  collaborative: false
)

// 트랙 추가
await plugin.playlist.addTracks(
  playlist["id"],
  trackIds: ["trackId1", "trackId2"],
  position: 0
)
```

## 📊 데이터 모델

### Track

```json
{
  id: string,
  name: string,
  externalUri: string,
  explicit: bool,
  durationMs: int,
  isrc: string,
  artists: [SimpleArtist],
  album: SimpleAlbum
}
```

### Album (Simple)

```json
{
  id: string,
  name: string,
  externalUri: string,
  releaseDate: string,
  releaseDatePrecision: string,
  artists: [SimpleArtist],
  images: [Image],
  albumType: string
}
```

### Artist (Simple)

```json
{
  id: string,
  name: string,
  externalUri: string,
  images: [Image]?
}
```

### Playlist

```json
{
  id: string,
  name: string,
  description: string,
  images: [Image],
  externalUri: string,
  owner: SimpleUser,
  collaborative: bool,
  public: bool
}
```

## 🚀 개발 가이드

### 개발 환경 설정

1. Hetu 컴파일러 설치
2. 프로젝트 클론
3. 의존성 설치
4. 예시 앱 실행 (example/ 디렉토리)

### 테스트

예시 Flutter 앱을 통한 플러그인 테스트:

```bash
cd example
flutter run
```

### 디버깅

- 컴파일된 바이트코드는 `example/assets/bytecode/`에 자동 복사됨
- 예시 앱에서 실시간으로 플러그인 테스트 가능

## 📝 라이선스 및 기여

### 철학

프로젝트는 아티스트 직접 지원을 장려합니다:

- 스트리밍 서비스의 중개 수수료를 피하고
- 아티스트에게 직접 기부하거나 굿즈 구매, 콘서트 참석을 권장합니다

### 기여 방법

1. 이슈 생성 또는 기존 이슈 확인
2. Fork 및 브랜치 생성
3. 변경사항 커밋
4. Pull Request 생성

## 🔗 관련 링크

- [GitHub Repository](<https://github.com/sonic-liberation/spotube-plugin-spotify>)
- [Spotube 메인 프로젝트](<https://spotube.krtirtho.dev/>)

## 📞 문의

문제 발생 시 GitHub Issues를 통해 문의해주세요.
