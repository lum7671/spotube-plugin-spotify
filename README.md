# MySpotify - Spotube Plugin

Spotify 메타데이터를 제공하는 Spotube 플러그인입니다.

## 기능

- 🔐 **인증 관리**: Spotify 계정 로그인 및 세션 관리
- 🎵 **트랙 관리**: 트랙 조회, 저장, 라디오 기능
- 📀 **앨범 관리**: 앨범 조회, 저장, 트랙 목록
- 👤 **아티스트 관리**: 아티스트 조회, 인기 트랙, 관련 아티스트
- 📝 **플레이리스트**: 플레이리스트 생성, 수정, 트랙 추가/제거
- 🔍 **검색**: 트랙, 앨범, 아티스트, 플레이리스트 검색
- 📱 **사용자 프로필**: 저장된 트랙, 앨범, 아티스트, 플레이리스트 조회
- 🌐 **Browse**: Spotify 홈 섹션 및 추천 콘텐츠

## 설치

1. 최신 릴리스에서 `plugin.smplug` 파일을 다운로드합니다
2. Spotube 앱을 실행합니다
3. 설정 > 플러그인 > 플러그인 추가에서 다운로드한 파일을 선택합니다
4. Spotube를 재시작합니다

## 사용 방법

### 인증

플러그인을 처음 사용할 때 Spotify 계정으로 로그인해야 합니다:

1. Spotube를 실행합니다
2. 플러그인이 자동으로 로그인 페이지를 엽니다
3. Spotify 계정 정보를 입력하여 로그인합니다
4. 인증이 완료되면 자동으로 세션이 저장됩니다

인증 정보는 로컬에 안전하게 저장되며, 만료 시 자동으로 갱신됩니다.

### 기능 사용

플러그인이 활성화되면 Spotube의 모든 기능을 사용할 수 있습니다:

- **음악 검색**: Spotify 카탈로그에서 음악 검색
- **라이브러리 관리**: 좋아요, 저장, 플레이리스트 관리
- **재생**: 트랙, 앨범, 플레이리스트 재생
- **추천**: Browse 섹션에서 추천 콘텐츠 확인

## 개발

### 요구사항

- [Hetu Script](https://github.com/hetu-script/hetu-script) 0.4.2+
- Flutter SDK 3.7.2+
- Spotube 앱

### 빌드

```bash
# 소스 컴파일
make compile

# 플러그인 패키징
make archive
```

빌드된 플러그인은 `build/plugin.smplug` 파일로 생성됩니다.

### 테스트

example 디렉토리에 테스트 앱이 포함되어 있습니다:

```bash
cd example
flutter run -d macos
```

## 기술 스택

- **언어**: Hetu Script
- **API**: Spotify GraphQL API (비공식)
- **인증**: Cookie 기반 인증 + TOTP
- **의존성**:
  - hetu_spotify_gql_client: Spotify GraphQL API 클라이언트
  - hetu_otp_util: OTP 생성 유틸리티
  - hetu_std: Hetu 표준 라이브러리
  - hetu_spotube_plugin: Spotube 플러그인 바인딩

## 변경사항

### 1.0.1 (2025-10-24)

#### 개선

- 🏗️ **코드 리팩토링 완료** (Phase 1-3)
  - 유틸리티 모듈 분리 (logger, cookie_util, error_handler)
  - Auth 모듈 분리 (auth_totp, auth_token, auth_credentials)
  - 모든 segment 파일에 통합 로깅 및 에러 핸들링 적용
- 📝 **로깅 시스템 개선**
  - 전체 코드베이스에 일관된 로깅 적용 (12개 파일)
  - print() 완전 제거, logger 사용으로 통일
  - 타임스탬프 및 로그 레벨 기반 필터링
- 🛡️ **에러 처리 강화**
  - 모든 API 엔드포인트에 에러 핸들러 적용
  - Null 체크 및 경고 로깅 추가
  - 사용자 친화적 에러 메시지 제공
- 🧹 **코드 품질 향상**
  - 코드 중복 100% 제거 (~150줄)
  - auth.ht 파일 크기 28.6% 감소 (709→506 lines)
  - 모듈화로 유지보수성 및 테스트 가능성 향상

#### 수정

- 🐛 auth.ht의 `_Timer` 타입 선언 제거 (Hetu Script 호환성 개선)
- 🐛 Cookie 유틸리티로 안전한 쿠키 접근 보장

### 1.0.0 (2025-10-24)

#### 추가

- ✨ Spotify 인증 시스템 구현
  - Cookie 기반 인증
  - TOTP를 사용한 액세스 토큰 생성
  - 자동 토큰 갱신 (만료 5분 전)
  - 인증 상태 스트림
- ✨ 모든 Spotify 메타데이터 API 지원
  - Track: 조회, 저장, 라디오
  - Album: 조회, 저장, 트랙 목록, 최신 릴리스
  - Artist: 조회, 저장, 인기 트랙, 관련 아티스트, 앨범
  - Playlist: 생성, 수정, 삭제, 저장, 트랙 추가/제거
  - User: 프로필, 저장된 트랙/앨범/아티스트/플레이리스트
  - Search: 통합 검색, 타입별 검색
  - Browse: 홈 섹션, 추천 콘텐츠
- ✨ 데이터 변환기 (Converters)
  - Spotify API 응답을 Spotube 형식으로 변환
  - 페이지네이션 지원

#### 수정

- 🐛 Browse 기능에서 `sp_t` 쿠키 누락 시 발생하는 RangeError 수정
  - 안전한 쿠키 접근 로직 추가
  - 쿠키가 없을 경우 빈 문자열 사용

#### 개선

- 📝 상세한 로깅 시스템 추가
  - 로그 레벨 지원 (DEBUG, INFO, WARNING, ERROR)
  - 타임스탬프 및 태그 기반 로깅
- 🔒 에러 처리 강화
  - 인증 실패 시 명확한 에러 메시지
  - 네트워크 에러 재시도 로직
  - 토큰 갱신 실패 시 재인증

## 라이선스

이 프로젝트는 개인 사용 목적으로 제공됩니다.

## 주의사항

⚠️ 이 플러그인은 Spotify의 비공식 API를 사용합니다. Spotify의 서비스 약관을 준수하여 사용해주세요.

## 기여

버그 리포트 및 기능 제안은 [GitHub Issues](https://github.com/lum7671/spotube-plugin-spotify/issues)에서 환영합니다.

## 작성자

Nate Doohyun Jang

## 지원

문제가 발생하면 다음을 확인해주세요:

1. Spotube 앱이 최신 버전인지 확인
2. 플러그인을 다시 설치
3. Spotube 캐시 삭제 후 재시작
4. 로그인 다시 시도

그래도 문제가 해결되지 않으면 GitHub Issues에 다음 정보와 함께 보고해주세요:

- Spotube 버전
- 운영체제
- 에러 메시지 (있는 경우)
- 재현 방법
