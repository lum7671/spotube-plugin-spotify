# 🚀 성능 개선 포인트 분석

**작성일**: 2025-10-24  
**버전**: 1.0.2  
**상태**: 분석 완료, 구현 대기

---

## 📊 현재 성능 현황

### 컴파일 성능

- **번들 시간**: ~500ms (26개 파일)
- **컴파일 시간**: ~33ms
- ✅ **상태**: 양호

### 런타임 성능

- **로그인 플로우**: WebView + TOTP + Token 생성 (~2-3초)
- **API 응답**: 의존성 라이브러리 성능에 의존
- ⚠️ **상태**: 개선 가능

---

## 🎯 성능 개선 포인트

### 1. Logger 성능 최적화 (우선순위: 높음)

#### 현재 문제점

**파일**: `src/util/logger.ht`

```hetu
fun log(level: LogLevel, tag: string, message: string) {
  if (!enabled) return;
  if (!_shouldLog(level)) return;
  
  final timestamp = DateTime.now().toString();  // ⚠️ 매 로그마다 생성
  print("[${timestamp}] [${levelStr}] [${tag}] ${message}");
}
```

**이슈**:

- `DateTime.now().toString()`가 **매 로그 호출마다 실행**됨
- 프로덕션 환경에서 로깅이 비활성화되어도 함수 호출 오버헤드 존재
- 로그 레벨 체크가 두 번 수행됨 (`enabled`, `_shouldLog`)

#### 개선 방안

```hetu
fun log(level: LogLevel, tag: string, message: string) {
  // 1. 조기 반환 최적화
  if (!enabled || !_shouldLog(level)) return;
  
  // 2. 타임스탬프 포맷 간소화 (millisecondsSinceEpoch 사용)
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final levelStr = _getLevelString(level);
  
  print("[${timestamp}] [${levelStr}] [${tag}] ${message}");
}
```

**예상 효과**:

- 조기 반환으로 불필요한 연산 제거
- 타임스탬프 생성 비용 감소
- 로그 많은 환경에서 5-10% 성능 향상 예상

---

### 2. List 변환 최적화 (우선순위: 중간)

#### 현재 문제점

**파일**: `src/segments/browse.ht`, `src/converter/converter.ht` 등

```hetu
// ⚠️ 3번의 개별 필터링 + toList() 호출
var playlists = section["items"].where((item) => item["objectType"] == "Playlist").toList()
var albums = section["items"].where((item) => item["objectType"] == "Album").toList()
var artists = section["items"].where((item) => item["objectType"] == "Artist").toList()
```

**이슈**:

- 동일한 배열을 3번 순회
- 각 순회마다 `.toList()` 메모리 할당
- 아이템이 많을 경우 O(3n) 복잡도

#### 개선 방안

```hetu
// ✅ 1번의 순회로 모두 분류
var playlists = []
var albums = []
var artists = []

for (var item in section["items"]) {
  if (item["objectType"] == "Playlist") {
    playlists.add(item)
  } else if (item["objectType"] == "Album") {
    albums.add(item)
  } else if (item["objectType"] == "Artist") {
    artists.add(item)
  }
}
```

**예상 효과**:

- 배열 순회 횟수: 3n → n
- 메모리 할당 최적화
- 대량 데이터 처리 시 30-40% 성능 향상 예상

**적용 대상**:

- `src/segments/browse.ht`: `sections()`, `sectionItems()` - 2곳
- `src/converter/converter.ht`: 필요시 적용 검토

---

### 3. Converter 메모리 최적화 (우선순위: 중간)

#### 현재 문제점

**파일**: `src/converter/converter.ht`

```hetu
static fun fullTracks(tracks: List) -> List {
  if(tracks == null || tracks.isEmpty) {
    return []
  }
  
  var modified = []  // ⚠️ 빈 배열로 시작
  
  for(var track in tracks) {
    // ... 변환 로직
    modified.add(modifiedTrack)  // ⚠️ 매번 add로 확장
  }
  
  return modified
}
```

**이슈**:

- 빈 배열에서 시작하여 `.add()`로 확장
- 배열 재할당 오버헤드 가능성
- 대량 데이터 변환 시 메모리 파편화

#### 개선 방안

```hetu
static fun fullTracks(tracks: List) -> List {
  if(tracks == null || tracks.isEmpty) {
    return []
  }
  
  // ✅ 사전에 크기 지정 (Hetu Script가 지원하는 경우)
  var modified = List(tracks.length)  // 또는 List.filled(tracks.length, null)
  
  for(var i = 0; i < tracks.length; i++) {
    var track = tracks[i]
    // ... 변환 로직
    modified[i] = modifiedTrack
  }
  
  return modified.where((item) => item != null).toList()
}
```

**예상 효과**:

- 메모리 재할당 최소화
- 배열 크기 예측으로 성능 향상
- 대량 트랙 변환 시 10-15% 성능 향상 예상

**적용 대상**:

- `fullTracks()` - 가장 많이 호출됨
- `fullAlbums()`
- `simpleAlbums()`
- `fullArtists()`
- `simpleArtists()`

---

### 4. 쿠키 조회 캐싱 (우선순위: 낮음)

#### 현재 문제점

**파일**: `src/util/cookie_util.ht`

```hetu
fun getCookieValue(credentials: Map, cookieName: string, {defaultValue: string = ""}) -> string {
  // ⚠️ 매번 배열 순회
  final cookies = credentials["cookies"].where((c) => c["name"] == cookieName).toList();
  
  if (cookies.length == 0) {
    return defaultValue;
  }
  
  return cookies[0]["value"];
}
```

**이슈**:

- `sp_t`, `sp_dc` 쿠키가 반복적으로 조회됨
- 매 API 호출마다 배열 순회

#### 개선 방안

```hetu
class CookieCache {
  var _cache: Map = {}
  var _lastCredentials: Map = null
  
  fun getCookieValue(credentials: Map, cookieName: string, {defaultValue: string = ""}) -> string {
    // 캐시 무효화 (credentials 변경 시)
    if (_lastCredentials != credentials) {
      _cache = {}
      _lastCredentials = credentials
    }
    
    // 캐시 확인
    if (_cache.containsKey(cookieName)) {
      return _cache[cookieName] ?? defaultValue
    }
    
    // 조회 및 캐싱
    final cookies = credentials["cookies"].where((c) => c["name"] == cookieName).toList();
    final value = cookies.length > 0 ? cookies[0]["value"] : defaultValue
    _cache[cookieName] = value
    
    return value
  }
}
```

**예상 효과**:

- 반복 조회 시 O(n) → O(1)
- API 호출 많은 환경에서 미세한 성능 향상

**주의사항**:

- credentials 변경 감지 필요
- 메모리 사용량 약간 증가

---

### 5. Token 갱신 타이머 최적화 (우선순위: 낮음)

#### 현재 문제점

**파일**: `src/segments/auth.ht`

```hetu
// ⚠️ 토큰 만료 1분 전에 갱신
final durationMs = duration.inMilliseconds
final safeDurationMs = durationMs > 60000 
  ? durationMs - 60000  // 1분 전에 갱신
  : (durationMs > 1000 ? durationMs : 1000)
```

**이슈**:

- 1분 전 갱신은 너무 보수적일 수 있음
- 네트워크 지연 고려하지 않음
- 갱신 실패 시 재시도 로직이 복잡함

#### 개선 방안

```hetu
// ✅ 5분 전에 갱신 (더 안정적)
final safetyMargin = 300000  // 5분
final safeDurationMs = durationMs > safetyMargin 
  ? durationMs - safetyMargin
  : (durationMs > 1000 ? durationMs : 1000)
```

**예상 효과**:

- 토큰 만료 위험 감소
- 네트워크 지연 허용 범위 증가
- 사용자 경험 개선

---

### 6. 조건부 로깅 (우선순위: 낮음)

#### 현재 문제점

**파일**: 모든 segment 파일

```hetu
fun getAlbum(id: string) {
  logger.info("getAlbum", "Fetching album: ${id}")  // ⚠️ 항상 실행
  return client.album.getAlbum(id).then((album) {
    // ...
  })
}
```

**이슈**:

- 문자열 보간(`${id}`)이 로그 비활성화 상태에서도 실행됨
- 불필요한 연산 낭비

#### 개선 방안

**옵션 1: 로그 레벨 체크**

```hetu
fun getAlbum(id: string) {
  if (logger.enabled && logger.minLevel <= LogLevel.INFO) {
    logger.info("getAlbum", "Fetching album: ${id}")
  }
  return client.album.getAlbum(id).then((album) {
    // ...
  })
}
```

**옵션 2: Lazy Evaluation (Hetu Script 지원 시)**

```hetu
fun info(tag: string, messageBuilder: () -> string) {
  if (!enabled || !_shouldLog(LogLevel.INFO)) return;
  
  final message = messageBuilder()  // 필요할 때만 생성
  // ...
}

// 사용
logger.info("getAlbum", () => "Fetching album: ${id}")
```

**예상 효과**:

- 프로덕션 환경에서 문자열 연산 제거
- CPU 사용량 미세 감소

---

## 📋 구현 우선순위

### Phase 1: 즉시 적용 가능 (난이도: 낮음)

1. ✅ **Logger 타임스탬프 최적화**
   - 파일: `src/util/logger.ht`
   - 예상 작업 시간: 10분
   - 예상 효과: 5-10% 로깅 성능 향상

2. ✅ **Token 갱신 타이머 안정성 개선**
   - 파일: `src/segments/auth.ht`
   - 예상 작업 시간: 5분
   - 예상 효과: 사용자 경험 개선

### Phase 2: 중간 우선순위 (난이도: 중간)

3. 🔄 **List 변환 최적화**
   - 파일: `src/segments/browse.ht`
   - 예상 작업 시간: 30분
   - 예상 효과: 30-40% browse 성능 향상
   - 리스크: 로직 변경으로 인한 버그 가능성

4. 🔄 **Converter 메모리 최적화**
   - 파일: `src/converter/converter.ht`
   - 예상 작업 시간: 1시간
   - 예상 효과: 10-15% 변환 성능 향상
   - 리스크: Hetu Script의 List 사전 할당 지원 확인 필요

### Phase 3: 장기 개선 (난이도: 높음)

5. ⏳ **쿠키 조회 캐싱**
   - 파일: `src/util/cookie_util.ht`
   - 예상 작업 시간: 1시간
   - 예상 효과: 미세한 성능 향상
   - 리스크: 캐시 무효화 로직 필요

6. ⏳ **조건부 로깅**
   - 파일: 모든 segment 파일
   - 예상 작업 시간: 2시간
   - 예상 효과: 프로덕션 환경에서 미세한 성능 향상
   - 리스크: 코드 복잡도 증가

---

## 🧪 성능 측정 방법

### 측정 도구

1. **Hetu Script Profiler** (지원 시)
   - 함수 호출 빈도
   - 실행 시간 분석

2. **수동 측정**

   ```hetu
   final start = DateTime.now().millisecondsSinceEpoch
   // ... 측정할 코드
   final end = DateTime.now().millisecondsSinceEpoch
   logger.debug("Performance", "Took ${end - start}ms")
   ```

3. **Flutter DevTools**
   - 메모리 사용량
   - CPU 프로파일링

### 측정 시나리오

1. **로그인 플로우**: authenticate() → login() 전체 시간
2. **Browse 섹션 로딩**: sections() 호출 시간
3. **대량 트랙 변환**: fullTracks(100개) 변환 시간
4. **반복 API 호출**: 동일 API 10회 연속 호출 시간

---

## 📝 구현 체크리스트

### Phase 1

- [ ] Logger 타임스탬프 최적화
  - [ ] `log()` 메서드 수정
  - [ ] 조기 반환 로직 개선
  - [ ] 테스트 및 검증
- [ ] Token 갱신 타이머 안정성 개선
  - [ ] 갱신 시간을 5분 전으로 변경
  - [ ] 테스트 및 검증

### Phase 2

- [ ] List 변환 최적화
  - [ ] `browse.ht` sections() 메서드 수정
  - [ ] `browse.ht` sectionItems() 메서드 수정
  - [ ] 성능 측정 및 비교
  - [ ] 테스트 및 검증
- [ ] Converter 메모리 최적화
  - [ ] Hetu Script List 사전 할당 지원 확인
  - [ ] fullTracks() 메서드 수정
  - [ ] 나머지 Converter 메서드 수정
  - [ ] 성능 측정 및 비교
  - [ ] 테스트 및 검증

### Phase 3

- [ ] 쿠키 조회 캐싱
  - [ ] CookieCache 클래스 설계
  - [ ] 캐시 무효화 로직 구현
  - [ ] 테스트 및 검증
- [ ] 조건부 로깅
  - [ ] Logger API 변경 검토
  - [ ] 모든 segment 파일 수정
  - [ ] 테스트 및 검증

---

## ⚠️ 주의사항

### Hetu Script 제약 사항

1. **List 사전 할당**: Hetu Script가 `List(size)` 또는 `List.filled()` 지원하는지 확인 필요
2. **Closure 성능**: 람다 함수 오버헤드 고려
3. **타입 추론**: 명시적 타입 선언이 성능에 영향을 줄 수 있음

### 테스트 필수

- 모든 성능 최적화 후 반드시 전체 기능 테스트 수행
- 성능 측정 결과 문서화
- 회귀(regression) 방지

### 우선순위 원칙

1. **사용자 경험** > **성능**
2. **안정성** > **속도**
3. **가독성** > **최적화**

---

## 📊 예상 전체 효과

### 최선의 시나리오 (모든 최적화 적용 시)

- **로그인 플로우**: 현재 대비 5-10% 향상
- **Browse 섹션**: 현재 대비 30-40% 향상
- **대량 데이터 변환**: 현재 대비 15-20% 향상
- **메모리 사용량**: 10-15% 감소
- **전체 체감 속도**: 미세한 개선

### 현실적 시나리오 (Phase 1-2만 적용 시)

- **로그인 플로우**: 현재 대비 5% 향상
- **Browse 섹션**: 현재 대비 30% 향상
- **전체 체감 속도**: 약간 개선

---

**작성자**: AI Assistant  
**최종 수정**: 2025-10-24  
**다음 검토**: 구현 완료 후
