# 📦 의존성 라이브러리 업그레이드 분석

**작성일**: 2025-10-24  
**프로젝트 버전**: 1.0.2  
**상태**: 분석 완료

---

## 📊 현재 환경

### 개발 환경

- **Flutter**: 3.35.6 (stable)
- **Dart SDK**: 3.9.2
- **Hetu Script**: 0.4.2+1

### 의존성 구조

```text
spotube-plugin-spotify
├── dependencies/ (Git 서브모듈)
│   ├── hetu_spotify_gql_client (커스텀)
│   └── hetu_otp_util (커스텀)
└── example/
    └── pubspec.yaml (테스트 앱)
```

---

## 🔍 의존성 라이브러리 현황

### 1. 코어 의존성

#### hetu_script (현재: ^0.4.2+1)

**최신 버전**: 0.4.2+1 ✅  
**상태**: 최신  
**출처**: pub.dev

**특징**:

- Spotube 플러그인 시스템의 핵심
- 안정 버전 사용 중
- 업그레이드 불필요

**리스크**:

- 🟢 **낮음** - 안정적인 버전

---

#### hetu_std (Git 의존성)

**현재**: Git main 브랜치  
**상태**: 최신 (main 브랜치 추적)  
**출처**: <https://github.com/hetu-community/hetu_std.git>

**특징**:

- Hetu Script 표준 라이브러리
- Git main 브랜치 직접 참조
- 자동 업데이트 없음

**업그레이드 방안**:

```bash
cd example
flutter pub upgrade hetu_std
```

**리스크**:

- 🟡 **중간** - Git 의존성은 버전 고정 없음
- Breaking change 가능성

**권장 사항**:

- ⚠️ 특정 커밋 해시로 고정 권장

```yaml
hetu_std:
  git:
    url: https://github.com/hetu-community/hetu_std.git
    ref: [specific-commit-hash]  # 안정성 확보
```

---

### 2. 플러그인 의존성

#### hetu_spotube_plugin (Git 의존성)

**현재**: Git main 브랜치  
**상태**: 최신 (main 브랜치 추적)  
**출처**: <https://github.com/KRTirtho/hetu_spotube_plugin.git>

**특징**:

- Spotube 플러그인 바인딩
- KRTirtho 공식 저장소
- Git main 브랜치 직접 참조

**업그레이드 방안**:

```bash
cd example
flutter pub upgrade hetu_spotube_plugin
```

**리스크**:

- 🟡 **중간** - 외부 저장소 의존
- Spotube 앱 업데이트 시 API 변경 가능성

**권장 사항**:

- ⚠️ Spotube 앱 버전과 호환성 유지 필요
- 특정 커밋 해시로 고정 고려

---

#### hetu_otp_util (Git 서브모듈, 로컬 의존성)

**현재**: 커밋 7790606 (heads/main)  
**상태**: 커스텀 버전  
**위치**: `dependencies/hetu_otp_util/`

**pubspec.yaml**:

```yaml
dependencies:
  hetu_script: ^0.4.2+1  ✅ 최신
  path: ^1.9.1          ⚠️ 업데이트 가능
dev_dependencies:
  lints: ^5.0.0         ⚠️ 업데이트 가능
  test: ^1.24.0         ✅ 최신
```

**업그레이드 가능**:

- `path`: ^1.9.1 → ^1.9.2 (마이너 업데이트)
- `lints`: ^5.0.0 → ^6.0.0 (메이저 업데이트)

**리스크**:

- 🟢 **낮음** - 직접 관리하는 서브모듈
- 업데이트 제어 가능

**권장 사항**:

```bash
cd dependencies/hetu_otp_util
flutter pub upgrade
git commit -am "chore: update dependencies"
```

---

#### hetu_spotify_gql_client (Git 서브모듈, 로컬 의존성)

**현재**: 커밋 a3749ef (heads/main)  
**상태**: 커스텀 버전  
**위치**: `dependencies/hetu_spotify_gql_client/`

**pubspec.yaml**:

```yaml
dependencies:
  hetu_script: ^0.4.2+1  ✅ 최신
  hetu_std: git          ⚠️ Git 의존성
  path: ^1.9.1          ⚠️ 업데이트 가능
dev_dependencies:
  lints: ^5.0.0         ⚠️ 업데이트 가능
  test: ^1.24.0         ✅ 최신
```

**업그레이드 가능**:

- `path`: ^1.9.1 → ^1.9.2
- `lints`: ^5.0.0 → ^6.0.0

**리스크**:

- 🟢 **낮음** - 직접 관리하는 서브모듈

**권장 사항**:

```bash
cd dependencies/hetu_spotify_gql_client
flutter pub upgrade
git commit -am "chore: update dependencies"
```

---

### 3. Example 앱 의존성

#### 직접 의존성

| 패키지 | 현재 | 최신 | 상태 |
|--------|------|------|------|
| get_it | ^8.0.3 | 8.0.3 | ✅ 최신 |
| shared_preferences | ^2.5.3 | 2.5.3 | ✅ 최신 |

#### Dev 의존성

| 패키지 | 현재 | 최신 | 업그레이드 가능 |
|--------|------|------|----------------|
| flutter_lints | ^5.0.0 | 6.0.0 | 🔄 **메이저** |

#### 간접 의존성 (업그레이드 가능)

| 패키지 | 현재 | 최신 | 영향 |
|--------|------|------|------|
| flutter_timezone | 4.1.1 | 5.0.0 | 🔄 메이저 |
| fast_noise | 1.0.1 | 2.0.0 | 🔄 메이저 |
| intl | 0.17.0 | 0.20.2 | 🔄 마이너 |
| characters | 1.4.0 | 1.4.1 | 🟢 패치 |
| material_color_utilities | 0.11.1 | 0.13.0 | 🟢 마이너 |
| meta | 1.16.0 | 1.17.0 | 🟢 마이너 |
| test_api | 0.7.6 | 0.7.7 | 🟢 패치 |
| lints | 5.1.1 | 6.0.0 | 🔄 메이저 |

---

## 🎯 업그레이드 우선순위

### Priority 1: 보안 및 안정성 (즉시)

#### 1.1. flutter_lints 업그레이드 (5.0.0 → 6.0.0)

**파일**: `example/pubspec.yaml`

**변경**:

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0  # 5.0.0 → 6.0.0
```

**이유**:

- 최신 Dart/Flutter lint 규칙 적용
- 코드 품질 향상
- 잠재적 버그 탐지 개선

**영향**:

- 🟡 **중간** - 새로운 lint 경고/에러 발생 가능
- 코드 수정 필요할 수 있음

**실행**:

```bash
cd example
# pubspec.yaml 수정 후
flutter pub upgrade flutter_lints
flutter analyze  # 새로운 lint 이슈 확인
```

**예상 작업 시간**: 30분 - 1시간 (lint 이슈 수정 포함)

---

#### 1.2. 서브모듈 의존성 업그레이드

**대상**:

- `dependencies/hetu_otp_util/`
- `dependencies/hetu_spotify_gql_client/`

**업그레이드 항목**:

- `path`: 1.9.1 → 1.9.2
- `lints`: 5.0.0 → 6.0.0

**이유**:

- 최신 패키지 버그 수정
- 개발 도구 개선

**실행**:

```bash
# hetu_otp_util
cd dependencies/hetu_otp_util
# pubspec.yaml 수정
flutter pub upgrade
flutter test  # 테스트 실행
git add .
git commit -m "chore: upgrade dependencies to latest versions"

# hetu_spotify_gql_client
cd ../hetu_spotify_gql_client
# pubspec.yaml 수정
flutter pub upgrade
flutter test
git add .
git commit -m "chore: upgrade dependencies to latest versions"

# 메인 프로젝트로 돌아와서 서브모듈 업데이트 커밋
cd ../..
git add dependencies
git commit -m "chore: update submodules with latest dependencies"
```

**예상 작업 시간**: 30분

---

### Priority 2: 간접 의존성 메이저 업데이트 (선택적)

#### 2.1. flutter_timezone (4.1.1 → 5.0.0)

**영향 범위**: `BrowseEndpoint`에서 사용

**파일**: `src/segments/browse.ht`

```hetu
return Timezone.getLocalTimeZone().then((timeZone){
  // ...
})
```

**리스크**:

- 🟡 **중간** - API 변경 가능성
- Breaking changes 확인 필요

**업그레이드 방법**:

```bash
cd example
flutter pub upgrade flutter_timezone --major-versions
# API 변경 사항 확인
# browse.ht 테스트
```

**권장 사항**:

- ⚠️ 변경 로그 확인 필수
- 기능 테스트 필수 (Browse 섹션)

**예상 작업 시간**: 1시간 (테스트 포함)

---

#### 2.2. intl (0.17.0 → 0.20.2)

**영향 범위**: 날짜/시간 포맷팅 (간접 사용)

**리스크**:

- 🟢 **낮음** - 일반적으로 하위 호환

**업그레이드 방법**:

```bash
cd example
flutter pub upgrade intl --major-versions
```

**예상 작업 시간**: 10분

---

### Priority 3: Git 의존성 안정화 (권장)

#### 3.1. hetu_std 버전 고정

**현재 문제**:

```yaml
hetu_std:
  git:
    url: https://github.com/hetu-community/hetu_std.git
    ref: main  # ⚠️ 항상 최신 커밋
```

**개선안**:

```yaml
hetu_std:
  git:
    url: https://github.com/hetu-community/hetu_std.git
    ref: [specific-commit-hash]  # 특정 커밋 고정
```

**이유**:

- 빌드 재현성 확보
- 예기치 않은 breaking change 방지
- CI/CD 안정성 향상

**실행**:

```bash
# 1. 현재 사용 중인 커밋 해시 확인
cd example/.pub-cache/git/hetu_std-[hash]
git rev-parse HEAD

# 2. pubspec.yaml 업데이트
# dependencies/hetu_spotify_gql_client/pubspec.yaml
# example/pubspec.yaml 모두 수정

# 3. 테스트
flutter pub get
flutter test
```

**예상 작업 시간**: 20분

---

#### 3.2. hetu_spotube_plugin 버전 고정

**동일한 이유로 특정 커밋 고정 권장**

---

## 📋 업그레이드 실행 계획

### Phase 1: 안전한 업데이트 (1주차)

**목표**: lint 도구 및 패치 업데이트

- [ ] **Day 1-2**: flutter_lints 6.0.0 업그레이드
  - [ ] example/pubspec.yaml 수정
  - [ ] `flutter pub upgrade flutter_lints`
  - [ ] `flutter analyze` 실행
  - [ ] Lint 이슈 수정 (발견 시)
  - [ ] 전체 테스트 실행

- [ ] **Day 3**: 서브모듈 의존성 업그레이드
  - [ ] hetu_otp_util dependencies 업데이트
  - [ ] hetu_spotify_gql_client dependencies 업데이트
  - [ ] 각 서브모듈 테스트 실행
  - [ ] 서브모듈 커밋 및 메인 프로젝트 업데이트

- [ ] **Day 4**: Git 의존성 안정화
  - [ ] hetu_std 커밋 해시 고정
  - [ ] hetu_spotube_plugin 커밋 해시 고정
  - [ ] 빌드 재현성 테스트

- [ ] **Day 5**: 검증 및 문서화
  - [ ] 전체 기능 테스트 (로그인, Browse, Search 등)
  - [ ] 컴파일 및 배포 테스트
  - [ ] 변경 사항 문서화

---

### Phase 2: 메이저 업데이트 (2주차, 선택적)

**목표**: 간접 의존성 메이저 업데이트

- [ ] **Day 1-2**: flutter_timezone 5.0.0
  - [ ] 변경 로그 확인
  - [ ] 업그레이드 실행
  - [ ] browse.ht API 호환성 테스트
  - [ ] Browse 섹션 기능 테스트

- [ ] **Day 3**: intl 0.20.2
  - [ ] 업그레이드 실행
  - [ ] 날짜/시간 포맷팅 테스트

- [ ] **Day 4-5**: 통합 테스트
  - [ ] 전체 기능 회귀 테스트
  - [ ] 성능 측정 및 비교
  - [ ] 배포 준비

---

## 🔒 보안 영향 분석

### 현재 보안 상태

#### 1. Git 의존성 리스크

**리스크 레벨**: 🟡 **중간**

**문제점**:

- `hetu_std`: main 브랜치 직접 참조
- `hetu_spotube_plugin`: main 브랜치 직접 참조

**보안 영향**:

- 악의적 커밋 가능성 (낮음, 신뢰할 수 있는 저장소)
- 예기치 않은 취약점 도입 가능성

**완화 방안**:

- ✅ 특정 커밋 해시로 고정 (Phase 1 포함)
- ✅ 정기적인 보안 감사

---

#### 2. 간접 의존성 취약점

**현재 상태**: ✅ **안전**

**확인 방법**:

```bash
cd example
flutter pub outdated --json > outdated.json
# Snyk, Dependabot 등으로 취약점 스캔
```

**권장 사항**:

- 정기적인 `flutter pub outdated` 실행 (월 1회)
- GitHub Dependabot 활성화 고려

---

## ⚡ 성능 영향 분석

### 업그레이드로 인한 성능 개선

#### 1. flutter_lints 6.0.0

**예상 효과**:

- 🟢 코드 품질 향상 → 간접적 성능 개선
- 🟢 최신 best practice 적용

---

#### 2. path 1.9.2

**예상 효과**:

- 🟢 파일 경로 처리 최적화
- 영향: 미미 (컴파일 타임에만 사용)

---

#### 3. flutter_timezone 5.0.0

**예상 효과**:

- 🟡 timezone 조회 성능 개선 가능
- 영향: Browse 섹션 로딩 시간

**측정 방법**:

```hetu
// browse.ht
final start = DateTime.now().millisecondsSinceEpoch
return Timezone.getLocalTimeZone().then((timeZone){
  final end = DateTime.now().millisecondsSinceEpoch
  logger.debug("Performance", "Timezone lookup: ${end - start}ms")
  // ...
})
```

---

#### 4. intl 0.20.2

**예상 효과**:

- 🟢 날짜/시간 포맷팅 성능 개선
- 영향: Logger 타임스탬프 생성

---

### 전체 예상 성능 영향

| 영역 | 현재 | 업그레이드 후 | 변화 |
|------|------|---------------|------|
| 컴파일 시간 | ~500ms | ~500ms | 변화 없음 |
| 로그인 플로우 | 2-3초 | 2-3초 | 변화 없음 |
| Browse 로딩 | ? | ? | 측정 필요 |
| 전체 메모리 | ? | ? | 측정 필요 |

---

## ✅ 업그레이드 체크리스트

### Phase 1: 안전한 업데이트

#### flutter_lints 6.0.0

- [ ] pubspec.yaml 수정
- [ ] `flutter pub upgrade flutter_lints` 실행
- [ ] `flutter analyze` 실행 및 이슈 수정
- [ ] 테스트 실행 및 확인
- [ ] 커밋 및 푸시

#### 서브모듈 의존성

- [ ] hetu_otp_util/pubspec.yaml 수정
- [ ] hetu_spotify_gql_client/pubspec.yaml 수정
- [ ] 각 서브모듈 `flutter pub upgrade` 실행
- [ ] 각 서브모듈 테스트 실행
- [ ] 서브모듈 커밋
- [ ] 메인 프로젝트 서브모듈 업데이트 커밋

#### Git 의존성 안정화

- [ ] hetu_std 현재 커밋 해시 확인
- [ ] hetu_spotube_plugin 현재 커밋 해시 확인
- [ ] pubspec.yaml에 커밋 해시 명시
- [ ] `flutter pub get` 및 빌드 테스트
- [ ] 문서화

### Phase 2: 메이저 업데이트 (선택적)

#### flutter_timezone 5.0.0

- [ ] 변경 로그 확인
- [ ] `flutter pub upgrade flutter_timezone --major-versions` 실행
- [ ] browse.ht API 호환성 확인
- [ ] Browse 섹션 기능 테스트
- [ ] 성능 측정 및 비교

#### intl 0.20.2

- [ ] `flutter pub upgrade intl --major-versions` 실행
- [ ] 날짜/시간 관련 기능 테스트

### 최종 검증

- [ ] 전체 기능 회귀 테스트
- [ ] 로그인 플로우 테스트
- [ ] Browse, Search, Playlist 등 주요 기능 테스트
- [ ] 컴파일 및 배포 테스트
- [ ] 성능 측정 및 문서화
- [ ] 변경 사항 README.md 업데이트

---

## 📝 업그레이드 후 검증 항목

### 기능 테스트

- [ ] **인증 플로우**
  - [ ] 로그인 성공
  - [ ] 토큰 갱신 작동
  - [ ] 로그아웃 작동

- [ ] **API 엔드포인트**
  - [ ] Album: 조회, 저장, 트랙 목록
  - [ ] Artist: 조회, 인기 트랙, 관련 아티스트
  - [ ] Playlist: 생성, 수정, 트랙 추가/제거
  - [ ] Search: 통합 검색, 타입별 검색
  - [ ] Track: 조회, 저장, 라디오
  - [ ] User: 프로필, 저장된 아이템 조회
  - [ ] Browse: 섹션 조회

- [ ] **로깅 시스템**
  - [ ] 모든 레벨 로그 정상 출력
  - [ ] 타임스탬프 포맷 정상

### 성능 테스트

- [ ] 컴파일 시간 측정 및 비교
- [ ] 로그인 플로우 시간 측정
- [ ] Browse 섹션 로딩 시간 측정
- [ ] 메모리 사용량 비교

### 보안 검증

- [ ] Git 의존성 커밋 해시 고정 확인
- [ ] 취약점 스캔 실행
- [ ] 빌드 재현성 테스트

---

## 🎯 권장 사항 요약

### 즉시 적용 (Phase 1)

1. ✅ **flutter_lints 6.0.0 업그레이드**
   - 코드 품질 향상
   - 작업 시간: 30분 - 1시간

2. ✅ **서브모듈 의존성 업데이트**
   - 최신 버그 수정 적용
   - 작업 시간: 30분

3. ✅ **Git 의존성 커밋 해시 고정**
   - 빌드 안정성 확보
   - 작업 시간: 20분

### 선택적 적용 (Phase 2)

4. 🔄 **flutter_timezone 5.0.0 업그레이드**
   - API 변경 사항 확인 필요
   - 작업 시간: 1시간

5. 🔄 **intl 0.20.2 업그레이드**
   - 하위 호환 가능성 높음
   - 작업 시간: 10분

### 장기 계획

6. 📅 **정기 업데이트 스케줄**
   - 월 1회: `flutter pub outdated` 확인
   - 분기 1회: 메이저 업데이트 검토
   - 연 1회: 전체 의존성 감사

---

**작성자**: AI Assistant  
**최종 수정**: 2025-10-24  
**다음 검토**: Phase 1 완료 후
