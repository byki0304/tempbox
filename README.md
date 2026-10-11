# 템프박스

휴대폰과 데스크톱 사이에서 메모와 파일을 한 번만 건넵니다. 다른 기기가 받으면 상자에서 비웁니다. 보관은 넣은 시각부터 240시간입니다.

## 로컬에서 열기

API를 먼저 켭니다.

```
node functions/local-server.js
```

그다음 웹을 켭니다.

```
flutter run -d chrome --web-port 3000
```

주소는 http://localhost:3000 입니다. API는 127.0.0.1:8787 이고 이 브라우저만 붙습니다.

Firebase 프로젝트는 tempbox (`tempbox-c3fc8`), 리전은 `asia-northeast3` 입니다. Google Cloud 프로젝트는 `tempbox-511314` 입니다. 호스트 이름은 비워 둡니다. 서비스 계정 키와 OAuth 클라이언트 비밀, 관리자 비밀번호는 저장소에 없습니다.

## 저장

- 메타데이터는 Firestore가 원본입니다.
- Firebase Storage 원본은 서명 주소로만 읽고, 공개 읽기는 막습니다.
- Google로 로그인한 사람만 선반을 Firebase 또는 Google Drive 중에서 고릅니다. 기본은 Firebase이고, 한 번 고르면 다음 로그인에도 남습니다.
- Drive에 두는 것은 원본 파일뿐입니다.

## 요금제와 용량

2026-10-11 기준 Firebase 문서입니다.

- Spark: 2026-02-03부터 Cloud Storage를 쓸 수 없습니다. 저장 용량은 0바이트이고, 그 90%도 0이므로 Firebase 파일 업로드는 거절합니다.
- Blaze: 계정 저장 한도는 없고, 객체 하나의 플랫폼 상한은 5TiB입니다. 기본 버킷의 무상 저장은 5GB이고 그 다음은 종량제입니다. 파일 하나가 이 용량의 90%를 넘으면 거절합니다.
- `STORAGE_BUDGET_BYTES` 가 비어 있으면 Blaze 무상 5GB를 예산으로 씁니다. 파일 하나의 상한은 예산의 80%이고, 사용량이 예산의 80%에 닿으면 새 Firebase 업로드를 멈춥니다.
- 기획서의 20MB, 100MB 개인 상한은 쓰지 않습니다.
- 비회원 보관 30개, 로그인 사용자 보관 200개입니다.
- Google Drive 파일 하나의 플랫폼 상한은 5TB입니다. 이 상자의 Drive 원본 상한은 2GB이고, 128MB, 256MB, 512MB, 1GB, 2GB 중에서 고릅니다. Drive 용량은 Firebase 예산에 넣지 않습니다.

## Google Drive 준비

사용할 계정은 byki0304@gmail.com 입니다.

1. Google Cloud 프로젝트 `tempbox-511314` 에서 Drive API를 켭니다.
2. OAuth 동의 화면의 테스트 사용자에 byki0304@gmail.com 을 넣습니다.
3. 클라이언트 ID와 비밀은 환경 변수 `GOOGLE_OAUTH_CLIENT_ID`, `GOOGLE_OAUTH_CLIENT_SECRET` 에만 둡니다. 저장소에 올리지 않습니다.
4. 앱에서 Google로 로그인한 뒤 선반을 Google Drive로 고르고, 파일 하나의 상한을 고릅니다.

Drive 연결이 거절되면 그 파일은 Firebase에 남습니다.

## 배포

산출물은 `flutter build web --release` 의 `build/web` 입니다. 배포 뒤에 `node tool/patch_service_worker.js` 로 개인 파일과 서명 주소가 서비스 워커에 캐시되지 않게 합니다.

Vercel과 Netlify 모두 그 산출물을 쓰고, 없는 경로는 `index.html` 로 되돌립니다. 호스트 이름은 비워 둡니다. Firebase 프로젝트 ID는 `tempbox-c3fc8` 입니다.

함수 리전은 `asia-northeast3` 이고 런타임은 Node.js 20입니다. Cloud Functions와 Cloud Storage는 Blaze가 필요합니다.

관리자는 Firebase 콘솔에서 custom claim `admin=true` 만 부여합니다. 계정을 시드하지 않습니다.

## 확인

```
node --test functions/test/domain.test.js
flutter test
```

보안 규칙은 JDK가 있을 때 에뮬레이터로 확인합니다. 이 환경에 Java가 없으면 이 명령은 시작되지 않습니다.

```
firebase emulators:exec --only firestore,storage "node --test functions/test/rules.test.js"
```

그 테스트는 타인 상자 읽기, 항목 직접 쓰기, privateProfiles 접근, 페어링 해시 읽기, stats 쓰기, expiresAt 수정, Storage 공개 읽기를 거절해야 합니다.
