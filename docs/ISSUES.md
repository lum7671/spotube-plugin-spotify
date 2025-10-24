# 🐛 발견된 문제점 및 개선 사항

## 문서 정보

- **작성일**: 2025년 10월 21일
- **분석 대상**: `src/segments/auth.ht`
- **우선순위**: 🔴 긴급 | 🟡 중요 | 🟢 권장

---

## 🔴 긴급 (Critical) - 즉시 수정 필요

### 1. `randomBytesFromMath()` 함수 반환값 누락

**파일**: `src/segments/auth.ht` (Line ~115)

**문제점**:

```javascript
fun randomBytesFromMath(length: int) -> string {
  var bytes = List()
  for (int i = 0; i < length; i++) {
    bytes.add(Random().nextInt(256).toString())
  }
  // ❌ return 문이 없음!
}
```

**영향**:

- User-Agent 생성 시 `undefined` 또는 `null`이 포함됨
- HTTP 요청이 실패하거나 비정상적인 User-Agent가 전송됨
- 토큰 발급 실패 가능성

**수정 방안**:

```javascript
fun randomBytesFromMath(length: int) -> string {
  var bytes = List()
  for (int i = 0; i < length; i++) {
    bytes.add(Random().nextInt(256).toString())
  }
  return bytes.join("") // ✅ 추가
}
```

**처리 상태**: [ ] 미처리

---

### 2. `getToken()` 함수의 중복 매개변수 정의

**파일**: `src/segments/auth.ht` (Line ~125)

**문제점**:

```javascript
fun getToken({
  mode = "transport",    // ❌ 기본값 설정
  timestamp: DateTime,
  totp: string,
  spDc: string,
  mode: string,          // ❌ 같은 이름 중복 선언
  totpVer: int
})
```

**영향**:

- 컴파일 에러 또는 예상치 못한 동작
- 매개변수 값이 덮어써질 가능성
- 코드 가독성 저하

**수정 방안**:

```javascript
fun getToken({
  timestamp: DateTime,
  totp: string,
  spDc: string,
  mode: string = "transport",  // ✅ 하나로 통합, 기본값 설정
  totpVer: int
})
```

**처리 상태**: [ ] 미처리

---

## 🟡 중요 (High) - 빠른 시일 내 수정 권장

### 3. Timer 만료 시간 검증 로직 부재

**파일**: `src/segments/auth.ht` (Line ~40-45)

**문제점**:

```javascript
_timer = Timer.periodic(getExpirationDuration(), (cancel){
  refreshCredentials()
})
```

**영향**:

- `getExpirationDuration()`이 0 또는 음수일 경우 즉시/무한 실행
- 이미 만료된 토큰일 때 무한 루프 가능성
- CPU 자원 낭비

**수정 방안**:

```javascript
if(event["type"] == "recovered" || event["type"] == "login") {
  _timer?.cancel()
  
  final duration = getExpirationDuration()
  
  // ✅ 최소 1초 보장, 최대한 만료 1분 전에 갱신
  final safeDuration = duration.inMilliseconds > 60000 
    ? Duration(milliseconds: duration.inMilliseconds - 60000)
    : Duration(seconds: 1)
  
  _timer = Timer.periodic(safeDuration, (cancel){
    refreshCredentials()
  })
}
```

**처리 상태**: [ ] 미처리

---

### 4. `sp_dc` 쿠키 null 체크 부재

**파일**: `src/segments/auth.ht` (Line ~155)

**문제점**:

```javascript
fun credentialsFromCookie(cookies: List) -> Future {
  final spDc = cookies.where((c) => c["name"] == "sp_dc").first?["value"];
  // ❌ spDc가 null이면 그대로 진행됨
  
  return getLatestNuance().then((nuance){
    // ...
  })
}
```

**영향**:

- `sp_dc` 쿠키가 없을 때 토큰 발급 실패
- 사용자에게 명확한 에러 메시지 없음
- 디버깅 어려움

**수정 방안**:

```javascript
fun credentialsFromCookie(cookies: List) -> Future {
  final spDc = cookies.where((c) => c["name"] == "sp_dc").first?["value"];
  
  // ✅ 쿠키 검증
  if (spDc == null || spDc.isEmpty) {
    throw Exception("sp_dc cookie not found. Please login again.");
  }
  
  return getLatestNuance().then((nuance){
    // ...
  })
}
```

**처리 상태**: [ ] 미처리

---

### 5. WebView 리스너 메모리 누수

**파일**: `src/segments/auth.ht` (Line ~210)

**문제점**:

```javascript
fun authenticate() -> Future {
  var webview = Webview(uri: "https://accounts.spotify.com/")
  
  var sub: StreamSubscription = webview.onUrlRequestStream.listen((url){
    // ...
  })
  // ❌ sub.cancel()이 호출되지 않음
  
  return webview.open()
}
```

**영향**:

- StreamSubscription이 해제되지 않아 메모리 누수
- WebView 닫힌 후에도 리스너가 살아있음
- 반복적인 로그인 시 메모리 사용량 증가

**수정 방안**:

```javascript
fun authenticate() -> Future {
  var webview = Webview(uri: "https://accounts.spotify.com/")
  var sub: StreamSubscription
  
  sub = webview.onUrlRequestStream.listen((url){
    var safeUrl = url.endsWith("/") ? url.substring(0, url.length - 1) : url
    var exp = Regex("https:\\/\\/accounts.spotify.com\\/.+\\/status")
    if(exp.hasMatch(safeUrl)) {
      return webview.getCookies(url).then((cookies){
        return login(cookies.map((cookie)=> cookie.toJson()).toList()).then(() {
          sub?.cancel() // ✅ 리스너 정리
          return webview.close()
        })
      })
    }
  })
  
  return webview.open()
}
```

**처리 상태**: [ ] 미처리

---

## 🟢 권장 (Medium) - 코드 품질 개선

### 6. JSON 파싱 에러 처리 부재

**파일**: `src/segments/auth.ht` (Line ~72-80)

**문제점**:

```javascript
fun initializeFromLocalStorage() {
  LocalStorage.getString("credentials").then((credentialsStr){
    if (credentialsStr != null) {
      credentials = JSON.decode(credentialsStr); // ❌ 파싱 실패 시?
      if (isExpired()) {
        refreshCredentials()
      } else {
        controller.add({ type: "recovered" }.toJson())
      }
    }
  })
}
```

**영향**:

- 손상된 JSON 데이터로 인한 앱 크래시
- LocalStorage 데이터 변조 시 예외 처리 없음

**수정 방안**:

```javascript
fun initializeFromLocalStorage() {
  LocalStorage.getString("credentials").then((credentialsStr){
    if (credentialsStr != null) {
      try {
        credentials = JSON.decode(credentialsStr)
        if (isExpired()) {
          refreshCredentials()
        } else {
          controller.add({ type: "recovered" }.toJson())
        }
      } catch (e) {
        print("[Auth] Failed to parse credentials: ${e}")
        LocalStorage.remove("credentials") // 손상된 데이터 제거
      }
    }
  })
}
```

**처리 상태**: [ ] 미처리

---

### 7. 경쟁 조건 (Race Condition)

**파일**: `src/segments/auth.ht` (Line ~72-80)

**문제점**:

```javascript
fun initializeFromLocalStorage() {
  LocalStorage.getString("credentials").then((credentialsStr){
    if (credentialsStr != null) {
      credentials = JSON.decode(credentialsStr);
      if (isExpired()) {
        refreshCredentials() // ⚠️ credentials 설정 직후 바로 사용
      }
    }
  })
}
```

**영향**:

- `refreshCredentials()` 내부에서 `credentials["cookies"]` 접근 시 타이밍 이슈
- 비동기 처리로 인한 예측 불가능한 동작

**수정 방안**:

```javascript
fun initializeFromLocalStorage() {
  LocalStorage.getString("credentials").then((credentialsStr){
    if (credentialsStr != null) {
      try {
        final parsedCreds = JSON.decode(credentialsStr)
        credentials = parsedCreds // ✅ 먼저 할당
        
        if (isExpired()) {
          refreshCredentials()
        } else {
          controller.add({ type: "recovered" }.toJson())
        }
      } catch (e) {
        print("[Auth] Failed to parse credentials: ${e}")
        LocalStorage.remove("credentials")
      }
    }
  })
}
```

**처리 상태**: [ ] 미처리

---

### 8. 네트워크 요청 에러 처리

**파일**: `src/segments/auth.ht` (여러 위치)

**문제점**:

```javascript
fun getLatestNuance() -> Future {
  return client.get_req(
    "https://codeberg.org/sonic-liberation/blubber-junkyard-elitism/raw/branch/main/nuances.json"
  ).then((res) {
    var data = JSON.decode(res.data);
    data.sort((a, b) => b["v"].compareTo(a["v"]))
    return data.first
  })
  // ❌ 네트워크 실패, JSON 파싱 실패 처리 없음
}
```

**영향**:

- 네트워크 연결 없을 때 앱 멈춤
- API 서버 다운 시 처리 불가
- 사용자에게 명확한 에러 메시지 없음

**수정 방안**:

```javascript
fun getLatestNuance() -> Future {
  return client.get_req(
    "https://codeberg.org/sonic-liberation/blubber-junkyard-elitism/raw/branch/main/nuances.json"
  ).then((res) {
    try {
      var data = JSON.decode(res.data);
      if (data == null || data.isEmpty) {
        throw Exception("Empty nuance data")
      }
      data.sort((a, b) => b["v"].compareTo(a["v"]))
      return data.first
    } catch (e) {
      throw Exception("Failed to parse nuance data: ${e}")
    }
  }).catchError((error) {
    print("[Auth] Failed to fetch nuance: ${error}")
    throw Exception("Network error: Cannot fetch authentication data")
  })
}
```

**처리 상태**: [ ] 미처리

---

### 9. `refreshCredentials()` 무한 재시도 방지

**파일**: `src/segments/auth.ht` (Line ~195-205)

**문제점**:

```javascript
fun refreshCredentials() -> Future {
  if (credentials["cookies"] == null) {
    print("[refreshCredentials] No cookie found. Cannot refresh credentials.");
    return;
  }
  return this.credentialsFromCookie(credentials["cookies"]).then((creds){
    LocalStorage.setString("credentials", JSON.encode(creds.toJson()));
    credentials = creds;
    controller.add({ type: "refreshed" }.toJson())
  })
  // ❌ 실패 시 재시도 로직 없음, 에러 전파 안 됨
}
```

**영향**:

- 토큰 갱신 실패 시 무한 재시도 가능성
- 사용자가 재로그인 필요함을 알 수 없음

**수정 방안**:

```javascript
var _refreshRetryCount: int = 0
final _maxRefreshRetries: int = 3

fun refreshCredentials() -> Future {
  if (credentials["cookies"] == null) {
    print("[refreshCredentials] No cookie found. Cannot refresh credentials.");
    controller.add({ type: "refresh_failed", reason: "no_cookies" }.toJson())
    return;
  }
  
  return this.credentialsFromCookie(credentials["cookies"]).then((creds){
    LocalStorage.setString("credentials", JSON.encode(creds.toJson()));
    credentials = creds;
    _refreshRetryCount = 0 // ✅ 성공 시 리셋
    controller.add({ type: "refreshed" }.toJson())
  }).catchError((error) {
    _refreshRetryCount++
    print("[Auth] Refresh failed (attempt ${_refreshRetryCount}): ${error}")
    
    if (_refreshRetryCount >= _maxRefreshRetries) {
      // ✅ 최대 재시도 초과 시 로그아웃
      print("[Auth] Max refresh retries exceeded. Logging out.")
      logout()
      controller.add({ type: "refresh_failed", reason: "max_retries" }.toJson())
    }
  })
}
```

**처리 상태**: [ ] 미처리

---

## 📊 처리 우선순위 요약

| 순위 | 문제 | 파일 | 영향도 | 난이도 |
|------|------|------|--------|--------|
| 1 | `randomBytesFromMath()` 반환값 누락 | auth.ht:115 | 🔴 Critical | ⭐ Easy |
| 2 | `getToken()` 중복 매개변수 | auth.ht:125 | 🔴 Critical | ⭐ Easy |
| 3 | Timer 만료 시간 검증 부재 | auth.ht:40 | 🟡 High | ⭐⭐ Medium |
| 4 | `sp_dc` 쿠키 null 체크 | auth.ht:155 | 🟡 High | ⭐ Easy |
| 5 | WebView 리스너 메모리 누수 | auth.ht:210 | 🟡 High | ⭐⭐ Medium |
| 6 | JSON 파싱 에러 처리 | auth.ht:72 | 🟢 Medium | ⭐ Easy |
| 7 | 경쟁 조건 | auth.ht:72 | 🟢 Medium | ⭐⭐ Medium |
| 8 | 네트워크 에러 처리 | auth.ht:85 | 🟢 Medium | ⭐⭐ Medium |
| 9 | 토큰 갱신 무한 재시도 | auth.ht:195 | 🟢 Medium | ⭐⭐⭐ Hard |

---

## 🔄 처리 체크리스트

### Phase 1: 긴급 수정 (즉시)

- [ ] #1: `randomBytesFromMath()` return 추가
- [ ] #2: `getToken()` 중복 매개변수 제거
- [ ] 테스트: 로그인 및 토큰 발급 확인

### Phase 2: 중요 수정 (1주일 이내)

- [ ] #3: Timer 검증 로직 추가
- [ ] #4: `sp_dc` 쿠키 검증
- [ ] #5: WebView 리스너 정리
- [ ] 테스트: 토큰 자동 갱신, 메모리 누수 확인

### Phase 3: 품질 개선 (2주일 이내)

- [ ] #6: JSON 파싱 try-catch 추가
- [ ] #7: 경쟁 조건 해결
- [ ] #8: 네트워크 에러 처리
- [ ] #9: 토큰 갱신 재시도 로직
- [ ] 테스트: 에러 시나리오 전체 테스트

---

## 📝 추가 개선 제안

### 로깅 시스템 개선

현재 `print()` 사용 중 → 구조화된 로깅 시스템 도입 권장

```javascript
enum LogLevel { DEBUG, INFO, WARN, ERROR }

fun log(level: LogLevel, message: string, context: Map = null) {
  // 로그 레벨별 처리
}
```

### 테스트 코드 작성

- 단위 테스트: 각 함수별 테스트
- 통합 테스트: 로그인 → 토큰 갱신 → 로그아웃 플로우
- 에러 시나리오 테스트

### 문서화

- API 문서 자동 생성
- 에러 코드 및 처리 방법 문서화
- 사용자 가이드 업데이트

---

## 📞 문의 및 보고

문제 발견 또는 개선 제안 시:

1. GitHub Issues에 보고
2. PR 제출 시 이 체크리스트 참조
3. 테스트 결과 포함 필수
